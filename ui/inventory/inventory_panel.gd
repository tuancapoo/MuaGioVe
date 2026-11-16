extends CanvasLayer
## Bảng Túi đồ: Tab (open_journal) mở / đóng. ←/→ chọn món, Esc / Tab đóng.
## Ô bên trái: lưới đồ; bên dưới: tên + mô tả món đang chọn. Chỉ đọc GameState, không tự sửa túi đồ.

const FONT := preload("res://assets/fonts/vt323_regular.ttf")
const COLS := 6
const SLOT := 96.0

var _panel: PanelContainer
var _grid: GridContainer
var _name: Label
var _desc: Label
var _empty: Label
var _slots: Array[Panel] = []
var _ids: Array = []
var _index := 0
var _player: Node


func _ready() -> void:
	layer = 70
	add_to_group(&"inventory_panel")
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override(&"panel", _box(Color(0.07, 0.06, 0.1, 0.94), Color(0.96, 0.78, 0.35), 4, 12, 30))
	center.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 14)
	_panel.add_child(v)
	v.add_child(_text("Túi đồ", 56, Color(0.96, 0.78, 0.35)))
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override(&"h_separation", 12)
	_grid.add_theme_constant_override(&"v_separation", 12)
	v.add_child(_grid)
	_empty = _text("Túi đồ trống.", 40, Color(0.7, 0.68, 0.75))
	v.add_child(_empty)
	_name = _text("", 46, Color(1, 0.97, 0.88))
	v.add_child(_name)
	_desc = _text("", 38, Color(0.85, 0.83, 0.9))
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(COLS * (SLOT + 12), 0)
	v.add_child(_desc)
	v.add_child(_text("←/→ chọn · Tab / Esc đóng", 32, Color(0.55, 0.53, 0.6)))
	hide()
	GameState.changed.connect(func(): if visible: _rebuild())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"open_journal"):
		if visible:
			close()
		elif _can_open():
			open()
		get_viewport().set_input_as_handled()
	elif visible:
		if event.is_action_pressed(&"move_left") or event.is_action_pressed(&"ui_left"):
			_select(_index - 1)
		elif event.is_action_pressed(&"move_right") or event.is_action_pressed(&"ui_right"):
			_select(_index + 1)
		elif event.is_action_pressed(&"ui_up"):
			_select(_index - COLS)
		elif event.is_action_pressed(&"ui_down"):
			_select(_index + COLS)
		elif event.is_action_pressed(&"cancel") or event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
			close()
		get_viewport().set_input_as_handled()


func _can_open() -> bool:
	_player = get_tree().get_first_node_in_group(&"player")
	var wheel := get_tree().get_first_node_in_group(&"action_wheel")
	return _player != null and _player.can_move and not (wheel and wheel.visible)


func open() -> void:
	_player.can_move = false
	_index = 0
	_rebuild()
	show()


func close() -> void:
	hide()
	if _player:
		_player.can_move = true


func _rebuild() -> void:
	for s in _slots:
		s.queue_free()
	_slots.clear()
	_ids = GameState.item_ids()
	_empty.visible = _ids.is_empty()
	for i in _ids.size():
		var id = _ids[i]
		var data := ItemData.get_item(id)
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2.ONE * SLOT
		var icon := TextureRect.new()
		icon.texture = data.icon if data else null
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 14; icon.offset_top = 14; icon.offset_right = -14; icon.offset_bottom = -14
		slot.add_child(icon)
		var count := GameState.item_count(id)
		if count > 1:
			var c := _text("x%d" % count, 30, Color(1, 1, 1))
			c.position = Vector2(SLOT - 40, SLOT - 34)
			slot.add_child(c)
		slot.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: _select(i))
		_grid.add_child(slot)
		_slots.append(slot)
	_select(clampi(_index, 0, maxi(0, _ids.size() - 1)))


func _select(i: int) -> void:
	if _ids.is_empty():
		_name.text = ""
		_desc.text = ""
		return
	_index = clampi(i, 0, _ids.size() - 1)
	for k in _slots.size():
		var sel := k == _index
		_slots[k].add_theme_stylebox_override(&"panel", _box(Color(1, 0.98, 0.92) if sel else Color(0.93, 0.9, 0.82),
			Color(0.96, 0.78, 0.35) if sel else Color(0.17, 0.14, 0.25), 5 if sel else 3, 10, 0))
	var id = _ids[_index]
	var data := ItemData.get_item(id)
	_name.text = ItemData.name_of(id)
	_desc.text = data.description if data else ""


func _text(t: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override(&"font", FONT)
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	return l


static func _box(bg: Color, border: Color, bw: int, radius_px: int, pad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius_px)
	s.set_content_margin_all(pad)
	s.anti_aliasing = false
	return s
