class_name TvCabinetSearch
extends CanvasLayer
## Cảnh tương tác Tủ Tivi trong phòng khách (Chương 1 — Nhiệm vụ sửa ống nước).
## Kết hợp Point & Click và Drag & Drop giống cảnh Balo / Tủ áo quần ở Chương 0:
##   1. Bấm vào cánh tủ tivi gỗ để mở tủ.
##   2. Kéo (Drag & Drop) sách báo cũ, hộp thiếc bánh quy, sổ ghi chép... ra ngoài tủ
##      để lộ ra 3 món đồ sửa ống nước cất phía sau:
##      - Vòng cao su (rubber_ring)
##      - Đầu nối ống (pipe_connector)
##      - Cái kẹp sắt (pipe_clamp)
##   3. Bấm hoặc kéo từng món để bỏ vào túi đồ. Đủ 3 món sẽ tự đóng cảnh.

signal all_tools_collected
signal closed(all_found: bool)

enum Stage { CLOSED, SEARCHING, ALL_FOUND }

const FONT := preload("res://assets/fonts/vt323_regular.ttf")
const SFX_CLICK := "res://assets/audio/sfx/typing/key_02.wav"
const SFX_RUSTLE := "res://assets/audio/sfx/fishing/cast.wav"
const SFX_DROP := "res://assets/audio/sfx/typing/key_01.wav"
const SFX_PICKUP := "res://assets/audio/sfx/fishing/catch.wav"

const TEX_CONNECTOR := "res://assets/items/pipe_connector.png"
const TEX_RUBBER := "res://assets/items/rubber_ring.png"
const TEX_CLAMP := "res://assets/items/pipe_clamp.png"

const CLICK_DRAG_THRESHOLD := 12.0

var _stage: Stage = Stage.CLOSED
var _player: Player = null
var _t: float = 0.0
var _open_anim: float = 0.0
var _closing: bool = false

## Các món trong tủ: index 0..2 là 3 món cần tìm (nằm dưới), index 3..6 là đồ cũ che lên trên.
## Mỗi phần tử: { id, name, is_tool, covered_by, size, pos, rest_pos, rot, removed, collected, hover, drop_slot }
var _items: Array[Dictionary] = []
var _dragging_idx: int = -1
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _door_hovered: bool = false
var _hover_tooltip: String = ""

var _tex_map: Dictionary = {}
var _canvas: Control
var _step_label: Label
var _thought_label: Label
var _close_btn: Button
var _sfx: AudioStreamPlayer


func open(player: Player) -> void:
	_player = player
	if _player:
		_player.lock(&"tv_cabinet_search")
	show()


func _ready() -> void:
	layer = 78
	_sfx = AudioStreamPlayer.new()
	_sfx.volume_db = -8.0
	add_child(_sfx)

	_tex_map[&"pipe_connector"] = _load_png(TEX_CONNECTOR)
	_tex_map[&"rubber_ring"] = _load_png(TEX_RUBBER)
	_tex_map[&"pipe_clamp"] = _load_png(TEX_CLAMP)

	_build_ui()
	_init_items()
	_update_step_hint()
	_set_thought("Cái tủ tivi cũ của ông nội... Ông bảo mấy đồ sửa ống nước cất trong ngăn dưới này.")


func _build_ui() -> void:
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.draw.connect(_on_draw_stage)
	add_child(_canvas)

	# Thanh hướng dẫn phía trên
	var top_panel := PanelContainer.new()
	top_panel.add_theme_stylebox_override(&"panel", _panel_box(Color(0.07, 0.06, 0.09, 0.92), Color(0.92, 0.82, 0.62, 0.88), 3, 10, 22, 10))
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
	_close_btn.add_theme_color_override(&"font_color", Color(0.90, 0.88, 0.94))
	_close_btn.add_theme_color_override(&"font_hover_color", Color(1.0, 0.95, 0.72))
	_close_btn.add_theme_stylebox_override(&"normal", _panel_box(Color(0.09, 0.08, 0.13, 0.92), Color(0.58, 0.54, 0.66), 3, 8, 18, 6))
	_close_btn.add_theme_stylebox_override(&"hover", _panel_box(Color(0.16, 0.14, 0.20, 0.96), Color(0.96, 0.84, 0.48), 3, 8, 18, 6))
	_close_btn.add_theme_stylebox_override(&"pressed", _panel_box(Color(0.12, 0.11, 0.17, 0.96), Color(1.0, 0.92, 0.62), 3, 8, 18, 6))
	_close_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_close_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_close_btn.offset_left = -240
	_close_btn.offset_right = -32
	_close_btn.offset_top = 28
	_close_btn.offset_bottom = 86
	_close_btn.pressed.connect(_close_self)
	_canvas.add_child(_close_btn)

	# Khung tự sự của Minh phía dưới (nở lên trên để không bị cắt mép dưới)
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


