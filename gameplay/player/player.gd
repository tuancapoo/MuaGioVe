class_name Player
extends CharacterBody2D
## Nhân vật Minh — di chuyển ngang (side-scrolling), chạy, tương tác.
## Điều khiển theo GDD mục 2.4: A/D hoặc mũi tên, giữ Shift để chạy, E để tương tác.
## Giữ Ctrl để ngồi xuống núp (animation "sneak-Idle"); đang ngồi thì không đi được.
## Bấm S / ↓ khi đứng yên: quay mặt ra màn hình ("front-view"). Đi là quay lại bình thường.
## Tư thế cho cutscene / vật để ngồi: set_pose(Player.POSE_SIT) / set_pose(Player.POSE_FRONT) / set_pose(&"").

## Phát ra khi đối tượng có thể tương tác gần nhất thay đổi (null nếu không còn gì).
## UI dùng signal này để hiện/ẩn lời nhắc "[E]".
signal interactable_changed(target: Node)

@export var walk_speed: float = 150.0
@export var run_speed: float = 300.0
## Gia tốc / giảm tốc (px/s²) — để Minh không khựng cứng khi dừng.
@export var acceleration: float = 1500.0
@export var friction: float = 2000.0

@export_group("Tiếng bước chân")
## Tiếng mặc định (map đổi lại qua footstep_surface → set_footstep_surface)
@export var walk_sound: AudioStream = preload("res://assets/audio/sfx/footsteps/stone_walk.mp3")
@export var run_sound: AudioStream = preload("res://assets/audio/sfx/footsteps/stone_run.mp3")
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var footstep_volume_db: float = -12.0
## Bỏ qua đoạn đầu file (giây) nếu file có khoảng lặng ở đầu
@export var walk_sound_offset: float = 0.0
@export var run_sound_offset: float = 0.0
## Bus âm thanh (dùng "SFX" nếu đã tạo bus này, không thì "Master")
@export var footstep_bus: StringName = &"SFX"
@export_group("")

## Tên + màu khung thoại của Minh (res://data/npcs/minh.tres).
@export var npc_data: NpcData = preload("res://data/npcs/minh.tres")

var speaker_name: String:
	get: return npc_data.display_name
var dialogue_color: Color:
	get: return npc_data.dialogue_color

## Tắt khi đang hội thoại, cutscene, minigame…
## Có thể gán trực tiếp (`can_move = false/true`) hoặc khoá theo lý do (`lock("cutscene") / unlock("cutscene")`).
var _manual_can_move: bool = true
var _locks: Dictionary = {}
var can_move: bool:
	get: return _manual_can_move and _locks.is_empty()
	set(value): _manual_can_move = value
## Đang ngồi núp (giữ Ctrl). Minigame / người đi theo đọc biến này.
var crouching: bool = false

## Tên animation ngồi núp (tag trong file .aseprite) — không phân biệt hoa thường
const CROUCH_ANIM := &"sneak-idle"
## Tư thế đứng yên đặc biệt (tag trong file .aseprite, không phân biệt hoa thường)
const POSE_FRONT := &"front-view"
const POSE_SIT := &"sit"

## Tư thế hiện tại khi đứng yên (rỗng = bình thường). Người đi theo làm giống Minh.
var pose: StringName = &""
## Khi ngồi: hạ hình xuống bao nhiêu px (chỗ ngồi đặt, vd mép kè thả chân). Người đi theo dùng chung.
var sit_drop: float = 0.0
var _anim_base_y: float = 0.0

