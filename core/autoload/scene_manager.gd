extends Node
## Autoload "SceneManager": đổi map có hiệu ứng mờ dần.
##
##   SceneManager.change_map("yard", "from_garden")
##
## - map_id → scene theo quy ước res://world/areas/<map_id>/<map_id>.tscn
## - spawn  → tên Marker2D trong "Spawns/" của map đích (rỗng / không có thì dùng PlayerSpawn)
## Scene đang chạy (Main) phải có hàm load_map(scene: PackedScene, spawn: String).

signal map_change_started(map_id: String)
signal map_change_finished(map_id: String)

const MAP_PATH := "res://world/areas/%s/%s.tscn"
const FADE_TIME := 0.25
## Sau khi vào map mới, bỏ qua MapExit trong khoảng này (tránh vừa vào đã bị đẩy ra lại).
const ARRIVAL_GRACE := 0.5

var _busy := false
var _arrived_at := -1000.0
var _fade: ColorRect


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)


func is_busy() -> bool:
	return _busy


## true nếu vừa vào map chưa lâu (MapExit dùng để không kích hoạt ngay).
func just_arrived() -> bool:
	return Time.get_ticks_msec() / 1000.0 - _arrived_at < ARRIVAL_GRACE


func map_exists(map_id: String) -> bool:
	return ResourceLoader.exists(MAP_PATH % [map_id, map_id])


func change_map(map_id: String, spawn: String = "") -> void:
	if _busy:
		return
	var path := MAP_PATH % [map_id, map_id]
	if not ResourceLoader.exists(path):
		push_error("SceneManager: không có map '%s' (%s)" % [map_id, path])
		return
	var main := get_tree().current_scene
	if main == null or not main.has_method("load_map"):
		push_error("SceneManager: scene hiện tại không có load_map()")
		return

	_busy = true
	map_change_started.emit(map_id)
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.can_move = false
		player.velocity = Vector2.ZERO

	await _tween_fade(1.0)
	main.load_map(load(path), spawn)
	# Đợi 1 frame cho map mới _ready() và camera cập nhật rồi mới sáng lại.
	await get_tree().process_frame
	_arrived_at = Time.get_ticks_msec() / 1000.0
	await _tween_fade(0.0)

	if player:
		player.can_move = true
	_busy = false
	map_change_finished.emit(map_id)


func _tween_fade(alpha: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", alpha, FADE_TIME)
	await tw.finished
