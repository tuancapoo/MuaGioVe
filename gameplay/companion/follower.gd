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
	var player := _player()
	if player == null or not body.visible:
		return
	body.global_position.y = player.global_position.y + player_feet_offset

	var target_x := _target_x(player)
	var dx := target_x - body.global_position.x
	if absf(dx) > teleport_distance:
		snap_behind()
		return

	var moving := absf(dx) > 4.0 and player.can_move
	if moving:
		var player_running := absf(player.velocity.x) > walk_speed + 1.0
		var speed := run_speed if (player_running or absf(dx) > run_distance) else walk_speed
		body.global_position.x = move_toward(body.global_position.x, target_x, speed * delta)
		sprite.flip_h = dx < 0.0
		_play(&"Run" if speed == run_speed else &"Walk")
	else:
		sprite.flip_h = player.anim.flip_h
		_play(&"Idle")


## Đặt ngay sau lưng Minh, quay cùng hướng.
func snap_behind() -> void:
	var player := _player()
	if player == null:
		return
	body.global_position = Vector2(_target_x(player), player.global_position.y + player_feet_offset)
	sprite.flip_h = player.anim.flip_h
	_play(&"Idle")


func _target_x(player: Node2D) -> float:
	var facing := -1.0 if player.anim.flip_h else 1.0
	var x := player.global_position.x - facing * follow_distance
	# Không ra ngoài map
	var map = get_tree().current_scene.get("map_node")
	if map:
		x = clampf(x, map.global_position.x + 20.0, map.global_position.x + map.map_size.x - 20.0)
	return x


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _play(anim_name: StringName) -> void:
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name) and sprite.animation != anim_name:
		sprite.play(anim_name)