func _cabinet_rect() -> Rect2:
	return Rect2(Vector2(540.0, 290.0), Vector2(840.0, 440.0))


func _inner_rect() -> Rect2:
	return Rect2(Vector2(574.0, 326.0), Vector2(772.0, 368.0))


func _has_tool_already(item_id: String) -> bool:
	return GameState.has_item(item_id) or GameState.has_flag("pipe_delivered." + item_id)


func _init_items() -> void:
	var c: Vector2 = _inner_rect().get_center()
	var got_rubber: bool = _has_tool_already("rubber_ring")
	var got_conn: bool = _has_tool_already("pipe_connector")
	var got_clamp: bool = _has_tool_already("pipe_clamp")

	_items = [
		# --- 3 món đồ sửa ống nước (nằm phía dưới đồ cũ) ---
		{
			"id": &"rubber_ring",
			"name": "Vòng cao su",
			"is_tool": true,
			"covered_by": &"newspaper",
			"size": Vector2(124.0, 124.0),
			"pos": c + Vector2(-235.0, 22.0),
			"rest_pos": c + Vector2(-235.0, 22.0),
			"rot": -0.08,
			"removed": got_rubber,
			"collected": got_rubber,
			"hover": false,
			"drop_slot": Vector2.ZERO,
		},
		{
			"id": &"pipe_connector",
			"name": "Đầu nối ống",
			"is_tool": true,
			"covered_by": &"biscuit_tin",
			"size": Vector2(128.0, 128.0),
			"pos": c + Vector2(6.0, 26.0),
			"rest_pos": c + Vector2(6.0, 26.0),
			"rot": 0.05,
			"removed": got_conn,
			"collected": got_conn,
			"hover": false,
			"drop_slot": Vector2.ZERO,
		},
		{
			"id": &"pipe_clamp",
			"name": "Cái kẹp sắt",
			"is_tool": true,
			"covered_by": &"notebook_rag",
			"size": Vector2(128.0, 128.0),
			"pos": c + Vector2(238.0, 18.0),
			"rest_pos": c + Vector2(238.0, 18.0),
			"rot": -0.06,
			"removed": got_clamp,
			"collected": got_clamp,
			"hover": false,
			"drop_slot": Vector2.ZERO,
		},
		# --- Đồ cũ trong tủ che lên 3 món trên (kéo ra ngoài tủ để dọn chỗ) ---
		{
			"id": &"newspaper",
			"name": "Xấp báo cũ",
			"is_tool": false,
			"covered_by": &"",
			"size": Vector2(226.0, 184.0),
			"pos": Vector2(280.0, 430.0) if got_rubber else (c + Vector2(-232.0, 14.0)),
			"rest_pos": c + Vector2(-232.0, 14.0),
			"rot": -0.05,
			"removed": got_rubber,
			"collected": false,
			"hover": false,
			"drop_slot": Vector2(270.0, 420.0),
		},
		{
			"id": &"biscuit_tin",
			"name": "Hộp thiếc bánh quy cũ",
			"is_tool": false,
			"covered_by": &"",
			"size": Vector2(214.0, 186.0),
			"pos": Vector2(290.0, 640.0) if got_conn else (c + Vector2(8.0, 20.0)),
			"rest_pos": c + Vector2(8.0, 20.0),
			"rot": 0.03,
			"removed": got_conn,
			"collected": false,
			"hover": false,
			"drop_slot": Vector2(280.0, 650.0),
		},
		{
			"id": &"notebook_rag",
			"name": "Sổ ghi chép & giẻ lau",
			"is_tool": false,
			"covered_by": &"",
			"size": Vector2(216.0, 182.0),
			"pos": Vector2(1635.0, 445.0) if got_clamp else (c + Vector2(236.0, 14.0)),
			"rest_pos": c + Vector2(236.0, 14.0),
			"rot": 0.07,
			"removed": got_clamp,
			"collected": false,
			"hover": false,
			"drop_slot": Vector2(1635.0, 450.0),
		},
		{
			"id": &"tv_remote",
			"name": "Điều khiển tivi cũ",
			"is_tool": false,
			"covered_by": &"",
			"size": Vector2(150.0, 64.0),
			"pos": c + Vector2(-100.0, -104.0),
			"rest_pos": c + Vector2(-100.0, -104.0),
			"rot": -0.10,
			"removed": false,
			"collected": false,
			"hover": false,
			"drop_slot": Vector2(1635.0, 645.0),
		},
	]


func _count_tools_found() -> int:
	var n: int = 0
	for it: Dictionary in _items:
		if bool(it["is_tool"]) and bool(it["collected"]):
			n += 1
	return n


func _is_item_unlocked(it: Dictionary) -> bool:
	var cover_id: StringName = it["covered_by"]
	if cover_id == &"":
		return true
	for other: Dictionary in _items:
		if other["id"] == cover_id:
			return bool(other["removed"])
	return true


