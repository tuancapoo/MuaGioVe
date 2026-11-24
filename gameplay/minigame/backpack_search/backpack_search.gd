class_name BackpackSearch
extends CanvasLayer
## Cảnh tương tác Balo (Chương 0 — Phòng Minh ở thành phố).
## Kết hợp Point & Click và Drag & Drop, khắc hoạ trải nghiệm tiêu cực của Minh ở trường cũ:
##   1. Bấm vào balo để mở khoá.
##   2. Kéo (Drag & Drop) lần lượt từng thứ ra ngoài balo:
##      - Cuốn tập bị xé, chi chít dòng chữ bắt nạt
##      - Bài kiểm tra điểm thấp (0 điểm)
##   3. Lộ ra chiếc điện thoại dưới đáy balo → bấm hoặc kéo ra để lấy.

signal phone_collected
signal closed(got_phone: bool)

enum Stage { CLOSED, SEARCHING, COLLECTED }

const FONT := preload("res://assets/fonts/vt323_regular.ttf")
const SFX_CLICK := "res://assets/audio/sfx/typing/key_02.wav"
const SFX_RUSTLE := "res://assets/audio/sfx/fishing/cast.wav"
const SFX_DROP := "res://assets/audio/sfx/typing/key_01.wav"
const SFX_PICKUP := "res://assets/audio/sfx/fishing/catch.wav"

const BAG_DROP_RADIUS := 220.0
const CLICK_DRAG_THRESHOLD := 12.0

var _stage: Stage = Stage.CLOSED
var _player: Player = null
var _t: float = 0.0
var _open_anim: float = 0.0
var _shake: float = 0.0
var _mood_flash: float = 0.0
var _phone_take_anim: float = 0.0
var _closing: bool = false

## Danh sách 3 lớp đồ trong balo, sắp từ đáy lên đỉnh (index 0 = đáy, index 2 = trên cùng)
## Mỗi phần tử: { id, size, pos, rest_pos, rot, removed, unlocked, hover, visible }
var _items: Array[Dictionary] = []
var _dragging_idx: int = -1
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _bag_hovered: bool = false
var _hover_tooltip: String = ""

var _canvas: Control
var _step_label: Label
var _thought_label: Label
var _close_btn: Button
var _sfx: AudioStreamPlayer


func open(player: Player) -> void:
	_player = player
	if _player:
		_player.lock(&"backpack_search")
	show()


func _ready() -> void:
	layer = 78
	_sfx = AudioStreamPlayer.new()
	_sfx.volume_db = -8.0
	add_child(_sfx)
	_build_ui()
	_init_items()
	_update_step_hint()
	_set_thought("Chiếc balo đi học cũ của mình... Cái điện thoại chắc nằm đâu trong này.")


