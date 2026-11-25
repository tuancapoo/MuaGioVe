extends Node2D
## Dẫn đường khi Minh đuổi theo An từ vườn rau ra khu vực câu cá (bờ mương chân đê):
##   garden -> yard (Door_nha_minh_va_an) -> nha_minh_va_an (Door_field)
##          -> field (Door_bo_muong_chan_de) -> bo_muong_chan_de (FishingSpot)
##
## - Ở mỗi map trung gian, An chạy phía trước giữ khoảng cách trong tầm nhìn Minh,
##   dừng đợi nếu Minh đứng lại, tới đúng cửa chuyển map thì vẫy gọi rồi chạy khuất qua cửa khi Minh tới gần.
## - Tới khu vực câu cá (bo_muong_chan_de), An chạy tới cạnh điểm câu cá chờ Minh;
##   khi Minh bắt kịp sẽ nói 1 câu ngắn và chuyển sang chế độ bạn đồng hành đi theo Minh (npc.an.following = true).

const AN_FRAMES := preload("res://assets/characters/an/an_frames.tres")
const FONT := preload("res://assets/fonts/vt323_regular.ttf")
const DIALOGUE_PATH := "res://data/dialogues/ch1_pipe_intro.dialogue"
const SFX_RUN := "res://assets/audio/sfx/footsteps/dirt_run.mp3"

const FLAG_CHASE := "ch1.chase_an_fishing"
const FLAG_ARRIVED := "ch1.arrived_fishing_spot"

const RUN_SPEED := 265.0
const MAX_LEAD_DIST := 165.0
const RESUME_LEAD_DIST := 135.0
const EXIT_TRIGGER_DIST := 86.0
const FINAL_TRIGGER_DIST := 96.0

const ROUTE := {
	"yard": {
		"start_x": 190.0,
		"target_x": 255.0,
		"ground_y": 313.0,
		"is_final": false,
		"callout": "Ra ngõ nè!",
	},
	"nha_minh_va_an": {
		"start_x": 1270.0,
		"target_x": 210.0,
		"ground_y": 314.0,
		"is_final": false,
		"callout": "Ra đồng nè Minh!",
	},
	"field": {
		"start_x": 2180.0,
		"target_x": 3060.0,
		"ground_y": 314.0,
		"is_final": false,
		"callout": "Xuống bờ mương!",
	},
	"bo_muong_chan_de": {
		"start_x": 635.0,
		"target_x": 698.0,
		"ground_y": 286.0,
		"is_final": true,
		"callout": "Tới nơi rồi!",
	},
}

var _sprite: AnimatedSprite2D
var _shadow: Node2D
var _callout_layer: Node2D
var _sfx: AudioStreamPlayer

var _active_map: String = ""
var _target_x: float = 0.0
var _dir: float = 1.0
var _is_final: bool = false
var _callout_text: String = ""
var _reached_target: bool = false
var _exiting_map: bool = false
var _waiting_for_player: bool = false
var _finishing_final: bool = false
var _t: float = 0.0

var speaker_name: String = "An"
var dialogue_color: Color = Color(0.95, 0.56, 0.7, 1.0)


func get_speech_anchor() -> Vector2:
	return global_position + Vector2(0.0, -118.0)


func _ready() -> void:
	name = "AnChaseGuide"
	add_to_group(&"dialogue_speaker")
	z_index = 2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_shadow = Node2D.new()
	_shadow.z_index = -1
	_shadow.draw.connect(_draw_shadow)
	add_child(_shadow)

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = AN_FRAMES
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.position = Vector2(0.0, -55.0)
	add_child(_sprite)

	_callout_layer = Node2D.new()
	_callout_layer.z_index = 30
	_callout_layer.draw.connect(_draw_callout)
	add_child(_callout_layer)

	_sfx = AudioStreamPlayer.new()
	_sfx.volume_db = -8.0
	add_child(_sfx)

	EventBus.map_changed.connect(_on_map_changed)
	GameState.changed.connect(_on_state_changed)
	visible = false
	_setup_for_map(GameState.current_map)


func _on_map_changed(map_id: String) -> void:
	_setup_for_map(map_id)


func _on_state_changed() -> void:
	if not GameState.has_flag(FLAG_CHASE) and not _finishing_final:
		visible = false
		_active_map = ""


func _setup_for_map(map_id: String) -> void:
	_reached_target = false
	_exiting_map = false
	_waiting_for_player = false
	_finishing_final = false
	modulate = Color(1, 1, 1, 1)

	if not GameState.has_flag(FLAG_CHASE) or not ROUTE.has(map_id):
		visible = false
		_active_map = ""
		return

	var cfg: Dictionary = ROUTE[map_id]
	_active_map = map_id
	var start_x: float = float(cfg["start_x"])
	_target_x = float(cfg["target_x"])
	var ground_y: float = float(cfg["ground_y"])
	_is_final = bool(cfg["is_final"])
	_callout_text = String(cfg["callout"])
	_dir = 1.0 if _target_x >= start_x else -1.0

	var player_now: Player = get_tree().get_first_node_in_group(&"player") as Player
	var init_y: float = (player_now.global_position.y + 56.0) if player_now else ground_y
	global_position = Vector2(start_x, init_y)
	_sprite.flip_h = _dir < 0.0
	_play(&"Idle")
	visible = true
	_shadow.queue_redraw()
	_callout_layer.queue_redraw()