func _process(delta: float) -> void:
	_t += delta
	if _stage != Stage.CLOSED and _open_anim < 1.0:
		_open_anim = minf(1.0, _open_anim + delta * 3.8)

	# Kéo trả đồ về vị trí gọn khi thả chuột
	for i: int in range(_items.size()):
		if i == _dragging_idx:
			continue
		var it: Dictionary = _items[i]
		if bool(it["collected"]):
			continue
		var cur_pos: Vector2 = it["pos"]
		var target_pos: Vector2 = it["drop_slot"] if bool(it["removed"]) else it["rest_pos"]
		if cur_pos.distance_to(target_pos) > 0.5:
			it["pos"] = cur_pos.lerp(target_pos, clampf(delta * 12.0, 0.0, 1.0))

	if is_instance_valid(_canvas):
		_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if _closing:
		return

	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo and ke.physical_keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_close_self()
		return

	if event is InputEventMouseMotion:
		var mpos: Vector2 = (event as InputEventMouseMotion).position
		_handle_mouse_move(mpos)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if is_instance_valid(_close_btn) and _close_btn.get_global_rect().has_point(mb.position) and _dragging_idx < 0:
				return
			if mb.pressed:
				_handle_mouse_down(mb.position)
			else:
				_handle_mouse_up(mb.position)
			get_viewport().set_input_as_handled()


func _handle_mouse_move(mpos: Vector2) -> void:
	if _dragging_idx >= 0:
		var it: Dictionary = _items[_dragging_idx]
		it["pos"] = mpos + _drag_offset
		_hover_tooltip = String(it["name"])
		return

	_hover_tooltip = ""
	_door_hovered = false
	for it: Dictionary in _items:
		it["hover"] = false

	if _stage == Stage.CLOSED:
		_door_hovered = _cabinet_rect().has_point(mpos)
		if _door_hovered:
			_hover_tooltip = "Bấm để mở tủ tivi"
		return

	if _stage == Stage.SEARCHING:
		var idx: int = _pick_top_item(mpos)
		if idx >= 0:
			var it: Dictionary = _items[idx]
			it["hover"] = true
			if bool(it["is_tool"]):
				_hover_tooltip = "Bấm để lấy: %s" % String(it["name"])
			elif not bool(it["removed"]):
				_hover_tooltip = "Kéo ra ngoài: %s" % String(it["name"])
			else:
				_hover_tooltip = String(it["name"])


func _handle_mouse_down(mpos: Vector2) -> void:
	# Không chặn nút Đóng ở góc trên phải
	if is_instance_valid(_close_btn) and _close_btn.get_global_rect().has_point(mpos):
		return

	if _stage == Stage.CLOSED:
		if _cabinet_rect().has_point(mpos):
			_stage = Stage.SEARCHING
			_play_sfx(SFX_CLICK, 0.92)
			_update_step_hint()
			_set_thought("Bên trong xếp đầy báo cũ với hộp đồ của ông... Kéo mấy thứ này ra ngoài để tìm thử xem.")
		return

	if _stage != Stage.SEARCHING:
		return

	var idx: int = _pick_top_item(mpos)
	if idx < 0:
		return

	var it: Dictionary = _items[idx]
	if bool(it["is_tool"]):
		_collect_tool(idx)
		return

	if bool(it["removed"]):
		return

	_dragging_idx = idx
	var item_pos: Vector2 = it["pos"]
	_drag_offset = item_pos - mpos
	_drag_start_mouse = mpos
	_play_sfx(SFX_RUSTLE, 1.05)


func _handle_mouse_up(mpos: Vector2) -> void:
	if _dragging_idx < 0:
		return

	var idx: int = _dragging_idx
	_dragging_idx = -1
	var it: Dictionary = _items[idx]
	var item_pos: Vector2 = it["pos"]
	var moved_dist: float = mpos.distance_to(_drag_start_mouse)

	# Nếu người chơi kéo đồ cũ ra ngoài khung tủ (hoặc bấm nhanh để đẩy gọn sang bên)
	var cab := _cabinet_rect()
	var outside_cab: bool = not cab.grow(-24.0).has_point(item_pos)
	if outside_cab:
		it["removed"] = true
		# Đặt tạm phía bên gần hướng người chơi vừa kéo ra
		var side_x: float = 265.0 if item_pos.x < 960.0 else 1645.0
		var clamped_y: float = clampf(item_pos.y, 320.0, 740.0)
		it["drop_slot"] = Vector2(side_x, clamped_y)
		_play_sfx(SFX_DROP, 0.95)
		_on_clutter_removed(it["id"])
		_update_step_hint()
	elif moved_dist < CLICK_DRAG_THRESHOLD:
		_set_thought("Giữ chuột kéo %s ra ngoài khung tủ để dọn chỗ xem phía sau." % String(it["name"]).to_lower())
		_play_sfx(SFX_CLICK, 0.85)
	else:
		_play_sfx(SFX_DROP, 0.8)


