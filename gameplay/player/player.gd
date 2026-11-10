class_name Player
extends CharacterBody2D
## Nhân vật Minh — di chuyển ngang (side-scrolling), chạy, tương tác.
## Điều khiển theo GDD mục 2.4: A/D hoặc mũi tên, giữ Shift để chạy, E để tương tác.

## Phát ra khi đối tượng có thể tương tác gần nhất thay đổi (null nếu không còn gì).
## UI dùng signal này để hiện/ẩn lời nhắc "[E]".
signal interactable_changed(target: Node)

@export var walk_speed: float = 150.0
@export var run_speed: float = 300.0
## Gia tốc / giảm tốc (px/s²) — để Minh không khựng cứng khi dừng.
@export var acceleration: float = 1500.0
@export var friction: float = 2000.0

## Tên + màu khung thoại của Minh (res://data/npcs/minh.tres).
@export var npc_data: NpcData = preload("res://data/npcs/minh.tres")

var speaker_name: String:
	get: return npc_data.display_name
var dialogue_color: Color:
	get: return npc_data.dialogue_color

## Tắt khi đang hội thoại, cutscene, minigame…
var can_move: bool = true

var _nearby: Array[Node] = []
var _current_target: Node = null

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	add_to_group("player")
	add_to_group(&"dialogue_speaker")
	DialogueManager.dialogue_started.connect(func(_r): can_move = false)
	DialogueManager.dialogue_ended.connect(func(_r): can_move = true)
	interaction_area.area_entered.connect(_on_area_entered)
	interaction_area.area_exited.connect(_on_area_exited)
	interaction_area.body_entered.connect(_on_area_entered)
	interaction_area.body_exited.connect(_on_area_exited)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	var direction := Input.get_axis("move_left", "move_right") if can_move else 0.0
	var is_running := Input.is_action_pressed("run")
	var target_speed := run_speed if is_running else walk_speed

	if direction != 0.0:
		anim.flip_h = direction < 0.0
		velocity.x = move_toward(velocity.x, direction * target_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	move_and_slide()
	_update_animation(direction, is_running)
	_update_interact_target()


func _unhandled_input(event: InputEvent) -> void:
	if can_move and event.is_action_pressed("interact") and _current_target != null:
		get_viewport().set_input_as_handled()
		EventBus.interacted.emit(_current_target)
		_current_target.interact(self)


func _update_animation(direction: float, is_running: bool) -> void:
	if direction == 0.0:
		_play("Idle")
	elif is_running:
		_play("Run")
	else:
		_play("Walk")


func _play(anim_name: StringName) -> void:
	if anim.animation != anim_name:
		anim.play(anim_name)


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
