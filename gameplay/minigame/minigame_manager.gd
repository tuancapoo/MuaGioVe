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

	# Khoá & đóng băng Player để không bị rơi xuyên sàn khi World tạm dừng
	_player_node = get_tree().get_first_node_in_group(&"player")
	if _player_node:
		_player_node.can_move = false
		if "velocity" in _player_node:
			_player_node.velocity = Vector2.ZERO
		var footsteps := _player_node.get_node_or_null("Footsteps") as AudioStreamPlayer
		if footsteps and footsteps.playing:
			footsteps.stop()
		if _player_node is Node2D:
			_saved_player_pos = (_player_node as Node2D).global_position
		_prev_player_process_mode = _player_node.process_mode
		_player_node.process_mode = Node.PROCESS_MODE_DISABLED

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

		# Nếu quest trùng tên minigame đang active, đánh dấu hoàn thành
		if GameState.is_quest_active(minigame_id):
			GameState.complete_quest(minigame_id)

	# Đóng minigame và khôi phục World
	if is_instance_valid(_active_minigame):
		_active_minigame.queue_free()
	_active_minigame = null
	_active_id = ""

	if is_instance_valid(_world_node):
		_world_node.process_mode = _prev_world_process_mode
	_world_node = null

	# Đợi 1 frame để physics của map (StaticBody2D mặt đất) bật lại trước khi mở Player
	await get_tree().process_frame
	if is_instance_valid(_player_node):
		if _player_node is Node2D:
			(_player_node as Node2D).global_position = _saved_player_pos
		if "velocity" in _player_node:
			_player_node.velocity = Vector2.ZERO
		_player_node.process_mode = _prev_player_process_mode
		if not _dialogue_open:
			_player_node.can_move = true
	_player_node = null

	EventBus.minigame_finished.emit(minigame_id, result)
	minigame_closed.emit(minigame_id, result)