func _on_clutter_removed(clutter_id: StringName) -> void:
	match clutter_id:
		&"newspaper":
			_set_thought("Xấp báo Nông Nghiệp cũ ông giữ cẩn thận ghê... A! Có cái vòng cao su nằm ngay phía dưới!")
		&"biscuit_tin":
			_set_thought("Hộp thiếc bánh quy của ông... mở ra chắc toàn kim chỉ, mà phía dưới có cái đầu nối ống kìa!")
		&"notebook_rag":
			_set_thought("Cuốn sổ ghi lịch tưới rau với giẻ lau cũ... Kìa, cái kẹp sắt nằm ngay phía sau!")
		&"tv_remote":
			_set_thought("Cái điều khiển tivi cũ dán băng keo ở nắp pin... không phải đồ sửa ống rồi.")


func _collect_tool(idx: int) -> void:
	var it: Dictionary = _items[idx]
	if bool(it["collected"]):
		return

	it["collected"] = true
	it["removed"] = true
	var item_key: String = String(it["id"])
	if not _has_tool_already(item_key):
		GameState.add_item(item_key, 1, true)
	_play_sfx(SFX_PICKUP, 1.08)

	match it["id"]:
		&"rubber_ring":
			_set_thought("Tìm thấy vòng cao su rồi! Có nó thì khớp nối mới kín nước được.")
		&"pipe_connector":
			_set_thought("Đúng cái đầu nối ống nước rồi!")
		&"pipe_clamp":
			_set_thought("Lấy được cả cái kẹp sắt nữa rồi!")

	_update_step_hint()

	if _count_tools_found() >= 3:
		_stage = Stage.ALL_FOUND
		GameState.set_flag("ch1.got_all_pipe_tools", true)
		_update_step_hint()
		_set_thought("Đủ cả 3 món rồi: đầu nối ống, vòng cao su với cái kẹp sắt! Ra vườn sửa cái vòi nước thôi.")
		all_tools_collected.emit()
		_auto_close_after_found()


func _auto_close_after_found() -> void:
	await get_tree().create_timer(1.35).timeout
	if is_inside_tree() and not _closing:
		_close_self()


func _pick_top_item(mpos: Vector2) -> int:
	# Duyệt ngược từ lớp trên cùng xuống dưới cùng
	for i: int in range(_items.size() - 1, -1, -1):
		var it: Dictionary = _items[i]
		if bool(it["collected"]):
			continue
		if bool(it["is_tool"]) and not _is_item_unlocked(it):
			continue
		var pos: Vector2 = it["pos"]
		var sz: Vector2 = it["size"]
		var rect := Rect2(pos - sz * 0.5, sz)
		if rect.has_point(mpos):
			return i
	return -1


func _update_step_hint() -> void:
	if _step_label == null:
		return
	var found: int = _count_tools_found()
	match _stage:
		Stage.CLOSED:
			_step_label.text = "Bấm vào cánh tủ tivi để mở tủ"
		Stage.SEARCHING:
			_step_label.text = "Kéo đồ cũ ra ngoài để tìm 3 món sửa ống nước  (%d/3)" % found
		Stage.ALL_FOUND:
			_step_label.text = "Đã tìm đủ cả 3 món sửa ống nước!  (3/3)"


func _set_thought(txt: String) -> void:
	if _thought_label:
		_thought_label.text = txt


func _close_self() -> void:
	if _closing:
		return
	_closing = true
	var done: bool = _count_tools_found() >= 3
	if _player:
		_player.unlock(&"tv_cabinet_search")
	closed.emit(done)
	queue_free()


# --- Vẽ khung cảnh Tủ Tivi & các món đồ (pixel-art sạch, ấm áp) --------------

