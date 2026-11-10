class_name GameMap
extends Node2D
## Script dùng chung cho mọi map. Mỗi map cần:
##  - Marker2D "PlayerSpawn": chỗ Minh xuất hiện (đặt ở CHÂN nhân vật).
##  - map_size: kích thước ảnh nền (px) để giới hạn camera.

## Id dùng trong điều kiện hội thoại: if current_map == "garden"
@export var map_id: String = "field"
@export var map_name: String = "field"
@export var map_size: Vector2i = Vector2i(4608, 384)
## Zoom camera riêng cho map này. 0 = dùng zoom mặc định của Player,
## tự tăng thêm nếu map thấp / hẹp hơn khung nhìn (để không lộ vùng ngoài map).
@export var camera_zoom: float = 0.0

@onready var player_spawn: Marker2D = $PlayerSpawn


## Đặt Player vào map: dịch tới chỗ xuất hiện và giới hạn camera trong khung map.
## spawn = tên Marker2D trong "Spawns/" (vd "from_garden"); rỗng / không có → PlayerSpawn.
func place_player(player: Player, spawn: String = "") -> void:
	GameState.current_map = map_id
	var marker := get_spawn(spawn)
	# Origin của Player ở giữa thân; chân cách origin ~56 px (theo CollisionShape).
	player.global_position = marker.global_position + Vector2(0, -56)
	player.velocity = Vector2.ZERO
	# Xuất hiện ở nửa phải map → quay mặt sang trái (nhìn vào trong map).
	player.anim.flip_h = marker.global_position.x > global_position.x + map_size.x * 0.5
	var cam := player.camera
	_fit_camera_zoom(cam)
	cam.limit_left = int(global_position.x)
	cam.limit_top = int(global_position.y)
	cam.limit_right = int(global_position.x) + map_size.x
	cam.limit_bottom = int(global_position.y) + map_size.y
	cam.reset_smoothing()
	EventBus.map_changed.emit(map_id)


## Zoom = camera_zoom (nếu đặt) hoặc zoom mặc định của Player, nhưng không nhỏ hơn mức
## cần để khung nhìn nằm gọn trong map (map 233 px cao cần zoom lớn hơn map 384 px).
func _fit_camera_zoom(cam: Camera2D) -> void:
	if not cam.has_meta("base_zoom"):
		cam.set_meta("base_zoom", cam.zoom.x)
	var zoom: float = camera_zoom if camera_zoom > 0.0 else cam.get_meta("base_zoom")
	var view := cam.get_viewport_rect().size
	zoom = maxf(zoom, maxf(view.y / map_size.y, view.x / map_size.x))
	cam.zoom = Vector2(zoom, zoom)


## Tìm chỗ xuất hiện theo tên; không có thì dùng PlayerSpawn.
func get_spawn(spawn: String) -> Marker2D:
	if not spawn.is_empty():
		var m := get_node_or_null("Spawns/" + spawn) as Marker2D
		if m:
			return m
		push_warning("GameMap '%s': không có Spawns/%s, dùng PlayerSpawn" % [map_id, spawn])
	return player_spawn