func _build_ui() -> void:
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_on_draw_stage)
	add_child(_canvas)

	# Thanh hướng dẫn phía trên
	var top_panel := PanelContainer.new()
	top_panel.add_theme_stylebox_override(&"panel", _panel_box(Color(0.06, 0.06, 0.11, 0.90), Color(0.88, 0.84, 0.72, 0.85), 3, 10, 22, 10))
	top_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top_panel.offset_top = 28
	top_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(top_panel)

	_step_label = Label.new()
	_step_label.add_theme_font_override(&"font", FONT)
	_step_label.add_theme_font_size_override(&"font_size", 42)
	_step_label.add_theme_color_override(&"font_color", Color(0.98, 0.94, 0.82))
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_panel.add_child(_step_label)

	# Nút đóng góc trên phải
	_close_btn = Button.new()
	_close_btn.text = "Đóng [Esc]"
	_close_btn.add_theme_font_override(&"font", FONT)
	_close_btn.add_theme_font_size_override(&"font_size", 36)
	_close_btn.add_theme_color_override(&"font_color", Color(0.88, 0.86, 0.94))
	_close_btn.add_theme_color_override(&"font_hover_color", Color(1.0, 0.95, 0.72))
	_close_btn.add_theme_stylebox_override(&"normal", _panel_box(Color(0.09, 0.09, 0.15, 0.92), Color(0.55, 0.54, 0.68), 3, 8, 18, 6))
	_close_btn.add_theme_stylebox_override(&"hover", _panel_box(Color(0.15, 0.14, 0.22, 0.96), Color(0.96, 0.84, 0.48), 3, 8, 18, 6))
	_close_btn.add_theme_stylebox_override(&"pressed", _panel_box(Color(0.12, 0.12, 0.19, 0.96), Color(1.0, 0.92, 0.62), 3, 8, 18, 6))
	_close_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_close_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_close_btn.offset_left = -240
	_close_btn.offset_right = -32
	_close_btn.offset_top = 28
	_close_btn.offset_bottom = 86
	_close_btn.pressed.connect(_close_self)
	_canvas.add_child(_close_btn)

	# Khung tự sự của Minh phía dưới (nở lên trên khi text xuống 2-3 dòng để không bị cắt mép dưới)
	var thought_panel := PanelContainer.new()
	thought_panel.add_theme_stylebox_override(&"panel", _panel_box(Color(0.05, 0.05, 0.10, 0.93), Color(0.45, 0.62, 0.95, 0.92), 3, 10, 30, 14))
	thought_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	thought_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	thought_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	thought_panel.offset_bottom = -36
	thought_panel.offset_top = -36
	thought_panel.custom_minimum_size = Vector2(980, 126)
	thought_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(thought_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override(&"separation", 2)
	thought_panel.add_child(vb)

	var speaker := Label.new()
	speaker.text = "Minh"
	speaker.add_theme_font_override(&"font", FONT)
	speaker.add_theme_font_size_override(&"font_size", 36)
	speaker.add_theme_color_override(&"font_color", Color(0.58, 0.74, 1.0))
	vb.add_child(speaker)

	_thought_label = Label.new()
	_thought_label.add_theme_font_override(&"font", FONT)
	_thought_label.add_theme_font_size_override(&"font_size", 40)
	_thought_label.add_theme_color_override(&"font_color", Color(0.95, 0.95, 0.98))
	_thought_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_thought_label.custom_minimum_size = Vector2(920, 0)
	vb.add_child(_thought_label)


func _init_items() -> void:
	var c := _bag_center()
	_items = [
		{
			"id": &"phone",
			"name": "Điện thoại",
			"size": Vector2(128, 214),
			"pos": c + Vector2(6, 22),
			"rest_pos": c + Vector2(6, 22),
			"rot": -0.06,
			"removed": false,
			"unlocked": false,
			"hover": false,
			"visible": true,
		},
		{
			"id": &"exam",
			"name": "Bài kiểm tra 0 điểm",
			"size": Vector2(224, 276),
			"pos": c + Vector2(-14, 10),
			"rest_pos": c + Vector2(-14, 10),
			"rot": 0.08,
			"removed": false,
			"unlocked": false,
			"hover": false,
			"visible": true,
		},
		{
			"id": &"notebook",
			"name": "Cuốn tập bị xé",
			"size": Vector2(236, 286),
			"pos": c + Vector2(10, 4),
			"rest_pos": c + Vector2(10, 4),
			"rot": -0.07,
			"removed": false,
			"unlocked": true, # Lớp trên cùng mở khoá trước tiên
			"hover": false,
			"visible": true,
		},
	]


func _bag_center() -> Vector2:
	var sz := _canvas.size if _canvas and _canvas.size.x > 10.0 else Vector2(1920, 1080)
	return Vector2(sz.x * 0.5, sz.y * 0.46)


func _bag_rect() -> Rect2:
	var c := _bag_center()
	return Rect2(c - Vector2(205, 225), Vector2(410, 450))


func _process(delta: float) -> void:
	_t += delta
	if _stage != Stage.CLOSED:
		_open_anim = minf(1.0, _open_anim + delta * 4.5)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 3.8)
	if _mood_flash > 0.0:
		_mood_flash = maxf(0.0, _mood_flash - delta * 1.4)
	if _stage == Stage.COLLECTED:
		_phone_take_anim = minf(1.0, _phone_take_anim + delta * 2.4)

	# Giữ item chưa lấy ra luôn bám tâm màn hình nếu cửa sổ thay đổi kích thước
	var c := _bag_center()
	var offsets: Array[Vector2] = [Vector2(6, 22), Vector2(-14, 10), Vector2(10, 4)]
	for i in _items.size():
		if not _items[i].removed and _dragging_idx != i:
			var target: Vector2 = c + offsets[i]
			var cur_pos: Vector2 = _items[i].pos
			_items[i].rest_pos = target
			_items[i].pos = cur_pos.lerp(target, clampf(delta * 12.0, 0.0, 1.0))

	_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if _closing:
		return

	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"cancel") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_self()
		return

	# Chặn các phím gameplay phía dưới (đi lại, mở túi đồ, tương tác) khi đang mở balo
	if event is InputEventKey and event.pressed:
		if _stage == Stage.COLLECTED and (event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept")):
			get_viewport().set_input_as_handled()
			_close_self()
			return
		if event.is_action_pressed(&"open_journal") or event.is_action_pressed(&"open_inventory") or event.is_action_pressed(&"interact"):
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion:
		var mpos := (event as InputEventMouseMotion).position
		_handle_mouse_move(mpos)
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if _close_btn.get_global_rect().has_point(mb.position):
				return # để nút Đóng xử lý
			if mb.pressed:
				_handle_mouse_down(mb.position)
			else:
				_handle_mouse_up(mb.position)
			get_viewport().set_input_as_handled()


func _handle_mouse_move(mpos: Vector2) -> void:
	if _dragging_idx >= 0:
		var sz := _canvas.size
		var clamped := Vector2(clampf(mpos.x + _drag_offset.x, 120.0, sz.x - 120.0), clampf(mpos.y + _drag_offset.y, 140.0, sz.y - 190.0))
		_items[_dragging_idx].pos = clamped
		_canvas.mouse_default_cursor_shape = Control.CURSOR_DRAG
		return

	_bag_hovered = false
	_hover_tooltip = ""
	for it in _items:
		it.hover = false

	if _stage == Stage.CLOSED:
		_bag_hovered = _bag_rect().has_point(mpos)
		if _bag_hovered:
			_hover_tooltip = "Bấm để mở balo"
			_canvas.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		else:
			_canvas.mouse_default_cursor_shape = Control.CURSOR_ARROW
		return

	if _stage == Stage.SEARCHING:
		var top_idx := _hit_test_items(mpos)
		if top_idx >= 0:
			_items[top_idx].hover = true
			var it := _items[top_idx]
			if it.id == &"phone" and it.unlocked:
				_hover_tooltip = "Điện thoại — Bấm hoặc kéo ra để lấy"
				_canvas.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			elif not it.removed and it.unlocked:
				_hover_tooltip = "%s — Giữ chuột kéo ra khỏi balo" % it.name
				_canvas.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			elif it.removed:
				_hover_tooltip = "%s — Bấm để xem lại" % it.name
				_canvas.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			else:
				_canvas.mouse_default_cursor_shape = Control.CURSOR_ARROW
		else:
			_canvas.mouse_default_cursor_shape = Control.CURSOR_ARROW


func _handle_mouse_down(mpos: Vector2) -> void:
	if _stage == Stage.COLLECTED:
		_close_self()
		return

	if _stage == Stage.CLOSED:
		if _bag_rect().has_point(mpos):
			_open_backpack()
		return

	if _stage == Stage.SEARCHING:
		var idx := _hit_test_items(mpos)
		if idx < 0:
			return
		var it := _items[idx]
		if not it.unlocked:
			return
		if it.removed:
			_inspect_removed_item(it.id)
			return
		# Bắt đầu kéo món đang mở khoá (hoặc bấm lấy điện thoại)
		_dragging_idx = idx
		_drag_start_mouse = mpos
		_drag_offset = (it.pos as Vector2) - mpos
		_play_sfx(SFX_RUSTLE, 1.15)


func _handle_mouse_up(mpos: Vector2) -> void:
	if _dragging_idx < 0:
		return
	var idx := _dragging_idx
	var it := _items[idx]
	_dragging_idx = -1
	_canvas.mouse_default_cursor_shape = Control.CURSOR_ARROW

	var item_pos: Vector2 = it.pos
	var dist_moved: float = mpos.distance_to(_drag_start_mouse)
	var dist_from_bag: float = item_pos.distance_to(_bag_center())

	# Chiếc điện thoại: bấm (Point & Click) HOẶC kéo ra ngoài đều lấy được!
	if it.id == &"phone":
		if dist_moved <= CLICK_DRAG_THRESHOLD or dist_from_bag >= BAG_DROP_RADIUS * 0.65:
			_collect_phone()
		return

	# Cuốn tập bị xé & Bài kiểm tra 0 điểm: chỉ cần kéo ra khỏi balo là được
	var outside_bag := not _bag_rect().has_point(item_pos) or dist_from_bag >= BAG_DROP_RADIUS
	if outside_bag:
		it.removed = true
		it.rot = -0.14 if item_pos.x < _bag_center().x else 0.14
		_play_sfx(SFX_DROP, 0.85)
		_on_item_dragged_out(it.id)
	else:
		# Thả vẫn nằm trong balo → trượt lại vào trong
		_play_sfx(SFX_DROP, 1.1)
		_set_thought("Kéo nó ra khỏi balo để bới tiếp...")


func _open_backpack() -> void:
	_stage = Stage.SEARCHING
	_open_anim = 0.0
	_shake = 0.35
	_play_sfx(SFX_RUSTLE, 0.92)
	_update_step_hint()
	_set_thought("Balo mở rồi... Mùi giấy cũ ẩm mốc. Kéo mấy thứ nằm trên ra để tìm điện thoại.")


func _on_item_dragged_out(id: StringName) -> void:
	if id == &"notebook":
		_items[1].unlocked = true # Mở khoá bài kiểm tra 0 điểm
		_shake = 0.45
		_mood_flash = 0.85
		_set_thought("...Cuốn tập bị tụi nó xé nát, viết đầy chữ bắt nạt. Mình không muốn nhìn nữa...")
	elif id == &"exam":
		_items[0].unlocked = true # Mở khoá điện thoại ở đáy balo
		_shake = 0.40
		_mood_flash = 0.75
		_set_thought("...Bài kiểm tra 0 điểm. Hôm đó mình chẳng viết nổi chữ nào. Ơ, dưới đáy có ánh sáng kìa!")
	_update_step_hint()


func _inspect_removed_item(id: StringName) -> void:
	_play_sfx(SFX_CLICK, 0.9)
	if id == &"notebook":
		_set_thought("\"Đồ yếu đuối\", \"Cút đi\"... Mình chỉ muốn quên hết mấy chuyện ở trường cũ.")
	elif id == &"exam":
		_set_thought("Điểm 0 đỏ chót... Chắc đây cũng là một lý do bố đưa mình về quê.")


func _collect_phone() -> void:
	if _stage == Stage.COLLECTED:
		return
	_stage = Stage.COLLECTED
	_items[0].removed = true
	_items[0].visible = false
	_phone_take_anim = 0.0
	_play_sfx(SFX_PICKUP, 1.0)

	GameState.set_flag("ch0.got_phone", true)
	GameState.add_item("phone", 1, true)
	_update_step_hint()
	_set_thought("Đây rồi! Chiếc điện thoại vẫn còn ở dưới đáy balo.")
	phone_collected.emit()

	await get_tree().create_timer(1.35).timeout
	if is_inside_tree() and not _closing:
		_close_self()


func _close_self() -> void:
	if _closing:
		return
	_closing = true
	var got_phone := GameState.has_flag("ch0.got_phone")
	if is_instance_valid(_player):
		_player.unlock(&"backpack_search")
	closed.emit(got_phone)
	queue_free()


func _update_step_hint() -> void:
	if _stage == Stage.CLOSED:
		_step_label.text = "Bấm vào balo để mở"
	elif _stage == Stage.COLLECTED:
		_step_label.text = "Đã tìm thấy điện thoại!"
	elif not _items[2].removed:
		_step_label.text = "Giữ chuột kéo cuốn tập bị xé ra khỏi balo"
	elif not _items[1].removed:
		_step_label.text = "Giữ chuột kéo bài kiểm tra 0 điểm ra khỏi balo"
	else:
		_step_label.text = "Bấm hoặc kéo chiếc điện thoại để lấy"


func _set_thought(text: String) -> void:
	if _thought_label:
		_thought_label.text = text


func _hit_test_items(mpos: Vector2) -> int:
	# Ưu tiên món chưa kéo ra ở trên cùng (index cao → thấp), rồi mới tới món đã thả ngoài sàn
	for i in range(_items.size() - 1, -1, -1):
		var it := _items[i]
		if not it.visible or not it.unlocked or it.removed:
			continue
		if _point_in_item(mpos, it):
			return i
	for i in range(_items.size() - 1, -1, -1):
		var it := _items[i]
		if not it.visible or not it.unlocked or not it.removed:
			continue
		if _point_in_item(mpos, it):
			return i
	return -1


func _point_in_item(p: Vector2, it: Dictionary) -> bool:
	var item_pos: Vector2 = it.pos
	var local: Vector2 = (p - item_pos).rotated(-float(it.rot))
	var half: Vector2 = (it.size as Vector2) * 0.5
	return absf(local.x) <= half.x and absf(local.y) <= half.y


func _play_sfx(path: String, pitch: float = 1.0) -> void:
	if _sfx and ResourceLoader.exists(path):
		_sfx.stream = load(path)
		_sfx.pitch_scale = pitch
		_sfx.play()


# ==============================================================================
# VẼ GIAO DIỆN & ĐỒ VẬT TRONG BALO
# ==============================================================================

func _on_draw_stage() -> void:
	var sz := _canvas.size
	var shake_off := Vector2(sin(_t * 58.0), cos(_t * 47.0)) * (8.0 * _shake)
	var center := _bag_center() + shake_off

	# 1. Nền tối mô phỏng sàn phòng Minh lúc cúi xuống mở balo
	_canvas.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.05, 0.05, 0.09, 0.90))
	# Vầng sáng nhẹ mờ trên sàn gạch quanh balo
	_draw_circle_soft(center + Vector2(0, 20), 420.0, Color(0.14, 0.16, 0.28, 0.28))
	_draw_circle_soft(center + Vector2(0, 10), 260.0, Color(0.20, 0.22, 0.36, 0.22))

	# Kẻ gạch mờ dưới sàn để khớp phòng thành phố
	var tile := 120.0
	var grid_col := Color(0.18, 0.19, 0.28, 0.14)
	var x := fmod(center.x, tile)
	while x < sz.x:
		_canvas.draw_line(Vector2(x, 0), Vector2(x, sz.y), grid_col, 2.0)
		x += tile
	var y := fmod(center.y, tile)
	while y < sz.y:
		_canvas.draw_line(Vector2(0, y), Vector2(sz.x, y), grid_col, 2.0)
		y += tile

	# 2. Vẽ balo (lớp sau / mở miệng)
	if _stage == Stage.CLOSED:
		_draw_backpack_closed(center)
	else:
		_draw_backpack_open_back(center)
		# Vẽ các món nằm TRONG balo theo thứ tự đáy → đỉnh
		for i in _items.size():
			if _items[i].visible and not _items[i].removed and _dragging_idx != i:
				_draw_item(_items[i], shake_off, false)
		# Vẽ mép trước balo chồng nhẹ lên phần đáy đồ
		_draw_backpack_open_front(center)

		# Vẽ các món ĐÃ KÉO RA NGOÀI nằm trên sàn
		for i in _items.size():
			if _items[i].visible and _items[i].removed and _dragging_idx != i:
				_draw_item(_items[i], shake_off, false)

		# Vẽ món ĐANG ĐƯỢC KÉO ở trên cùng
		if _dragging_idx >= 0:
			_draw_item(_items[_dragging_idx], Vector2.ZERO, true)

	# 3. Hiệu ứng ánh chớp buồn / nặng nề khi kéo thấy đồ bị bắt nạt / 0 điểm
	if _mood_flash > 0.01:
		var edge_col := Color(0.45, 0.08, 0.14, 0.24 * _mood_flash)
		_canvas.draw_rect(Rect2(Vector2.ZERO, sz), edge_col)

	# 4. Tooltip nhỏ cạnh con trỏ
	if not _hover_tooltip.is_empty() and _dragging_idx < 0:
		var m := _canvas.get_local_mouse_position()
		var tsize := FONT.get_string_size(_hover_tooltip, HORIZONTAL_ALIGNMENT_LEFT, -1, 32)
		var box_pos := Vector2(clampf(m.x - tsize.x * 0.5, 24.0, sz.x - tsize.x - 44.0), maxf(108.0, m.y - 54.0))
		var rect := Rect2(box_pos - Vector2(12, 6), tsize + Vector2(24, 14))
		_canvas.draw_rect(rect, Color(0.06, 0.06, 0.11, 0.92))
		_canvas.draw_rect(rect, Color(0.95, 0.86, 0.55, 0.9), false, 2.0)
		_canvas.draw_string(FONT, box_pos + Vector2(0, tsize.y - 4), _hover_tooltip, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0.98, 0.95, 0.85))


