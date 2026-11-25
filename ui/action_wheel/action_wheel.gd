extends CanvasLayer
## Thanh chọn một hàng trên đầu Minh (group "action_wheel"; Main tạo sẵn 1 node).
## Interactable có `actions` gọi open(target, player).
##
## Các ô, theo thứ tự:
##   [Xem] (vật)  [Nói chuyện] (NPC)  [Nhặt] (vật chưa nhặt)  rồi từng món trong túi đồ
## Hiện tối đa VISIBLE ô; mũi tên ◀ ▶ báo còn ô ở bên trái / phải.
## ←/→ (A/D) dịch 1 ô · E / Enter / click chọn · Esc huỷ.
##
## Phím I: mở cùng thanh này nhưng CHỈ có các món trong túi đồ (không có Xem / Nói chuyện / Nhặt).
## Chọn một món → Minh nói mô tả của món đó. Bấm I lần nữa / Esc để đóng.

const ICONS := {
	&"talk": preload("res://assets/ui/icons/action_talk.png"),
	&"examine": preload("res://assets/ui/icons/action_examine.png"),
	&"take": preload("res://assets/ui/icons/action_take.png"),
	&"search": preload("res://assets/ui/icons/action_search.png"),
}
const ICON_ITEM := preload("res://assets/ui/icons/action_use_item.png")
const ARROW_L := preload("res://assets/ui/icons/arrow_left.png")
const ARROW_R := preload("res://assets/ui/icons/arrow_right.png")
const FONT := preload("res://assets/fonts/vt323_regular.ttf")
const VISIBLE := 4

## Kích thước ô, khoảng cách giữa các ô (px màn hình)
@export var bubble_size: float = 84.0
@export var gap: float = 16.0
## Hàng nằm cao hơn đỉnh đầu Minh bao nhiêu (px thế giới, tính từ gốc Player)
@export var head_offset: Vector2 = Vector2(0, -95)

var _target: Interactable          # null = đang mở túi đồ bằng phím I
var _player: Node2D
var _entries: Array = []            # [{action, item, label, icon}]
var _index := 0                     # ô đang chọn (trong toàn bộ danh sách)
var _first := 0                     # ô đầu tiên đang hiện
var _root: Control
var _bubbles: Array[Panel] = []     # VISIBLE ô, tái sử dụng
var _icons: Array[TextureRect] = []
var _arrow_l: TextureRect
var _arrow_r: TextureRect
var _label_panel: PanelContainer
var _label: Label


func _ready() -> void:
	layer = 80
	add_to_group(&"action_wheel")
	_ensure_inventory_action()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	for i in VISIBLE:
		var b := Panel.new()
		b.size = Vector2.ONE * bubble_size
		b.pivot_offset = b.size * 0.5
		var icon := TextureRect.new()
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 14; icon.offset_top = 14; icon.offset_right = -14; icon.offset_bottom = -14
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(icon)
		b.mouse_entered.connect(func(): _select(_first + i))
		b.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: _select(_first + i); _confirm())
		_root.add_child(b)
		_bubbles.append(b)
		_icons.append(icon)
	_arrow_l = _make_arrow(ARROW_L, -1)
	_arrow_r = _make_arrow(ARROW_R, 1)
	_label_panel = PanelContainer.new()
	_label_panel.add_theme_stylebox_override(&"panel", _box(Color(0.07, 0.06, 0.1, 0.9), Color(0.98, 0.95, 0.85), 3, 8, 14))
	_label_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.add_theme_font_override(&"font", FONT)
	_label.add_theme_font_size_override(&"font_size", 44)
	_label.add_theme_color_override(&"font_color", Color(0.98, 0.95, 0.85))
	_label_panel.add_child(_label)
	_root.add_child(_label_panel)
	hide()


func _make_arrow(tex: Texture2D, dir: int) -> TextureRect:
	var a := TextureRect.new()
	a.texture = tex
	a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	a.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	a.size = Vector2(30, 36)
	a.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: _step(dir))
	_root.add_child(a)
	return a


func open(target: Interactable, player: Node2D) -> void:
	_target = target
	_player = player
	_build_entries()
	if _entries.is_empty():
		return
	_player.can_move = false
	_index = 0
	_first = 0
	_refresh()
	show()


## Phím I: thanh chọn chỉ gồm các món trong túi đồ.
func open_inventory(player: Node2D) -> void:
	_target = null
	_player = player
	_build_entries()
	if _entries.is_empty():
		EventBus.toast_requested.emit("Túi đồ đang trống.")
		return
	_player.can_move = false
	_index = 0
	_first = 0
	_refresh()
	show()


func close() -> void:
	hide()
	if is_instance_valid(_player):
		# Đợi 1 frame để phím E vừa bấm không bị Player xử lý lại
		await get_tree().process_frame
		_player.can_move = true