func _on_draw_stage() -> void:
	var vp: Vector2 = _canvas.size
	# Nền tối ấm trong phòng khách
	_canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.05, 0.04, 0.06, 0.86))

	var cab: Rect2 = _cabinet_rect()
	var inner: Rect2 = _inner_rect()

	# 1. Phần chân chiếc tivi cũ + khăn ren đặt phía trên mặt tủ (gợi đúng chiếc tủ tivi trong phòng khách)
	_draw_retro_tv_top(cab)

	# 2. Thân tủ gỗ nâu trầm
	var wood_out := Color(0.11, 0.07, 0.05)
	var wood_dk := Color(0.22, 0.14, 0.10)
	var wood_mid := Color(0.32, 0.21, 0.14)
	var wood_hi := Color(0.45, 0.30, 0.20)
	var shelf_bg := Color(0.12, 0.08, 0.06)

	# Đổ bóng tủ
	_canvas.draw_rect(Rect2(cab.position + Vector2(14.0, 18.0), cab.size), Color(0.0, 0.0, 0.0, 0.45))
	# Chân tủ gỗ chéo kiểu vintage
	_canvas.draw_rect(Rect2(Vector2(cab.position.x + 36.0, cab.end.y - 4.0), Vector2(30.0, 42.0)), wood_out)
	_canvas.draw_rect(Rect2(Vector2(cab.position.x + 41.0, cab.end.y - 4.0), Vector2(20.0, 36.0)), wood_dk)
	_canvas.draw_rect(Rect2(Vector2(cab.end.x - 66.0, cab.end.y - 4.0), Vector2(30.0, 42.0)), wood_out)
	_canvas.draw_rect(Rect2(Vector2(cab.end.x - 61.0, cab.end.y - 4.0), Vector2(20.0, 36.0)), wood_dk)

	# Khung ngoài tủ
	_canvas.draw_rect(cab.grow(6.0), wood_out)
	_canvas.draw_rect(cab, wood_mid)
	_canvas.draw_rect(Rect2(cab.position, Vector2(cab.size.x, 12.0)), wood_hi)
	_canvas.draw_rect(Rect2(Vector2(cab.position.x, cab.end.y - 12.0), Vector2(cab.size.x, 12.0)), wood_dk)

	# 3. Khoang bên trong tủ
	_canvas.draw_rect(inner.grow(4.0), wood_out)
	_canvas.draw_rect(inner, shelf_bg)
	# Ván gỗ hậu tủ + bóng chiều sâu phía trên
	_canvas.draw_rect(Rect2(inner.position, Vector2(inner.size.x, 26.0)), Color(0.07, 0.04, 0.03, 0.85))
	for row_y: int in range(int(inner.position.y) + 56, int(inner.end.y), 62):
		_canvas.draw_rect(Rect2(Vector2(inner.position.x, float(row_y)), Vector2(inner.size.x, 3.0)), Color(0.17, 0.11, 0.08, 0.55))
	# Hai vách ngăn nhỏ chia 3 ô trong tủ
	var div1_x: float = inner.position.x + inner.size.x * 0.333
	var div2_x: float = inner.position.x + inner.size.x * 0.666
	_canvas.draw_rect(Rect2(Vector2(div1_x - 6.0, inner.position.y), Vector2(12.0, inner.size.y)), wood_dk)
	_canvas.draw_rect(Rect2(Vector2(div1_x - 2.0, inner.position.y), Vector2(4.0, inner.size.y)), wood_mid)
	_canvas.draw_rect(Rect2(Vector2(div2_x - 6.0, inner.position.y), Vector2(12.0, inner.size.y)), wood_dk)
	_canvas.draw_rect(Rect2(Vector2(div2_x - 2.0, inner.position.y), Vector2(4.0, inner.size.y)), wood_mid)

	# 4. Nếu tủ đã mở → vẽ các món đồ bên trong & đồ đã kéo ra ngoài
	if _stage != Stage.CLOSED:
		for i: int in range(_items.size()):
			if i == _dragging_idx:
				continue
			_draw_item(_items[i])

	# 5. Hai cánh cửa gỗ tủ (đóng kín lúc CLOSED, mở xoay sang 2 bên khi mở)
	_draw_cabinet_doors(inner, wood_out, wood_dk, wood_mid, wood_hi)

	# 6. Vẽ món đang được kéo lên trên cùng
	if _dragging_idx >= 0 and _dragging_idx < _items.size():
		_draw_item(_items[_dragging_idx], true)

	# 7. Thanh trạng thái nhỏ hiển thị 3 món sửa ống nước ở góc dưới tủ
	_draw_tool_checklist(cab)

	# 8. Tooltip gọn cạnh con trỏ chuột
	if not _hover_tooltip.is_empty():
		var mpos: Vector2 = _canvas.get_local_mouse_position()
		var tsize: Vector2 = FONT.get_string_size(_hover_tooltip, HORIZONTAL_ALIGNMENT_LEFT, -1, 32)
		var box_pos: Vector2 = mpos + Vector2(18.0, -44.0)
		box_pos.x = clampf(box_pos.x, 20.0, vp.x - tsize.x - 44.0)
		box_pos.y = clampf(box_pos.y, 100.0, vp.y - 200.0)
		var trect := Rect2(box_pos, Vector2(tsize.x + 26.0, 40.0))
		_canvas.draw_rect(trect.grow(2.0), Color(0.95, 0.85, 0.56, 0.92))
		_canvas.draw_rect(trect, Color(0.06, 0.06, 0.11, 0.94))
		_canvas.draw_string(FONT, box_pos + Vector2(13.0, 30.0), _hover_tooltip, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(1.0, 0.96, 0.82))