func _draw_backpack_closed(c: Vector2) -> void:
	var hover_glow := 1.0 if _bag_hovered else (0.55 + 0.35 * sin(_t * 3.5))
	var scale_pop := 1.03 if _bag_hovered else 1.0
	_canvas.draw_set_transform(c, 0.0, Vector2.ONE * scale_pop)

	# Bóng dưới đất
	_draw_ellipse(Vector2(0, 196), Vector2(185, 34), Color(0, 0, 0, 0.45))

	# Quai xách trên đỉnh
	_canvas.draw_arc(Vector2(0, -186), 38.0, PI, TAU, 16, Color(0.08, 0.08, 0.14), 22.0)
	_canvas.draw_arc(Vector2(0, -186), 38.0, PI, TAU, 16, Color(0.24, 0.25, 0.38), 12.0)

	# Viền sáng báo bấm được
	var glow_col := Color(1.0, 0.92, 0.58, 0.88 * hover_glow)
	_draw_rounded_box(Rect2(-176, -188, 352, 384), glow_col, 48.0)

	# Thân balo (tông xanh tím tối khớp bag.png)
	_draw_rounded_box(Rect2(-168, -180, 336, 368), Color(0.09, 0.09, 0.15), 44.0)
	_draw_rounded_box(Rect2(-158, -170, 316, 348), Color(0.20, 0.21, 0.33), 38.0)
	# Mảng sáng nhẹ góc trên trái
	_draw_rounded_box(Rect2(-142, -156, 284, 150), Color(0.25, 0.27, 0.41, 0.75), 32.0)

	# Đường khoá kéo vòng cung trên thân balo
	_canvas.draw_arc(Vector2(0, -28), 144.0, PI * 1.12, PI * 1.88, 28, Color(0.08, 0.08, 0.14), 10.0)
	_canvas.draw_arc(Vector2(0, -28), 144.0, PI * 1.12, PI * 1.88, 28, Color(0.68, 0.70, 0.80), 4.0)
	# Tay kéo khoá nổi bật
	var zip_pos := Vector2(92, -138) + Vector2(0, sin(_t * 4.0) * 3.0)
	_canvas.draw_rect(Rect2(zip_pos - Vector2(10, 8), Vector2(20, 34)), Color(0.08, 0.08, 0.14))
	_canvas.draw_rect(Rect2(zip_pos - Vector2(7, 5), Vector2(14, 28)), Color(0.95, 0.86, 0.55))

	# Ngăn túi nhỏ phía trước
	_draw_rounded_box(Rect2(-118, 28, 236, 128), Color(0.11, 0.11, 0.18), 20.0)
	_draw_rounded_box(Rect2(-110, 36, 220, 112), Color(0.16, 0.17, 0.28), 16.0)
	_canvas.draw_line(Vector2(-96, 62), Vector2(96, 62), Color(0.08, 0.08, 0.14), 6.0)
	_canvas.draw_rect(Rect2(-12, 56, 24, 14), Color(0.65, 0.67, 0.78))

	_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_backpack_open_back(c: Vector2) -> void:
	_canvas.draw_set_transform(c, 0.0, Vector2.ONE)
	_draw_ellipse(Vector2(0, 212), Vector2(215, 38), Color(0, 0, 0, 0.48))

	# Nắp balo mở ngửa ra phía sau
	var flap_y := lerpf(-130.0, -225.0, _open_anim)
	_draw_rounded_box(Rect2(-168, flap_y, 336, 150), Color(0.09, 0.09, 0.15), 36.0)
	_draw_rounded_box(Rect2(-158, flap_y + 10, 316, 130), Color(0.16, 0.17, 0.27), 30.0)

	# Thân ngoài balo mở rộng miệng
	_draw_rounded_box(Rect2(-194, -150, 388, 360), Color(0.09, 0.09, 0.15), 42.0)
	_draw_rounded_box(Rect2(-184, -140, 368, 340), Color(0.20, 0.21, 0.33), 36.0)

	# Khoang tối bên trong miệng balo
	_draw_rounded_box(Rect2(-156, -124, 312, 265), Color(0.06, 0.06, 0.10), 28.0)
	_draw_rounded_box(Rect2(-146, -114, 292, 245), Color(0.10, 0.10, 0.16), 24.0)
	_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_backpack_open_front(c: Vector2) -> void:
	_canvas.draw_set_transform(c, 0.0, Vector2.ONE)
	# Mép trước balo che phần đáy khoang để cảm giác đồ nằm lún sâu trong balo
	_draw_rounded_box(Rect2(-190, 96, 380, 114), Color(0.09, 0.09, 0.15), 24.0)
	_draw_rounded_box(Rect2(-180, 104, 360, 98), Color(0.18, 0.19, 0.31), 20.0)
	# Ngăn túi nhỏ phía trước
	_draw_rounded_box(Rect2(-120, 118, 240, 74), Color(0.11, 0.11, 0.18), 14.0)
	_draw_rounded_box(Rect2(-112, 124, 224, 62), Color(0.15, 0.16, 0.26), 12.0)
	_canvas.draw_line(Vector2(-96, 142), Vector2(96, 142), Color(0.08, 0.08, 0.14), 5.0)
	_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_item(it: Dictionary, shake_off: Vector2, is_dragging: bool) -> void:
	var pos: Vector2 = it.pos + shake_off
	var rot: float = 0.0 if is_dragging else float(it.rot)
	var sc: float = 1.07 if is_dragging else (1.03 if it.hover and it.unlocked else 1.0)
	var glow: bool = (it.hover and it.unlocked) or (it.id == &"phone" and it.unlocked and not it.removed)

	_canvas.draw_set_transform(pos, rot, Vector2.ONE * sc)
	var half: Vector2 = it.size * 0.5
	# Bóng đổ
	var shadow_off := Vector2(14, 18) if is_dragging else Vector2(6, 8)
	_canvas.draw_rect(Rect2(-half + shadow_off, it.size), Color(0, 0, 0, 0.40 if is_dragging else 0.32))

	match it.id:
		&"notebook":
			_draw_torn_notebook(half, glow)
		&"exam":
			_draw_zero_exam(half, glow)
		&"phone":
			_draw_phone(half, glow)

	_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 1. Cuốn tập bị xé + dòng chữ bắt nạt
