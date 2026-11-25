extends CanvasLayer
## Ô hiển thị nhiệm vụ hiện tại ở góc trên trái màn hình (đồng bộ phong cách với HUD Chương 0).
## Tự cập nhật theo GameState và tự ẩn ở Chương 0, lúc màn hình đen mở đầu, hoặc khi chạy minigame.

const FONT := preload("res://assets/fonts/vt323_regular.ttf")
const FISH_TARGET := 5
const MELON_TARGET := 4

var _panel: PanelContainer
var _title_label: Label
var _sub_label: Label


func _ready() -> void:
	layer = 48
	_build_ui()
	GameState.changed.connect(_refresh)
	EventBus.map_changed.connect(func(_map_id: String) -> void: _refresh())
	MinigameManager.minigame_started.connect(func(_id: String) -> void: _refresh())
	MinigameManager.minigame_closed.connect(func(_id: String, _res: Dictionary) -> void: _refresh())
	_refresh()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.11, 0.84)
	sb.border_color = Color(0.78, 0.76, 0.88, 0.78)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 20
	sb.content_margin_right = 22
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	sb.anti_aliasing = false
	_panel.add_theme_stylebox_override(&"panel", sb)
	_panel.position = Vector2(36, 32)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override(&"separation", 2)
	_panel.add_child(vb)

	_title_label = Label.new()
	_title_label.add_theme_font_override(&"font", FONT)
	_title_label.add_theme_font_size_override(&"font_size", 40)
	_title_label.add_theme_color_override(&"font_color", Color(0.96, 0.84, 0.46))
	vb.add_child(_title_label)

	_sub_label = Label.new()
	_sub_label.add_theme_font_override(&"font", FONT)
	_sub_label.add_theme_font_size_override(&"font_size", 34)
	_sub_label.add_theme_color_override(&"font_color", Color(0.94, 0.93, 0.96))
	_sub_label.hide()
	vb.add_child(_sub_label)

	_panel.hide()


func _refresh() -> void:
	if _panel == null:
		return

	if GameState.chapter != 1 or MinigameManager.is_running():
		_panel.hide()
		return

	if not GameState.has_flag("ch1.morning_intro_done") and GameState.current_map == "phong_ngu_minh":
		_panel.hide()
		return

	if GameState.is_quest_active("steal_melon") or (GameState.current_map == "ruong_dua" and GameState.has_flag("ch1.melon_intro_done") and not GameState.is_quest_done("steal_melon")):
		var melons: int = GameState.item_count("watermelon")
		if melons >= MELON_TARGET:
			GameState.complete_quest("steal_melon")
			EventBus.toast_requested.emit("Hoàn thành: Trộm dưa hấu!")
			_panel.hide()
			return
		_show_quest("Trộm dưa hấu", "Hái dưa hấu (%d/%d)" % [melons, MELON_TARGET])
		return

	if not GameState.is_quest_done("fix_pipe"):
		_show_quest("Sửa ống nước")
		return

	if GameState.has_flag("ch1.chase_an_fishing"):
		_show_quest("Đuổi theo An")
		return

	if GameState.has_flag("ch1.arrived_fishing_spot") and not GameState.is_quest_done("catch_fish"):
		var fish_count: int = GameState.item_count("fish")
		if fish_count >= FISH_TARGET:
			GameState.complete_quest("catch_fish")
			EventBus.toast_requested.emit("Hoàn thành: Câu 5 con cá!")
			_panel.hide()
			return
		_show_quest("Câu cá", "Câu 5 con cá (%d/%d)" % [fish_count, FISH_TARGET])
		return

	_panel.hide()


func _show_quest(title: String, sub: String = "") -> void:
	_title_label.text = title
	if sub.is_empty():
		_sub_label.hide()
	else:
		_sub_label.text = sub
		_sub_label.show()
	_panel.reset_size()
	_panel.show()