func _physics_process(delta: float) -> void:
	if not visible or _active_map.is_empty() or _exiting_map or _finishing_final:
		return

	_t += delta
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player == null:
		return

	# Đồng bộ mặt đất của An chuẩn theo chân Minh (y hệt Follower của an_companion) để không bị lơ lửng
	if player.is_on_floor():
		global_position.y = player.global_position.y + 56.0

	var dist_to_target: float = absf(_target_x - global_position.x)
	if not _reached_target:
		if dist_to_target <= 6.0:
			global_position.x = _target_x
			_reached_target = true
			_waiting_for_player = true
			_sprite.flip_h = player.global_position.x < global_position.x
			_play(&"Idle")
		else:
			var lead: float = (global_position.x - player.global_position.x) * _dir
			if _waiting_for_player:
				if lead <= RESUME_LEAD_DIST:
					_waiting_for_player = false
			else:
				if lead >= MAX_LEAD_DIST:
					_waiting_for_player = true

			if _waiting_for_player:
				_sprite.flip_h = player.global_position.x < global_position.x
				_play(&"Idle")
			else:
				global_position.x = move_toward(global_position.x, _target_x, RUN_SPEED * delta)
				_sprite.flip_h = _dir < 0.0
				_play(&"Run")
	else:
		# Đã đứng ngay tại cửa chuyển map hoặc ngay cạnh điểm câu cá
		_sprite.flip_h = player.global_position.x < global_position.x
		_play(&"Idle")
		var player_dist: float = absf(player.global_position.x - global_position.x)
		if _is_final:
			if player_dist <= FINAL_TRIGGER_DIST and player.can_move:
				_finish_chase_at_fishing(player)
		else:
			if player_dist <= EXIT_TRIGGER_DIST:
				_dash_through_exit()

	_callout_layer.queue_redraw()


func _dash_through_exit() -> void:
	if _exiting_map:
		return
	_exiting_map = true
	_sprite.flip_h = _dir < 0.0
	_play(&"Run")

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "global_position:x", global_position.x + _dir * 38.0, 0.28)
	tw.tween_property(self, "modulate:a", 0.0, 0.28)
	await tw.finished
	if is_inside_tree():
		visible = false


func _finish_chase_at_fishing(player: Player) -> void:
	if _finishing_final:
		return
	_finishing_final = true
	_callout_text = ""
	_callout_layer.queue_redraw()

	player.lock(&"an_arrive_fishing")
	_sprite.flip_h = player.global_position.x < global_position.x
	player.anim.flip_h = global_position.x < player.global_position.x
	_play(&"Idle")

	var dlg := _load_dialogue()
	if dlg:
		DialogueManager.show_dialogue_balloon(dlg, "an_arrived_fishing")
		await DialogueManager.dialogue_ended

	if not is_inside_tree():
		return

	GameState.set_flag(FLAG_CHASE, false)
	GameState.set_flag(FLAG_ARRIVED, true)
	GameState.start_quest("catch_fish")
	# Chuyển mượt sang An đồng hành thực thụ đi theo Minh bên khu vực câu cá
	GameState.npc_set("an", "following", true)
	visible = false
	_active_map = ""
	if is_instance_valid(player):
		player.unlock(&"an_arrive_fishing")


func _draw_shadow() -> void:
	_shadow.draw_rect(Rect2(Vector2(-16.0, -3.0), Vector2(32.0, 6.0)), Color(0.0, 0.0, 0.0, 0.28))


func _draw_callout() -> void:
	if _exiting_map or _finishing_final or _callout_text.is_empty():
		return
	if not _reached_target and not _waiting_for_player:
		return
	var bob_y: float = roundf(sin(_t * 6.0) * 2.0)
	var anchor := Vector2(0.0, -112.0 + bob_y)
	var tw: float = FONT.get_string_size(_callout_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var bw: float = tw + 12.0
	var bh: float = 18.0
	var r := Rect2(Vector2(-bw * 0.5, anchor.y - bh).round(), Vector2(bw, bh))
	_callout_layer.draw_rect(r.grow(1.0), Color(0.95, 0.56, 0.70, 0.95))
	_callout_layer.draw_rect(r, Color(0.08, 0.06, 0.12, 0.88))
	_callout_layer.draw_string(FONT, r.position + Vector2(6.0, 14.0), _callout_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.96, 0.92))


func _play(anim_name: StringName) -> void:
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation(anim_name) and _sprite.animation != anim_name:
		_sprite.play(anim_name)


func _play_sfx(path: String, pitch: float = 1.0) -> void:
	if _sfx == null or not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path) as AudioStream
	if stream:
		_sfx.stream = stream
		_sfx.pitch_scale = pitch
		_sfx.play()


func _load_dialogue() -> DialogueResource:
	if FileAccess.file_exists(DIALOGUE_PATH):
		var raw := FileAccess.get_file_as_string(DIALOGUE_PATH)
		if not raw.is_empty():
			return DialogueManager.create_resource_from_text(raw)
	if ResourceLoader.exists(DIALOGUE_PATH):
		return load(DIALOGUE_PATH) as DialogueResource
	return null