func _draw_torn_notebook(half: Vector2, glow: bool) -> void:
	var sz := half * 2.0
	if glow:
		var pulse := 0.7 + 0.3 * sin(_t * 5.0)
		_canvas.draw_rect(Rect2(-half - Vector2(5, 5), sz + Vector2(10, 10)), Color(1.0, 0.90, 0.58, 0.78 * pulse))

	# Trang giấy trắng nhô ra ở góc bị xé nát
	var page_poly := PackedVector2Array([
		Vector2(-half.x + 8, -half.y + 6),
		Vector2(half.x - 4, -half.y + 8),
		Vector2(half.x - 14, -half.y + 52),
		Vector2(half.x - 2, -half.y + 92),
		Vector2(half.x - 18, -half.y + 130),
		Vector2(half.x - 6, half.y - 6),
		Vector2(-half.x + 8, half.y - 6),
	])
	_canvas.draw_colored_polygon(page_poly, Color(0.89, 0.86, 0.79))

	# Bìa vở cũ màu xanh xám bị xé mất góc trên phải
	var cover_poly := PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x - 74, -half.y),
		Vector2(half.x - 54, -half.y + 34),
		Vector2(half.x - 86, -half.y + 64),
		Vector2(half.x - 42, -half.y + 98),
		Vector2(half.x - 66, -half.y + 136),
		Vector2(half.x - 12, -half.y + 168),
		Vector2(half.x - 4, half.y),
		Vector2(-half.x, half.y),
	])
	_canvas.draw_colored_polygon(cover_poly, Color(0.28, 0.35, 0.45))
	var cover_outline := cover_poly.duplicate()
	cover_outline.append(cover_poly[0])
	_canvas.draw_polyline(cover_outline, Color(0.11, 0.12, 0.18), 4.0)

	# Gáy vở tối màu
	_canvas.draw_rect(Rect2(-half.x, -half.y, 24, sz.y), Color(0.16, 0.20, 0.28))

	# Nhãn vở ghi tên bị gạch phá
	var label_r := Rect2(-half.x + 38, -half.y + 28, 126, 56)
	_canvas.draw_rect(label_r, Color(0.93, 0.90, 0.83))
	_canvas.draw_rect(label_r, Color(0.22, 0.26, 0.35), false, 2.0)
	_canvas.draw_string(FONT, label_r.position + Vector2(12, 24), "Tập: Minh", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.18, 0.20, 0.28))
	# Vết gạch chéo tên bằng bút mực đỏ đen
	_canvas.draw_line(label_r.position + Vector2(6, 12), label_r.end - Vector2(8, 12), Color(0.76, 0.14, 0.16), 4.0)
	_canvas.draw_line(label_r.position + Vector2(10, 44), label_r.position + Vector2(118, 10), Color(0.76, 0.14, 0.16), 4.0)

	# Vết bẩn / nhàu trên bìa
	_draw_ellipse(Vector2(-32, 86), Vector2(36, 20), Color(0.16, 0.15, 0.18, 0.32))
	_draw_ellipse(Vector2(28, 104), Vector2(28, 16), Color(0.32, 0.24, 0.18, 0.28))

	# Dòng chữ bắt nạt nguệch ngoạc
	_canvas.draw_string(FONT, Vector2(-half.x + 32, -10), "ĐỒ YẾU ĐUỐI", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0.84, 0.16, 0.18))
	_canvas.draw_string(FONT, Vector2(-half.x + 48, 34), "CÚT ĐI!", HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color(0.12, 0.10, 0.14))
	_canvas.draw_string(FONT, Vector2(-half.x + 28, 76), "KHÔNG AI CHƠI", HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color(0.78, 0.14, 0.16))
	_canvas.draw_string(FONT, Vector2(-half.x + 56, 104), "VỚI MÀY ĐÂU", HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color(0.78, 0.14, 0.16))

	# Nét rạch xé trên bìa
	_canvas.draw_line(Vector2(-half.x + 36, 12), Vector2(half.x - 28, 52), Color(0.12, 0.10, 0.14, 0.7), 3.0)
	_canvas.draw_line(Vector2(-half.x + 42, -26), Vector2(half.x - 52, -4), Color(0.82, 0.16, 0.18, 0.65), 2.5)