func _build_entries() -> void:
	_entries.clear()
	if _target:
		for a in _target.available_actions():
			_entries.append({"action": a, "item": &"", "label": Interactable.ACTION_NAMES[a], "icon": ICONS[a]})
	if _target == null or _target.show_items:
		for id in GameState.item_ids():
			var data := ItemData.get_item(id)
			var count := GameState.item_count(id)
			_entries.append({"action": &"use_item", "item": StringName(id),
				"label": ItemData.name_of(id) + (" x%d" % count if count > 1 else ""),
				"icon": data.icon if data and data.icon else ICON_ITEM})


# --- Hiển thị ------------------------------------------------------------------------

func _refresh() -> void:
	for i in VISIBLE:
		var k := _first + i
		var b := _bubbles[i]
		b.visible = k < _entries.size()
		if not b.visible:
			continue
		var sel := k == _index
		_icons[i].texture = _entries[k].icon
		var bg := Color(1, 0.98, 0.92) if sel else Color(0.93, 0.9, 0.82)
		var border := Color(0.96, 0.78, 0.35) if sel else Color(0.17, 0.14, 0.25)
		b.add_theme_stylebox_override(&"panel", _box(bg, border, 5 if sel else 4, bubble_size * 0.3, 0))
		b.scale = Vector2.ONE * (1.12 if sel else 1.0)
	_arrow_l.visible = _first > 0
	_arrow_r.visible = _first + VISIBLE < _entries.size()
	_label.text = _entries[_index].label


func _process(_d: float) -> void:
	if not visible or not is_instance_valid(_player):
		return
	var center: Vector2 = _player.get_viewport().get_canvas_transform() * (_player.global_position + head_offset)
	var shown := mini(VISIBLE, _entries.size() - _first)
	var row_w := shown * bubble_size + (shown - 1) * gap
	var x := center.x - row_w * 0.5
	var y := center.y - bubble_size
	for i in VISIBLE:
		_bubbles[i].position = Vector2(x + i * (bubble_size + gap), y)
	_arrow_l.position = Vector2(x - gap - _arrow_l.size.x, y + (bubble_size - _arrow_l.size.y) * 0.5)
	_arrow_r.position = Vector2(x + row_w + gap, y + (bubble_size - _arrow_r.size.y) * 0.5)
	_label_panel.reset_size()
	var sel_x := x + (_index - _first) * (bubble_size + gap) + bubble_size * 0.5
	_label_panel.position = Vector2(sel_x - _label_panel.size.x * 0.5, y - _label_panel.size.y - 18)


# --- Điều khiển -------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		# Phím I mở túi đồ khi Minh đang tự do đi lại
		if event.is_action_pressed(&"open_inventory"):
			var p := get_tree().get_first_node_in_group(&"player") as Player
			if p and p.can_move:
				get_viewport().set_input_as_handled()
				open_inventory(p)
		return
	if _target == null and event.is_action_pressed(&"open_inventory"):
		close()
	elif event.is_action_pressed(&"move_left") or event.is_action_pressed(&"ui_left"):
		_step(-1)
	elif event.is_action_pressed(&"move_right") or event.is_action_pressed(&"ui_right"):
		_step(1)
	elif event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept"):
		_confirm()
	elif event.is_action_pressed(&"cancel") or event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		close()
	else:
		return
	get_viewport().set_input_as_handled()


## Dịch 1 ô; cuộn hàng khi ô chọn ra khỏi khung 4 ô.
func _step(dir: int) -> void:
	_select(clampi(_index + dir, 0, _entries.size() - 1))


func _select(i: int) -> void:
	if i < 0 or i >= _entries.size():
		return
	_index = i
	if _index < _first:
		_first = _index
	elif _index >= _first + VISIBLE:
		_first = _index - VISIBLE + 1
	_refresh()


func _confirm() -> void:
	var e: Dictionary = _entries[_index]
	var target := _target
	var player := _player
	await close()
	if target:
		target.choose(e.action, player, e.item)
	else:
		_describe_item(e.item)


## Túi đồ (phím I): Minh nói mô tả món được chọn.
func _describe_item(item_id: StringName) -> void:
	var data := ItemData.get_item(item_id)
	var desc := data.description.strip_edges().replace("\n", " ") if data else ""
	if desc.is_empty():
		desc = "(%s.)" % ItemData.name_of(item_id)
	var res = DialogueManager.create_resource_from_text("~ start" + "\n" + "Minh: " + desc + "\n" + "=> END" + "\n")
	DialogueManager.show_dialogue_balloon(res, "start")


## Phím I mở túi đồ (tạo lúc chạy nếu project.godot chưa khai báo action "open_inventory").
func _ensure_inventory_action() -> void:
	if InputMap.has_action(&"open_inventory"):
		return
	InputMap.add_action(&"open_inventory")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_I
	InputMap.action_add_event(&"open_inventory", ev)


static func _box(bg: Color, border: Color, bw: int, radius_px: float, pad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(int(radius_px))
	s.content_margin_left = pad; s.content_margin_right = pad
	s.content_margin_top = pad * 0.4; s.content_margin_bottom = pad * 0.4
	s.anti_aliasing = false
	return s
