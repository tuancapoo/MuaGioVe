extends Node
## Mở đầu Chương 1 trong phòng ngủ Minh ở quê:
## 1. Màn hình đen → tiếng Ông Nội gọi Minh dậy sửa ống nước ở luống rau.
## 2. Màn hình sáng dần → Minh đứng cạnh giường trong phòng ngủ ở quê.
## 3. Cho phép Minh tự do đi ra phòng khách → ra sân (yard) gặp Ông Nội.

const DIALOGUE_PATH := "res://data/dialogues/ch1_pipe_intro.dialogue"
const FLAG_MORNING_DONE := "ch1.morning_intro_done"

var _overlay_layer: CanvasLayer
var _fade_rect: ColorRect


func _ready() -> void:
	if GameState.chapter != 1 or GameState.has_flag(FLAG_MORNING_DONE):
		return

	# Che đen ngay từ frame đầu để không bị nháy sáng trước khi Ông Nội gọi
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "Ch1MorningOverlay"
	_overlay_layer.layer = 85 # Dưới DialogueBalloon (100) để hộp thoại hiện trên nền đen
	add_child(_overlay_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 1)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay_layer.add_child(_fade_rect)

	call_deferred("_run_morning_intro")


func _run_morning_intro() -> void:
	# Đợi 1 frame để Main đặt Minh cạnh giường xong
	await get_tree().process_frame
	if not is_inside_tree():
		return

	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player:
		player.lock(&"ch1_morning_intro")
		player.anim.flip_h = false # Đứng cạnh giường, hướng mặt vào trong phòng

	await get_tree().create_timer(0.45).timeout
	if not is_inside_tree():
		return

	# Tiếng Ông Nội gọi từ ngoài sân trên nền màn hình đen
	var dlg := _load_dialogue()
	if dlg:
		DialogueManager.show_dialogue_balloon(dlg, "morning_wakeup")
		await DialogueManager.dialogue_ended

	if not is_inside_tree():
		return

	await get_tree().create_timer(0.25).timeout
	if not is_inside_tree():
		return

	# Sáng dần hiện ra phòng ngủ Minh ở quê, Minh đứng cạnh giường
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 0.0, 1.1)
	await tw.finished
	if not is_inside_tree():
		return

	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.set_flag(FLAG_MORNING_DONE, true)

	if is_instance_valid(_overlay_layer):
		_overlay_layer.queue_free()
	if is_instance_valid(player):
		player.unlock(&"ch1_morning_intro")


func _load_dialogue() -> DialogueResource:
	if FileAccess.file_exists(DIALOGUE_PATH):
		var raw := FileAccess.get_file_as_string(DIALOGUE_PATH)
		if not raw.is_empty():
			return DialogueManager.create_resource_from_text(raw)
	if ResourceLoader.exists(DIALOGUE_PATH):
		return load(DIALOGUE_PATH) as DialogueResource
	return null