## 2. Bài kiểm tra điểm thấp (0 điểm)
func _draw_zero_exam(half: Vector2, glow: bool) -> void:
	var sz := half * 2.0
	if glow:
		var pulse := 0.7 + 0.3 * sin(_t * 5.0)
		_canvas.draw_rect(Rect2(-half - Vector2(5, 5), sz + Vector2(10, 10)), Color(1.0, 0.90, 0.58, 0.78 * pulse))

	# Tờ giấy kiểm tra hơi nhàu
	_canvas.draw_rect(Rect2(-half, sz), Color(0.93, 0.91, 0.85))
	_canvas.draw_rect(Rect2(-half, sz), Color(0.16, 0.16, 0.22), false, 3.0)

	# Dòng kẻ ngang xanh nhạt & lề đỏ
	var line_y := -half.y + 62.0
	while line_y < half.y - 16.0:
		_canvas.draw_line(Vector2(-half.x + 12, line_y), Vector2(half.x - 12, line_y), Color(0.65, 0.76, 0.88, 0.65), 1.5)
		line_y += 22.0
	_canvas.draw_line(Vector2(-half.x + 42, -half.y + 42), Vector2(-half.x + 42, half.y - 10), Color(0.85, 0.42, 0.42, 0.6), 2.0)

	# Tiêu đề bài kiểm tra
	_canvas.draw_string(FONT, Vector2(-half.x + 18, -half.y + 34), "BÀI KIỂM TRA", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.18, 0.20, 0.28))

	# Ô điểm 0 đỏ chót góc trên phải
	var score_center := Vector2(half.x - 46, -half.y + 58)
	_canvas.draw_arc(score_center, 34.0, 0.0, TAU, 24, Color(0.84, 0.12, 0.14), 4.0)
	_canvas.draw_string(FONT, score_center + Vector2(-15, 20), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 66, Color(0.86, 0.10, 0.12))
	_canvas.draw_string(FONT, score_center + Vector2(-34, 48), "0 điểm", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.84, 0.12, 0.14))

	# Các dòng làm bài bỏ dở bị gạch đỏ X
	for row_i in 4:
		var ry := -half.y + 102.0 + row_i * 34.0
		_canvas.draw_line(Vector2(-half.x + 52, ry), Vector2(half.x - 56 - row_i * 12, ry), Color(0.32, 0.34, 0.44, 0.7), 2.5)
		# Dấu X đỏ
		var xc := Vector2(half.x - 36, ry - 4)
		_canvas.draw_line(xc + Vector2(-9, -9), xc + Vector2(9, 9), Color(0.84, 0.14, 0.16), 3.0)
		_canvas.draw_line(xc + Vector2(9, -9), xc + Vector2(-9, 9), Color(0.84, 0.14, 0.16), 3.0)

	# Lời phê đỏ phía dưới
	_canvas.draw_string(FONT, Vector2(-half.x + 22, half.y - 44), "Kém! Không tập trung", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color(0.82, 0.14, 0.16))
	_canvas.draw_string(FONT, Vector2(-half.x + 22, half.y - 18), "Mời phụ huynh!", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.82, 0.14, 0.16))

	# Nếp gấp nhàu chéo
	_canvas.draw_line(Vector2(-half.x + 10, -10), Vector2(half.x - 16, 48), Color(0.60, 0.58, 0.52, 0.42), 2.0)
	_canvas.draw_line(Vector2(-half.x + 68, -half.y + 8), Vector2(-half.x + 18, half.y - 8), Color(0.60, 0.58, 0.52, 0.35), 2.0)


