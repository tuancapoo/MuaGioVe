class_name GameMap
extends Node2D
## Script dùng chung cho mọi map. Mỗi map cần:
##  - Marker2D "PlayerSpawn": chỗ Minh xuất hiện (đặt ở CHÂN nhân vật).
##  - map_size: kích thước ảnh nền (px) để giới hạn camera.

## Id dùng trong điều kiện hội thoại: if current_map == "garden"
@export var map_id: String = ""
@export var map_name: String = ""
@export var map_size: Vector2i = Vector2i(640, 384)

@onready var player_spawn: Marker2D = $PlayerSpawn


## Đặt Player vào map: dịch tới PlayerSpawn và giới hạn camera trong khung map.
func place_player(player: Player) -> void:
	GameState.current_map = map_id
	# Origin của Player ở giữa thân; chân cách origin ~56 px (theo CollisionShape).
	player.global_position = player_spawn.global_position + Vector2(0, -56)
	var cam := player.camera
	cam.limit_left = int(global_position.x)
	cam.limit_top = int(global_position.y)
	cam.limit_right = int(global_position.x) + map_size.x
	cam.limit_bottom = int(global_position.y) + map_size.y
	cam.reset_smoothing()
	EventBus.map_changed.emit(map_id)