var _nearby: Array[Node] = []
var _footsteps: AudioStreamPlayer
const FOOTSTEP_PATH := "res://assets/audio/sfx/footsteps/%s_%s.mp3"
var _current_target: Node = null

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	add_to_group("player")
	add_to_group(&"dialogue_speaker")
	DialogueManager.dialogue_started.connect(func(_r): lock(&"dialogue"))
	DialogueManager.dialogue_ended.connect(func(_r): unlock(&"dialogue"))
	interaction_area.area_entered.connect(_on_area_entered)
	interaction_area.area_exited.connect(_on_area_exited)
	interaction_area.body_entered.connect(_on_area_entered)
	interaction_area.body_exited.connect(_on_area_exited)
	_setup_footsteps()
	_ensure_crouch_action()
	_anim_base_y = anim.position.y


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	crouching = can_move and is_on_floor() and Input.is_action_pressed("crouch")
	# Đang ngồi thì đứng yên tại chỗ
	var direction := Input.get_axis("move_left", "move_right") if can_move and not crouching else 0.0
	if direction != 0.0 or crouching:
		pose = &""   # đi / ngồi núp là bỏ tư thế (đứng dậy)
	var is_running := Input.is_action_pressed("run")
	var target_speed := run_speed if is_running else walk_speed

	if direction != 0.0:
		anim.flip_h = direction < 0.0
		velocity.x = move_toward(velocity.x, direction * target_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	move_and_slide()
	_update_animation(direction, is_running)
	_update_footsteps(direction != 0.0 and is_on_floor() and absf(velocity.x) > 10.0, is_running)
	_update_interact_target()


func _unhandled_input(event: InputEvent) -> void:
	if not can_move:
		return
	if event.is_action_pressed("move_down") and is_on_floor() and absf(velocity.x) < 10.0:
		set_pose(&"" if pose == POSE_FRONT else POSE_FRONT)
		return
	if _current_target == null:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		EventBus.interacted.emit(_current_target)
		_current_target.interact(self)
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var world_click := get_viewport().get_canvas_transform().affine_inverse() * mb.position
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _is_click_on_target(_current_target, world_click):
			get_viewport().set_input_as_handled()
			EventBus.interacted.emit(_current_target)
			_current_target.interact(self)


func _is_click_on_target(target: Node, world_click: Vector2) -> bool:
	if not (target is Node2D):
		return false
	var tpos := (target as Node2D).global_position
	var on_object := absf(world_click.x - tpos.x) <= 64.0 and world_click.y >= tpos.y - 120.0 and world_click.y <= tpos.y + 40.0
	if on_object:
		return true
	var prompt_off: Variant = target.get("prompt_offset")
	if prompt_off is Vector2:
		return world_click.distance_to(tpos + prompt_off) <= 44.0
	return false


func _update_animation(direction: float, is_running: bool) -> void:
	var crouch_anim := anim_of(anim.sprite_frames, CROUCH_ANIM)
	if crouching and crouch_anim != &"":
		_play(crouch_anim)
		return
	var pose_anim := anim_of(anim.sprite_frames, pose)
	var sitting := direction == 0.0 and pose == POSE_SIT and pose_anim != &""
	anim.position.y = _anim_base_y + (sit_drop if sitting else 0.0)
	if direction == 0.0 and pose_anim != &"":
		_play(pose_anim)
		return
	if direction == 0.0:
		_play("Idle")
	elif is_running:
		_play("Run")
	else:
		_play("Walk")


func _play(anim_name: StringName) -> void:
	if anim.animation != anim_name:
		anim.play(anim_name)


## Khoá / mở khoá điều khiển theo lý do (tránh hội thoại kết thúc giữa cutscene/minigame mở khoá nhầm).
func lock(reason: StringName) -> void:
	_locks[reason] = true
	velocity = Vector2.ZERO


func unlock(reason: StringName) -> void:
	_locks.erase(reason)


func is_locked() -> bool:
	return not can_move


## Đặt tư thế khi đứng yên: POSE_FRONT, POSE_SIT hoặc &"" (bình thường).
func set_pose(new_pose: StringName) -> void:
	pose = new_pose
	if new_pose != POSE_SIT:
		sit_drop = 0.0


## Tên animation trong bộ frame khớp `wanted` (không phân biệt hoa thường), rỗng nếu chưa vẽ.
## Dùng chung cho người đi theo (vd An có "Sit", Minh có "sit").
static func anim_of(frames: SpriteFrames, wanted: StringName) -> StringName:
	if frames == null or wanted == &"":
		return &""
	if frames.has_animation(wanted):
		return wanted
	var w := String(wanted).to_lower()
	for n in frames.get_animation_names():
		if String(n).to_lower() == w:
			return n
	return &""


## Phím ngồi: Ctrl (tạo lúc chạy nếu project.godot chưa khai báo action "crouch").
func _ensure_crouch_action() -> void:
	if InputMap.has_action(&"crouch"):
		return
	InputMap.add_action(&"crouch")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_CTRL
	InputMap.action_add_event(&"crouch", ev)


# --- Tiếng bước chân ----------------------------------------------------------

func _setup_footsteps() -> void:
	_footsteps = AudioStreamPlayer.new()
	_footsteps.name = "Footsteps"
	_footsteps.volume_db = footstep_volume_db
	_footsteps.bus = footstep_bus if AudioServer.get_bus_index(footstep_bus) != -1 else &"Master"
	add_child(_footsteps)
	_make_loop(walk_sound)
	_make_loop(run_sound)


## Map gọi khi Minh vào map: "dirt" / "grass" / "stone" / "tile".
## Thiếu file của mặt nào thì giữ tiếng đang dùng.
func set_footstep_surface(surface: String) -> void:
	var walk := FOOTSTEP_PATH % [surface, "walk"]
	var run := FOOTSTEP_PATH % [surface, "run"]
	if ResourceLoader.exists(walk):
		walk_sound = _make_loop(load(walk))
	if ResourceLoader.exists(run):
		run_sound = _make_loop(load(run))
	if _footsteps and _footsteps.playing:
		_footsteps.stop() # frame sau _update_footsteps phát lại đúng tiếng mới


func _make_loop(s: AudioStream) -> AudioStream:
	if s is AudioStreamMP3 or s is AudioStreamOggVorbis:
		s.loop = true # phát lặp liên tục khi còn đi / chạy
	elif s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	return s


## Đang đi → tiếng đi; đang chạy → tiếng chạy; đứng yên / bị khoá → tắt.
func _update_footsteps(moving: bool, running: bool) -> void:
	if not moving:
		if _footsteps.playing:
			_footsteps.stop()
		return
	var stream := run_sound if running else walk_sound
	if stream == null:
		_footsteps.stop()
		return
	if _footsteps.stream != stream or not _footsteps.playing:
		_footsteps.stream = stream
		_footsteps.play(run_sound_offset if running else walk_sound_offset)


## Điểm đuôi khung thoại chỉ vào khi Minh nói (trên đầu).
func get_speech_anchor() -> Vector2:
	return global_position + Vector2(0, -62)


# --- Tương tác ---------------------------------------------------------------
# Đối tượng tương tác được = Area2D/Body nằm trong group "interactable"
# và có hàm `interact(player)`. NPC, vật phẩm, cửa… đều theo quy ước này.

func _on_area_entered(node: Node) -> void:
	if node.is_in_group("interactable") and node.has_method("interact"):
		_nearby.append(node)


func _on_area_exited(node: Node) -> void:
	_nearby.erase(node)


func _update_interact_target() -> void:
	var best: Node = null
	var best_dist := INF
	for n in _nearby:
		if not is_instance_valid(n) or not can_move:
			continue
		var d := global_position.distance_squared_to((n as Node2D).global_position)
		if d < best_dist:
			best_dist = d
			best = n
	if best != _current_target:
		_current_target = best
		interactable_changed.emit(best)