## 3. Chiếc điện thoại của Minh
func _draw_phone(half: Vector2, glow: bool) -> void:
	var sz := half * 2.0
	if glow:
		var pulse := 0.65 + 0.35 * sin(_t * 5.0)
		_draw_rounded_box(Rect2(-half - Vector2(8, 8), sz + Vector2(16, 16)), Color(1.0, 0.93, 0.58, 0.90 * pulse), 22.0)

	# Vỏ máy tối màu
	_draw_rounded_box(Rect2(-half, sz), Color(0.09, 0.10, 0.16), 18.0)
	_draw_rounded_box(Rect2(-half + Vector2(4, 4), sz - Vector2(8, 8)), Color(0.22, 0.25, 0.34), 15.0)

	# Loa thoại phía trên
	_canvas.draw_rect(Rect2(-18, -half.y + 12, 36, 5), Color(0.10, 0.11, 0.18))

	# Màn hình xanh nhạt phát sáng nhẹ khi đã mở khoá
	var screen_r := Rect2(-half.x + 11, -half.y + 26, sz.x - 22, sz.y - 54)
	var unlocked: bool = _items[0].unlocked
	var screen_col := Color(0.20, 0.34, 0.50) if unlocked else Color(0.11, 0.14, 0.22)
	_canvas.draw_rect(screen_r, screen_col)

	if unlocked:
		# Ánh sáng nhẹ + giờ 06:45 trên màn hình khoá
		_canvas.draw_rect(Rect2(screen_r.position, Vector2(screen_r.size.x, 42)), Color(0.28, 0.45, 0.64, 0.55))
		_canvas.draw_string(FONT, screen_r.position + Vector2(18, 56), "06:45", HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color(0.92, 0.96, 1.0))
		# Vết xước nhỏ trên mặt kính
		_canvas.draw_line(screen_r.position + Vector2(16, 86), screen_r.position + Vector2(68, 128), Color(0.86, 0.94, 1.0, 0.55), 2.0)
		_canvas.draw_line(screen_r.position + Vector2(46, 110), screen_r.position + Vector2(82, 102), Color(0.86, 0.94, 1.0, 0.40), 1.5)

	# Nút home dưới
	_canvas.draw_arc(Vector2(0, half.y - 14), 8.0, 0.0, TAU, 16, Color(0.55, 0.60, 0.72), 2.0)


func _draw_rounded_box(r: Rect2, col: Color, radius: float) -> void:
	var rad := minf(radius, minf(r.size.x, r.size.y) * 0.5)
	_canvas.draw_rect(Rect2(r.position.x + rad, r.position.y, r.size.x - rad * 2.0, r.size.y), col)
	_canvas.draw_rect(Rect2(r.position.x, r.position.y + rad, r.size.x, r.size.y - rad * 2.0), col)
	_canvas.draw_circle(Vector2(r.position.x + rad, r.position.y + rad), rad, col)
	_canvas.draw_circle(Vector2(r.end.x - rad, r.position.y + rad), rad, col)
	_canvas.draw_circle(Vector2(r.position.x + rad, r.end.y - rad), rad, col)
	_canvas.draw_circle(Vector2(r.end.x - rad, r.end.y - rad), rad, col)


func _draw_ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	_canvas.draw_colored_polygon(pts, col)


func _draw_circle_soft(c: Vector2, radius: float, col: Color) -> void:
	_canvas.draw_circle(c, radius, col)


static func _panel_box(bg: Color, border: Color, bw: int, radius: int, pad_x: int, pad_y: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	s.anti_aliasing = false
	return s