func _draw_retro_tv_top(cab: Rect2) -> void:
	# Khăn ren nhỏ phủ mặt tủ
	var cloth_rect := Rect2(Vector2(cab.position.x + 120.0, cab.position.y - 8.0), Vector2(600.0, 14.0))
	_canvas.draw_rect(cloth_rect, Color(0.86, 0.82, 0.72))
	# Phần đáy tivi cổ ở giữa
	var tv_rect := Rect2(Vector2(cab.get_center().x - 165.0, cab.position.y - 98.0), Vector2(330.0, 92.0))
	_canvas.draw_rect(tv_rect.grow(5.0), Color(0.11, 0.08, 0.07))
	_canvas.draw_rect(tv_rect, Color(0.28, 0.23, 0.19))
	_canvas.draw_rect(Rect2(tv_rect.position + Vector2(16.0, 12.0), Vector2(220.0, 66.0)), Color(0.18, 0.21, 0.23))
	_canvas.draw_rect(Rect2(tv_rect.position + Vector2(22.0, 18.0), Vector2(208.0, 54.0)), Color(0.32, 0.36, 0.38))
	# Núm xoay tivi cổ bên phải
	_canvas.draw_circle(tv_rect.position + Vector2(280.0, 32.0), 14.0, Color(0.14, 0.12, 0.11))
	_canvas.draw_circle(tv_rect.position + Vector2(280.0, 32.0), 9.0, Color(0.62, 0.58, 0.50))
	_canvas.draw_circle(tv_rect.position + Vector2(280.0, 66.0), 11.0, Color(0.14, 0.12, 0.11))
	_canvas.draw_circle(tv_rect.position + Vector2(280.0, 66.0), 6.0, Color(0.55, 0.52, 0.46))


func _draw_cabinet_doors(inner: Rect2, wood_out: Color, wood_dk: Color, wood_mid: Color, wood_hi: Color) -> void:
	var half_w: float = inner.size.x * 0.5
	var closed_factor: float = 1.0 - _open_anim
	if closed_factor <= 0.02:
		# Vẽ mép 2 cánh cửa đã mở gập sang 2 bên
		_canvas.draw_rect(Rect2(Vector2(inner.position.x - 24.0, inner.position.y), Vector2(20.0, inner.size.y)), wood_out)
		_canvas.draw_rect(Rect2(Vector2(inner.position.x - 20.0, inner.position.y + 4.0), Vector2(12.0, inner.size.y - 8.0)), wood_hi)
		_canvas.draw_rect(Rect2(Vector2(inner.end.x + 4.0, inner.position.y), Vector2(20.0, inner.size.y)), wood_out)
		_canvas.draw_rect(Rect2(Vector2(inner.end.x + 8.0, inner.position.y + 4.0), Vector2(12.0, inner.size.y - 8.0)), wood_hi)
		return

	var dw: float = maxf(18.0, half_w * closed_factor)
	var left_door := Rect2(inner.position, Vector2(dw - 2.0, inner.size.y))
	var right_door := Rect2(Vector2(inner.end.x - dw + 2.0, inner.position.y), Vector2(dw - 2.0, inner.size.y))

	for drect: Rect2 in [left_door, right_door]:
		_canvas.draw_rect(drect, wood_mid)
		_canvas.draw_rect(Rect2(drect.position, Vector2(drect.size.x, 8.0)), wood_hi)
		_canvas.draw_rect(Rect2(Vector2(drect.position.x, drect.end.y - 8.0), Vector2(drect.size.x, 8.0)), wood_dk)
		if drect.size.x > 46.0:
			var inset := drect.grow(-22.0)
			_canvas.draw_rect(inset, wood_dk)
			_canvas.draw_rect(inset.grow(-5.0), wood_mid)
		_canvas.draw_rect(drect, wood_out, false, 4.0)

	# Hai tay nắm đồng sáng bóng ở giữa
	if closed_factor > 0.35:
		var knob_y: float = inner.get_center().y
		var brass := Color(0.92, 0.76, 0.34)
		var brass_dk := Color(0.55, 0.40, 0.14)
		var lx: float = left_door.end.x - 26.0
		var rx: float = right_door.position.x + 26.0
		_canvas.draw_circle(Vector2(lx, knob_y), 11.0, brass_dk)
		_canvas.draw_circle(Vector2(lx - 1.0, knob_y - 1.0), 8.0, brass)
		_canvas.draw_circle(Vector2(rx, knob_y), 11.0, brass_dk)
		_canvas.draw_circle(Vector2(rx - 1.0, knob_y - 1.0), 8.0, brass)

	# Viền sáng ấm khi di chuột vào tủ lúc đang đóng
	if _stage == Stage.CLOSED:
		var glow_a: float = 0.85 if _door_hovered else (0.28 + 0.18 * sin(_t * 4.0))
		_canvas.draw_rect(inner.grow(2.0), Color(1.0, 0.90, 0.54, glow_a), false, 4.0)


