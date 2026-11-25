extends Node
## Autoload "MinigameManager": mở / đóng mini-game từ thế giới hoặc hội thoại (Hệ thống S2).
##
## Cách gọi:
##   MinigameManager.start("fishing", {"target": 5})
##   (hoặc trong .dialogue: do MinigameManager.start("fishing"))
##
## Luồng (theo docs/HE_THONG.md mục 10):
##   1. Khoá Minh, tạm dừng World (process_mode = DISABLED).
##   2. Mở res://gameplay/minigame/<id>/<id>.tscn trên CanvasLayer riêng (layer 75).
##   3. Khi minigame phát finished(result):
##      - Nếu thắng (result.success == true):
##        + Bật cờ minigame.<id>.won, cập nhật minigame.<id>.best_score
##        + Thưởng vật phẩm (item_id, amount) vào túi đồ và Hạt Gió (lần đầu + Tinh tế)
##      - Mở lại World, mở khoá Minh, phát EventBus.minigame_finished(id, result).

signal minigame_started(minigame_id: String)
signal minigame_closed(minigame_id: String, result: Dictionary)

const MINIGAME_PATH := "res://gameplay/minigame/%s/%s.tscn"

var _layer: CanvasLayer
var _active_minigame: MinigameBase = null
var _active_id: String = ""
var _world_node: Node = null
var _prev_world_process_mode: Node.ProcessMode = Node.PROCESS_MODE_INHERIT
var _player_node: Node = null
var _prev_player_process_mode: Node.ProcessMode = Node.PROCESS_MODE_INHERIT
var _saved_player_pos: Vector2 = Vector2.ZERO
var _dialogue_open: bool = false
var _saved_player: Node2D = null
var _saved_player_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "MinigameLayer"
	_layer.layer = 75
	add_child(_layer)
	DialogueManager.dialogue_started.connect(func(_r): _dialogue_open = true)
	DialogueManager.dialogue_ended.connect(func(_r): _dialogue_open = false)


func is_running() -> bool:
	return is_instance_valid(_active_minigame)


## Mở một mini-game theo id (vd: "fishing", "melon_stealth").
func start(minigame_id: String, params: Dictionary = {}) -> void:
	if is_running():
		push_warning("MinigameManager: đang chạy '%s', bỏ qua lệnh mở '%s'" % [_active_id, minigame_id])
		return

	var path := MINIGAME_PATH % [minigame_id, minigame_id]
	if not ResourceLoader.exists(path):
		push_error("MinigameManager: không tìm thấy scene '%s'" % path)
		return

	var packed := load(path) as PackedScene
	if packed == null:
		push_error("MinigameManager: không nạp được '%s'" % path)
		return

	# Khoá Player và dừng World
	var player := get_tree().get_first_node_in_group(&"player")
	_saved_player = player as Node2D
	if is_instance_valid(_saved_player):
		_saved_player_position = _saved_player.global_position
	if player:
		player.can_move = false
		if "velocity" in player:
			player.velocity = Vector2.ZERO

	var main := get_tree().current_scene
	_world_node = main.get_node_or_null("World") if main else null
	if _world_node:
		_prev_world_process_mode = _world_node.process_mode
		_world_node.process_mode = Node.PROCESS_MODE_DISABLED

	_active_id = minigame_id
	_active_minigame = packed.instantiate() as MinigameBase
	_layer.add_child(_active_minigame)
	_active_minigame.setup(params)
	_active_minigame.finished.connect(_on_minigame_finished.bind(minigame_id))
	minigame_started.emit(minigame_id)


func _on_minigame_finished(result: Dictionary, minigame_id: String) -> void:
	var success := bool(result.get("success", false))
	if success:
		GameState.set_flag("minigame.%s.won" % minigame_id, true)
		var score := int(result.get("score", 0))
		var best := int(GameState.get_flag("minigame.%s.best_score" % minigame_id, 0))
		if score > best:
			GameState.set_flag("minigame.%s.best_score" % minigame_id, score)

		# Thưởng vật phẩm câu / thu hoạch được vào túi đồ
		var item_id := String(result.get("item_id", ""))
		var amount := int(result.get("amount", 0))
		if not item_id.is_empty() and amount > 0:
			GameState.add_item(item_id, amount, true)

		# Thưởng Hạt Gió lần đầu hoàn thành (Bảng 63: 1 Hạt Gió cho màn 1.2)
		var reward_flag := "minigame.%s.rewarded" % minigame_id
		if not GameState.has_flag(reward_flag):
			GameState.set_flag(reward_flag, true)
			var seeds := int(result.get("wind_seeds", 1))
			if seeds > 0:
				GameState.add_wind_seeds(seeds)
				EventBus.toast_requested.emit("+%d Hạt Gió" % seeds)

		# Thưởng Hạt Gió cho thành tích "Tinh tế" (Bảng 40 & Bảng 63: ≤ 3 lần cá thoát → +1 Hạt Gió)
		if bool(result.get("flawless", false)):
			GameState.set_flag("minigame.%s.flawless" % minigame_id, true)
			var flawless_flag := "minigame.%s.flawless_rewarded" % minigame_id
			if not GameState.has_flag(flawless_flag):
				GameState.set_flag(flawless_flag, true)
				GameState.add_wind_seeds(1)
				EventBus.toast_requested.emit("+1 Hạt Gió (Tinh tế!)")

		# fix_pipe được hoàn thành ngay khi lắp xong kẹp, không đợi đóng minigame.
		if minigame_id != "fix_pipe" and GameState.is_quest_active(minigame_id):
			GameState.complete_quest(minigame_id)

	# Đóng minigame và khôi phục World
	if is_instance_valid(_active_minigame):
		_active_minigame.queue_free()
	_active_minigame = null
	_active_id = ""

	if is_instance_valid(_world_node):
		_world_node.process_mode = _prev_world_process_mode
	_world_node = null

	# Khôi phục Player đúng scene chính, không đổi map / không tạo Player mới.
	await get_tree().process_frame
	var player := _saved_player
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as Node2D
	if is_instance_valid(player):
		# World đã bật lại trước khi can thiệp Player.
		player.process_mode = Node.PROCESS_MODE_INHERIT
		player.show()
		var visual := player.get_node_or_null("AnimatedSprite2D") as CanvasItem
		if visual:
			visual.show()
		# Nếu vị trí bị ghi đè trái ý muốn trong minigame, đưa Minh về chỗ cũ.
		if player.global_position.distance_to(_saved_player_position) > 256.0:
			player.global_position = _saved_player_position
		var camera := player.get_node_or_null("Camera2D") as Camera2D
		if camera:
			camera.enabled = true
			camera.make_current()
		if not _dialogue_open:
			player.set("can_move", true)
		print("[MinigameManager] player=", player.get_path(),
			" visible=", player.is_visible_in_tree(),
			" pos=", player.global_position,
			" camera=", camera != null)
	else:
		push_error("[MinigameManager] Player không còn trong scene sau minigame!")
	_saved_player = null
	EventBus.minigame_finished.emit(minigame_id, result)
	minigame_closed.emit(minigame_id, result)
