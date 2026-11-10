extends Node
## Hành vi đi theo Minh (bạn đồng hành). Gắn làm con của một NPC (npc.tscn).
## NPC chỉ hiện khi appear_condition đúng (vd "npc_get('an', 'following', false)"),
## nên bật / tắt cờ là bật / tắt việc đi theo.
##
## - Đi sau lưng Minh một khoảng, cùng mặt đất với Minh.
## - Minh chạy thì chạy theo; bị bỏ xa quá thì dịch chuyển ngầm về sau lưng Minh.
## - Minh bị khoá (đang thoại, chuyển map…) thì đứng yên.
## - Đổi map: Main gọi snap_behind() để đặt ngay sau lưng Minh.

## Khoảng cách sau lưng Minh (px)
@export var follow_distance: float = 40.0
## Xa hơn mức này thì dịch chuyển ngầm (px)
@export var teleport_distance: float = 280.0
## Xa hơn mức này thì chạy cho kịp (px)
@export var run_distance: float = 110.0
@export var walk_speed: float = 150.0
@export var run_speed: float = 300.0
## Từ gốc toạ độ của Player tới chân (px) — xem player.gd
@export var player_feet_offset: float = 56.0

@onready var body: Node2D = get_parent()
@onready var sprite: AnimatedSprite2D = get_parent().get_node("AnimatedSprite2D")


func _ready() -> void:
	body.add_to_group(&"companion")
	body.visibility_changed.connect(func(): if body.visible: snap_behind())


func _physics_process(delta: float) -> void:
	var player: Player = _player()
	if player == null or not body.visible:
		return
	body.global_position.y = player.global_position.y + player_feet_offset

	var target_x := _target_x(player)
	var dx := target_x - body.global_position.x
	if absf(dx) > teleport_distance:
		snap_behind()
		return

	var moving: bool = absf(dx) > 4.0 and player.can_move
	if moving:
		var player_running: bool = absf(player.velocity.x) > walk_speed + 1.0
		var speed: float = run_speed if (player_running or absf(dx) > run_distance) else walk_speed
		body.global_position.x = move_toward(body.global_position.x, target_x, speed * delta)
		sprite.flip_h = dx < 0.0
		_play(&"Run" if speed == run_speed else &"Walk")
	else:
		sprite.flip_h = player.anim.flip_h
		_play(&"Idle")


## Đặt ngay sau lưng Minh, quay cùng hướng.
func snap_behind() -> void:
	var player: Player = _player()
	if player == null:
		return
	body.global_position = Vector2(_target_x(player), player.global_position.y + player_feet_offset)
	sprite.flip_h = player.anim.flip_h
	_play(&"Idle")


func _target_x(player: Player) -> float:
	var facing := -1.0 if player.anim.flip_h else 1.0
	var x := player.global_position.x - facing * follow_distance
	# Không ra ngoài map
	var map = _current_map()
	if map:
		x = clampf(x, map.global_position.x + 20.0, map.global_position.x + map.map_size.x - 20.0)
	return x


## Map đang chơi: An là con của Main/World, Main giữ map_node.
func _current_map() -> Node:
	var world := body.get_parent()
	var main := world.get_parent() if world else null
	return main.get("map_node") if main else null


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _play(anim_name: StringName) -> void:
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name) and sprite.animation != anim_name:
		sprite.play(anim_name)