func _draw_tool_checklist(cab: Rect2) -> void:
	var labels := [
		["rubber_ring", "Vòng cao su"],
		["pipe_connector", "Đầu nối ống"],
		["pipe_clamp", "Cái kẹp sắt"],
	]
	var y: float = cab.end.y + 52.0
	var start_x: float = cab.get_center().x - 360.0
	for i: int in range(labels.size()):
		var key: String = labels[i][0]
		var title: String = labels[i][1]
		var found: bool = false
		for it: Dictionary in _items:
			if String(it["id"]) == key and bool(it["collected"]):
				found = true
				break
		var box_pos := Vector2(start_x + float(i) * 250.0, y)
		var box_rect := Rect2(box_pos, Vector2(226.0, 44.0))
		var border_col := Color(0.54, 0.88, 0.52, 0.95) if found else Color(0.56, 0.54, 0.66, 0.8)
		_canvas.draw_rect(box_rect.grow(2.0), border_col)
		_canvas.draw_rect(box_rect, Color(0.08, 0.08, 0.13, 0.90))
		var txt: String = ("[v] " if found else "[ ] ") + title
		var tcol := Color(0.64, 0.94, 0.58) if found else Color(0.86, 0.85, 0.90)
		_canvas.draw_string(FONT, box_pos + Vector2(14.0, 32.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, tcol)


func _draw_item(it: Dictionary, is_dragged: bool = false) -> void:
	if bool(it["collected"]):
		return

	var pos: Vector2 = it["pos"]
	var sz: Vector2 = it["size"]
	var is_tool: bool = bool(it["is_tool"])
	var hovered: bool = bool(it["hover"])
	var unlocked: bool = _is_item_unlocked(it)
	var id: StringName = it["id"]

	if is_tool:
		# Vẽ ánh sáng vàng dịu khi đồ sửa đã được lộ ra để người chơi dễ nhận biết
		if unlocked:
			var pulse: float = 0.25 + 0.15 * sin(_t * 5.0)
			if hovered:
				pulse = 0.55
			_canvas.draw_circle(pos, 58.0, Color(1.0, 0.88, 0.45, pulse))
			_canvas.draw_circle(pos, 42.0, Color(1.0, 0.95, 0.72, pulse * 0.85))
		var tex: Texture2D = _tex_map.get(id, null)
		if tex:
			var scale_px: float = 96.0 if not hovered else 106.0
			var trect := Rect2(pos - Vector2(scale_px, scale_px) * 0.5, Vector2(scale_px, scale_px))
			_canvas.draw_texture_rect(tex, trect, false)
		return

	# Vẽ bóng đổ khi đang kéo đồ cũ
	var draw_pos: Vector2 = pos
	var r := Rect2(draw_pos - sz * 0.5, sz)
	if is_dragged:
		_canvas.draw_rect(Rect2(r.position + Vector2(12.0, 16.0), r.size), Color(0.0, 0.0, 0.0, 0.45))

	match id:
		&"newspaper":
			_draw_newspaper(r, hovered or is_dragged)
		&"biscuit_tin":
			_draw_biscuit_tin(r, hovered or is_dragged)
		&"notebook_rag":
			_draw_notebook_rag(r, hovered or is_dragged)
		&"tv_remote":
			_draw_tv_remote(r, hovered or is_dragged)


func _draw_newspaper(r: Rect2, hi: bool) -> void:
	var out_col := Color(1.0, 0.92, 0.58) if hi else Color(0.18, 0.14, 0.10)
	# Tờ báo dưới hơi lệch tạo cảm giác cả xấp báo
	_canvas.draw_rect(Rect2(r.position + Vector2(8.0, 10.0), r.size - Vector2(8.0, 8.0)), Color(0.68, 0.63, 0.50))
	_canvas.draw_rect(r.grow(3.0), out_col)
	_canvas.draw_rect(r, Color(0.88, 0.84, 0.72))
	# Tiêu đề báo đỏ vintage
	_canvas.draw_rect(Rect2(r.position + Vector2(12.0, 12.0), Vector2(r.size.x - 24.0, 28.0)), Color(0.68, 0.22, 0.18))
	_canvas.draw_string(FONT, r.position + Vector2(22.0, 34.0), "BÁO NÔNG NGHIỆP", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.98, 0.94, 0.84))
	# Ảnh minh họa xám + cột chữ báo
	_canvas.draw_rect(Rect2(r.position + Vector2(14.0, 52.0), Vector2(84.0, 68.0)), Color(0.55, 0.53, 0.46))
	_canvas.draw_rect(Rect2(r.position + Vector2(22.0, 62.0), Vector2(68.0, 48.0)), Color(0.42, 0.48, 0.38))
	for row: int in range(6):
		var ly: float = r.position.y + 56.0 + float(row) * 14.0
		_canvas.draw_rect(Rect2(Vector2(r.position.x + 110.0, ly), Vector2(r.size.x - 126.0, 6.0)), Color(0.36, 0.34, 0.29))
	for row2: int in range(2):
		var ly2: float = r.position.y + 134.0 + float(row2) * 16.0
		_canvas.draw_rect(Rect2(Vector2(r.position.x + 14.0, ly2), Vector2(r.size.x - 28.0, 6.0)), Color(0.38, 0.36, 0.30))


func _draw_biscuit_tin(r: Rect2, hi: bool) -> void:
	# Hộp thiếc bánh quy xanh dương - viền vàng kiểu hộp bánh ông bà hay cất đồ!
	var c: Vector2 = r.get_center()
	var rad: float = minf(r.size.x, r.size.y) * 0.48
	var out_col := Color(1.0, 0.92, 0.58) if hi else Color(0.10, 0.14, 0.24)
	_canvas.draw_circle(c, rad + 4.0, out_col)
	_canvas.draw_circle(c, rad, Color(0.15, 0.30, 0.58))
	_canvas.draw_circle(c, rad - 10.0, Color(0.84, 0.68, 0.28))
	_canvas.draw_circle(c, rad - 16.0, Color(0.18, 0.36, 0.68))
	# Họa tiết bánh quy ở giữa nắp hộp
	_canvas.draw_circle(c + Vector2(-18.0, -10.0), 16.0, Color(0.86, 0.68, 0.36))
	_canvas.draw_circle(c + Vector2(18.0, 6.0), 18.0, Color(0.82, 0.62, 0.30))
	_canvas.draw_circle(c + Vector2(-8.0, 20.0), 14.0, Color(0.90, 0.74, 0.42))
	_canvas.draw_string(FONT, c + Vector2(-50.0, -34.0), "BÁNH QUY", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.98, 0.90, 0.62))


func _draw_notebook_rag(r: Rect2, hi: bool) -> void:
	var out_col := Color(1.0, 0.92, 0.58) if hi else Color(0.18, 0.12, 0.08)
	# Miếng giẻ lau sọc xanh nhạt gập bên dưới
	var rag := Rect2(r.position + Vector2(28.0, 20.0), Vector2(r.size.x - 24.0, r.size.y - 24.0))
	_canvas.draw_rect(rag.grow(3.0), out_col)
	_canvas.draw_rect(rag, Color(0.76, 0.80, 0.82))
	for sx: int in range(int(rag.position.x) + 14, int(rag.end.x), 24):
		_canvas.draw_rect(Rect2(Vector2(float(sx), rag.position.y), Vector2(8.0, rag.size.y)), Color(0.56, 0.66, 0.74))
	# Cuốn sổ tay bìa nâu đặt chéo lên trên
	var book := Rect2(r.position, Vector2(r.size.x - 42.0, r.size.y - 16.0))
	_canvas.draw_rect(book.grow(3.0), out_col)
	_canvas.draw_rect(book, Color(0.46, 0.28, 0.16))
	_canvas.draw_rect(Rect2(book.position, Vector2(20.0, book.size.y)), Color(0.30, 0.18, 0.10))
	_canvas.draw_rect(Rect2(book.position + Vector2(36.0, 26.0), Vector2(book.size.x - 52.0, 44.0)), Color(0.92, 0.88, 0.76))
	_canvas.draw_string(FONT, book.position + Vector2(46.0, 56.0), "SỔ VƯỜN", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.26, 0.18, 0.12))


func _draw_tv_remote(r: Rect2, hi: bool) -> void:
	var out_col := Color(1.0, 0.92, 0.58) if hi else Color(0.10, 0.10, 0.14)
	_canvas.draw_rect(r.grow(3.0), out_col)
	_canvas.draw_rect(r, Color(0.22, 0.23, 0.27))
	# Nút nguồn đỏ + các phím bấm nhỏ
	_canvas.draw_rect(Rect2(r.position + Vector2(12.0, 14.0), Vector2(16.0, 14.0)), Color(0.84, 0.22, 0.18))
	for col_i: int in range(5):
		for row_i: int in range(2):
			var bx: float = r.position.x + 40.0 + float(col_i) * 20.0
			var by: float = r.position.y + 14.0 + float(row_i) * 20.0
			_canvas.draw_rect(Rect2(Vector2(bx, by), Vector2(13.0, 12.0)), Color(0.62, 0.64, 0.68))


# --- Helpers -----------------------------------------------------------------

func _panel_box(bg: Color, border: Color, bw: int, rad: int, pad_x: int, pad_y: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(rad)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	sb.anti_aliasing = false
	return sb


func _play_sfx(path: String, pitch: float = 1.0) -> void:
	if _sfx == null or not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path) as AudioStream
	if stream:
		_sfx.stream = stream
		_sfx.pitch_scale = pitch
		_sfx.play()


func _load_png(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		var res: Resource = load(res_path)
		if res is Texture2D:
			return res
	var abs_path := ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img:
			return ImageTexture.create_from_image(img)
	return null
