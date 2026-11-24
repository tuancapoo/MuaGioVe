class_name WardrobeSearch
extends CanvasLayer
## Cảnh tương tác Tủ áo quần (Chương 0 — Phòng Minh ở thành phố).
## Vẽ áo quần theo phong cách pixel art khớp bảng màu & nét viền của Minh (minh_regular / minh_uniform):
##   1. Bấm vào tủ để mở cửa tủ.
##   2. Kéo (Drag & Drop) lần lượt 3 chiếc áo bị bắt nạt / làm rách ra khỏi tủ:
##      - Áo đồng phục rách vai, dính dấu giày bùn & khăn quàng đỏ
##      - Áo sơ mi bị tạt mực tím & vẽ bậy
##      - Áo khoác bị rạch rách, đứt tay áo
##   3. Lộ ra bộ áo quần nguyên vẹn (áo thun kem + quần xanh giống Minh) → bấm hoặc kéo ra để lấy.

signal clothes_collected
signal closed(got_clothes: bool)

enum Stage { CLOSED, SEARCHING, COLLECTED }

const FONT := preload("res://assets/fonts/vt323_regular.ttf")
const SFX_CLICK := "res://assets/audio/sfx/typing/key_02.wav"
const SFX_RUSTLE := "res://assets/audio/sfx/fishing/cast.wav"
const SFX_DROP := "res://assets/audio/sfx/typing/key_01.wav"
const SFX_PICKUP := "res://assets/audio/sfx/fishing/catch.wav"

const WARDROBE_DROP_RADIUS := 245.0
const CLICK_DRAG_THRESHOLD := 12.0
const PIXEL_SCALE := 8.0 # 36x39 px × 8 = 288x312 px sắc nét

const PIXEL_PALETTE := {
	"O": Color8(24, 24, 38),
	"W": Color8(247, 249, 235),
	"L": Color8(255, 255, 252),
	"S": Color8(183, 194, 208),
	"D": Color8(138, 150, 168),
	"R": Color8(223, 62, 66),
	"r": Color8(158, 36, 44),
	"B": Color8(75, 97, 181),
	"b": Color8(51, 65, 122),
	"n": Color8(39, 46, 69),
	"M": Color8(122, 83, 56),
	"m": Color8(78, 51, 34),
	"I": Color8(86, 46, 138),
	"i": Color8(48, 22, 82),
	"J": Color8(71, 80, 104),
	"j": Color8(49, 55, 74),
	"k": Color8(99, 110, 138),
	"t": Color8(208, 213, 224),
	"H": Color8(179, 130, 82),
	"h": Color8(125, 86, 52),
	"G": Color8(168, 176, 194),
	"X": Color8(18, 16, 26),
}

const ART_MUD_UNIFORM: PackedStringArray = [
	".................OO.................",
	"................OGGO................",
	"................O..O................",
	".................OO.................",
	"................OHHO................",
	".............OOOHHHHOOO.............",
	"...........OOHHHHHHHHHHOO...........",
	".........OOHHHhOOOOOOOHHHOO.........",
	"........OOLLWWO......OWWLLOO........",
	"......OOLLWWWOOR....ROOWWWOO........",
	".....OLLWWWWWWORR..RROOWWWWO........",
	"....OLLWWWWWWWORRRRRROOWWWWSO.......",
	"...OLLWWWWWWWWWOORROOWWWWWWSO.......",
	"..OLLWWWWWWWWWOORRRROOWWWW.O........",
	"..OLWWWWWWWWWOORRrrRROOWWWSO........",
	".OLLWWWWWSOOOWWRROORROOWWSO.........",
	".OOSWWWWWSOWWWRRO..ORROWWSO.........",
	"..OOSSWWWOOWWWRO....OROWWSO.........",
	"....OOOOOOOWWWOO....OOWWWSO.........",
	"..........OWWWWWWWWWWWWWWSO.........",
	"..........OWWWWmMmMWWWWWWSO.........",
	"..........OWWWmMMMmWWWWWWSO.........",
	"..........OWWWmMmMMmWWWWWSO.........",
	"..........OWWWWmMMMmMWWWWSO.........",
	"..........OWWWWWmMmMmWWWWSO.........",
	"..........OWWWWWWmMMmWWWWSO.........",
	"..........OWWWWWWWmmWWWWWSO.........",
	"..........OWWWWWWWSWWWWWSSO.........",
	"..........OWWWWWWWWWWWWWSSO.........",
	"..........OSWWWWWWWWWWWWSSO.........",
	"..........OSWWWWWWWWSSWWSSO.........",
	"..........OSSWWWWWWSS.OSSSO.........",
	"..........OSSWWWSO.....OSSO.........",
	"..........OSSO..O.......OSO.........",
	"...........OO............O..........",
	"....................................",
	"....................................",
	"....................................",
	"....................................",
]

const ART_INK_SHIRT: PackedStringArray = [
	".................OO.................",
	"................OGGO................",
	"................O..O................",
	".................OO.................",
	"................OHHO................",
	".............OOOHHHHOOO.............",
	"...........OOHHHHHHHHHHOO...........",
	".........OOHHHhOOOOOOOHHHOO.........",
	"........OOLLWWO......OWWLLOO........",
	"......OOLLWWWWOO....OOWWWWLLOO......",
	".....OLLWWWWWWWO....OWWWWWWWLLO.....",
	"....OLLWWWiIWWWOO..OOWWWWWWWWLLO....",
	"...OLLWWWiIiIWWWOOOOOWWWWWWWWWLLO...",
	"..OLLWWWWiIiIWWWWWWWWWWiIWWWWWWLLO..",
	"..OLWWWWWWiIWWWWWWWSWWiIiWWWWWWWLO..",
	".OLLWWWWWSOOOWWWWWWSWWWIIWWOOOSWLLO.",
	".OOSWWWWWSOWWWWWWWWSWWWWWWWOOWSWSOO.",
	"..OOSSWWWOOWWWWRRWWSWWWWWWWOOWWSSO..",
	"....OOOOOOOWWWR..RWSWWWWWWWO.OOOO...",
	"..........OWWWWRR.WSWWRWRWWO........",
	"..........OWWWWWW.WSWRWRRWWO........",
	"..........OWWWWWWWWSWRWWWRWO........",
	"..........OWWWRRRWWSWWWWWSSO........",
	"..........OWWWWWWWWSWWiIWWWO........",
	"..........OWWWiIWWWSWiIiIWWO........",
	"..........OWWiIiIWWSWiIiIWWO........",
	"..........OWWWiIIWWSWWiiWWWO........",
	"..........OWWWWiWWWSWWWWWWWO........",
	"..........OSWWWWWWWSWWWWWWWO........",
	"..........OSWWWWWWWWWWWWSSSO........",
	"..........OSSWWWWWWWWWWSSSO.........",
	"..........OSSSWWWWSWWWWWSSO.........",
	"...........OOSWWO..OOSWWSO..........",
	".............OSSO....OSSO...........",
	"..............OO......OO............",
	"....................................",
	"....................................",
	"....................................",
	"....................................",
]

const ART_TORN_JACKET: PackedStringArray = [
	".................OO.................",
	"................OGGO................",
	"................O..O................",
	".................OO.................",
	"................OHHO................",
	".............OOOHHHHOOO.............",
	"...........OOHHHHHHHHHHOO...........",
	".........OOHHHhOOOOOOOHHHOO.........",
	"........OOkkJJO......OJJkkOO........",
	"......OOkkJJJJOO....OOJJJJOO........",
	".....OkkJJJJJJJOO..OOJJJJJO.........",
	"....OkkJJJJJJJJJO..OJJJJJJO.........",
	"...OkkJJJJJJJJJJO..OJJJJJO..........",
	"..OkkJJJJJJJJJJJOOOOJJJJJJO.........",
	"..OkJJJJJJJJJJJJJOJJJJJJJjO.........",
	".OkkJJJJJjOOOJJJJOGJJJJJ.O..........",
	".OOjJJJJJjOJJJJJJOJJJJJJjO..........",
	"..OOjjJJJOOJJJJJJOGJJJJJjO..........",
	"....OOOOOOOJJJJJJOJJJJJJjO..........",
	"..........OJJXXttOJJJJJJjO..........",
	"..........OJJJXXXtOJJJJJjO..........",
	"..........OJJJJXXttOJJJJjO..........",
	"..........OJJJJJJOXXttJJjO..........",
	"..........OJJJJJJOJXXXtJjO..........",
	"..........OJJJJJJOGJXXttjO..........",
	"..........OJJJJJJOJJJXXtjO..........",
	"..........OJJJJJJOJJJJJJjO..........",
	"..........OJJXXttOJJJJJJjO..........",
	"..........OJJJXXXtJJJJJJjO..........",
	"..........OJJJJXXtOJJJJjjO..........",
	"..........OjJJJJJJOJJJjjjO..........",
	"..........OjjJJJjjOjjJjjjO..........",
	"..........OjjJjjO..OjjjjO...........",
	"..........OjjjO.....OjjO............",
	"...........OO........OO.............",
	"....................................",
	"....................................",
	"....................................",
	"....................................",
]

const ART_INTACT_OUTFIT: PackedStringArray = [
	".................OO.................",
	"................OGGO................",
	"................O..O................",
	".................OO.................",
	"................OHHO................",
	".............OOOHHHHOOO.............",
	"...........OOHHHHHHHHHHOO...........",
	".........OOHHHhOOOOOOOHHHOO.........",
	"........OOLLWWO......OWWLLOO........",
	"......OOLLWWWWOO....OOWWWWLLOO......",
	".....OLLWWWWWWWOOOOOOWWWWWWWLLO.....",
	"....OLLWWWWWWWWWWWWWWWWWWWWWWLLO....",
	"...OLLWWWWWWWWWWWWWWWWWWWWWWWWLLO...",
	"..OLLWWWWWWWWWWWWWWWWWWWWWWWWWWLLO..",
	"..OLWWWWWWWWWWWWWWWWWWWWWWWWWWWWLO..",
	".OLLWWWWWSOOOWWWWWWWWWWWWOOOSWWWLLO.",
	".OOSWWWWWSOWWWWWWWWWWWWWWWOWSWWWSOO.",
	"..OOSSWWWOOWWWWWWWWWWWWWWWOWWWSSOO..",
	"....OOOOOOOWWWWWWWWWWWWWWWOO.OOOO...",
	"..........OWWWWWWWWWWWWWWWO.........",
	"..........OWWWWWWWWWWWWWWWO.........",
	"..........OWWWWWWWWWWWWWWWO.........",
	"..........OSWWWWWWWWWWWWWWO.........",
	"..........OSSWWWWWWWWWWWSSO.........",
	"..........OSSSSSSSSSSSSSSSO.........",
	"..........OOOOOOOOOOOOOOOOO.........",
	"..........OnnBBBBBBBBBBBnnO.........",
	"..........OnnBBBBBBBBBBBnnO.........",
	"..........OnnBBBBBBBBBBbbnO.........",
	"..........OnnBBBBBbBBBBbbnO.........",
	"..........OnnBBBBBnBBBBbbnO.........",
	"..........OnnBBBBnOnBBBbbnO.........",
	"..........OnnBBBBnOnBBBbbnO.........",
	"..........OnnBBBBnOnBBBbbnO.........",
	"..........OnnbbbbnOnbbbbnnO.........",
	"..........OOOOOOOO.OOOOOOOO.........",
	"....................................",
	"....................................",
	"....................................",
]

var _stage: Stage = Stage.CLOSED
var _player: Player = null
var _t: float = 0.0
var _open_anim: float = 0.0
var _shake: float = 0.0
var _mood_flash: float = 0.0
var _closing: bool = false

## Cache texture pixel art: id -> { hanger, floor, hanger_glow, floor_glow }
var _sprites: Dictionary = {}

## 4 lớp đồ trong tủ từ trong ra ngoài (index 0 = bộ nguyên vẹn sâu nhất, index 3 = áo rách ngoài cùng)
var _items: Array[Dictionary] = []
var _dragging_idx: int = -1
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _wardrobe_hovered: bool = false
var _hover_tooltip: String = ""

var _canvas: Control
var _step_label: Label
var _thought_label: Label
var _close_btn: Button
var _sfx: AudioStreamPlayer


func open(player: Player) -> void:
	_player = player
	if _player:
		_player.lock(&"wardrobe_search")
	show()


func _ready() -> void:
	layer = 78
	_sfx = AudioStreamPlayer.new()
	_sfx.volume_db = -8.0
	add_child(_sfx)
	_build_pixel_sprites()
	_build_ui()
	_init_items()
	_update_step_hint()
	_set_thought("Tủ áo quần cũ của mình... Mở ra xem còn bộ nào mặc được mang về quê không.")


func _build_pixel_sprites() -> void:
	_sprites[&"mud_uniform"] = _make_sprite_bundle(ART_MUD_UNIFORM)
	_sprites[&"ink_shirt"] = _make_sprite_bundle(ART_INK_SHIRT)
	_sprites[&"torn_jacket"] = _make_sprite_bundle(ART_TORN_JACKET)
	_sprites[&"intact_outfit"] = _make_sprite_bundle(ART_INTACT_OUTFIT)


func _make_sprite_bundle(rows: PackedStringArray) -> Dictionary:
	var hanger_img := _rasterize(rows, false)
	var floor_img := _rasterize(rows, true)
	return {
		"hanger": ImageTexture.create_from_image(hanger_img),
		"floor": ImageTexture.create_from_image(floor_img),
		"hanger_glow": ImageTexture.create_from_image(_make_outline_mask(hanger_img)),
		"floor_glow": ImageTexture.create_from_image(_make_outline_mask(floor_img)),
	}


func _rasterize(rows: PackedStringArray, strip_hanger: bool) -> Image:
	var h: int = rows.size()
	var w: int = rows[0].length()
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		if strip_hanger and y < 8:
			continue
		var row: String = rows[y]
		for x in w:
			var ch: String = row.substr(x, 1)
			if PIXEL_PALETTE.has(ch):
				img.set_pixel(x, y, PIXEL_PALETTE[ch])
	return img


## Tạo lớp viền sáng 1px pixel art ôm sát đúng đường nét của sprite
func _make_outline_mask(src: Image) -> Image:
	var w: int = src.get_width()
	var h: int = src.get_height()
	var out := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.1:
				continue
			for d in dirs:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and nx < w and ny >= 0 and ny < h and src.get_pixel(nx, ny).a > 0.1:
					out.set_pixel(x, y, Color.WHITE)
					break
	return out


func _build_ui() -> void:
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	var c := _wardrobe_center()
	var sz := Vector2(36.0, 39.0) * PIXEL_SCALE
	_items = [
		{
			"id": &"intact_outfit",
			"name": "Bộ áo quần nguyên vẹn",
			"size": sz,
			"pos": c + Vector2(0, -34),
			"rest_pos": c + Vector2(0, -34),
			"rot": 0.0,
			"removed": false,
			"unlocked": false,
			"hover": false,
			"visible": true,
		},
		{
			"id": &"torn_jacket",
			"name": "Áo khoác bị rạch rách",
			"size": sz,
			"pos": c + Vector2(-22, -34),
			"rest_pos": c + Vector2(-22, -34),
			"rot": -0.04,
			"removed": false,
			"unlocked": false,
			"hover": false,
			"visible": true,
		},
		{
			"id": &"ink_shirt",
			"name": "Áo bị tạt mực & vẽ bậy",
			"size": sz,
			"pos": c + Vector2(20, -34),
			"rest_pos": c + Vector2(20, -34),
			"rot": 0.04,
			"removed": false,
			"unlocked": false,
			"hover": false,
			"visible": true,
		},
		{
			"id": &"mud_uniform",
			"name": "Áo đồng phục rách vai",
			"size": sz,
			"pos": c + Vector2(-4, -34),
			"rest_pos": c + Vector2(-4, -34),
			"rot": -0.02,
			"removed": false,
			"unlocked": true, # Chiếc áo rách ngoài cùng mở khoá trước tiên
			"hover": false,
			"visible": true,
		},
	]


func _wardrobe_center() -> Vector2:
	var sz := _canvas.size if _canvas and _canvas.size.x > 10.0 else Vector2(1920, 1080)
	return Vector2(sz.x * 0.5, sz.y * 0.45)


func _wardrobe_rect() -> Rect2:
	var c := _wardrobe_center()
	return Rect2(c - Vector2(216, 272), Vector2(432, 544))


func _process(delta: float) -> void:
	_t += delta
	if _stage != Stage.CLOSED:
		_open_anim = minf(1.0, _open_anim + delta * 4.5)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 3.8)
	if _mood_flash > 0.0:
		_mood_flash = maxf(0.0, _mood_flash - delta * 1.4)

	var c := _wardrobe_center()
	var offsets: Array[Vector2] = [
		Vector2(0, -34),
		Vector2(-22, -34),
		Vector2(20, -34),
		Vector2(-4, -34),
	]
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
				return
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

	_wardrobe_hovered = false
	_hover_tooltip = ""
	for it in _items:
		it.hover = false

	if _stage == Stage.CLOSED:
		_wardrobe_hovered = _wardrobe_rect().has_point(mpos)
		if _wardrobe_hovered:
			_hover_tooltip = "Bấm để mở tủ áo quần"
			_canvas.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		else:
			_canvas.mouse_default_cursor_shape = Control.CURSOR_ARROW
		return

	if _stage == Stage.SEARCHING:
		var top_idx := _hit_test_items(mpos)
		if top_idx >= 0:
			_items[top_idx].hover = true
			var it := _items[top_idx]
			if it.id == &"intact_outfit" and it.unlocked:
				_hover_tooltip = "Bộ áo quần nguyên vẹn — Bấm hoặc kéo ra để lấy"
				_canvas.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			elif not it.removed and it.unlocked:
				_hover_tooltip = "%s — Giữ chuột kéo ra khỏi tủ" % it.name
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
		if _wardrobe_rect().has_point(mpos):
			_open_wardrobe()
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
		_dragging_idx = idx
		_drag_start_mouse = mpos
		_drag_offset = (it.pos as Vector2) - mpos
		_play_sfx(SFX_RUSTLE, 1.1)


func _handle_mouse_up(mpos: Vector2) -> void:
	if _dragging_idx < 0:
		return
	var idx := _dragging_idx
	var it := _items[idx]
	_dragging_idx = -1
	_canvas.mouse_default_cursor_shape = Control.CURSOR_ARROW

	var item_pos: Vector2 = it.pos
	var dist_moved: float = mpos.distance_to(_drag_start_mouse)
	var dist_from_wardrobe: float = item_pos.distance_to(_wardrobe_center())

	# Bộ áo quần nguyên vẹn: bấm (Point & Click) HOẶC kéo ra khỏi tủ đều lấy được
	if it.id == &"intact_outfit":
		if dist_moved <= CLICK_DRAG_THRESHOLD or not _wardrobe_rect().has_point(item_pos) or dist_from_wardrobe >= WARDROBE_DROP_RADIUS * 0.7:
			_collect_clothes()
		return

	# 3 chiếc áo rách: chỉ cần kéo ra khỏi tủ là được
	var outside_wardrobe := not _wardrobe_rect().has_point(item_pos) or dist_from_wardrobe >= WARDROBE_DROP_RADIUS
	if outside_wardrobe:
		it.removed = true
		it.rot = -0.14 if item_pos.x < _wardrobe_center().x else 0.14
		_play_sfx(SFX_DROP, 0.86)
		_on_shirt_dragged_out(it.id)
	else:
		_play_sfx(SFX_DROP, 1.1)
		_set_thought("Kéo cái áo rách này ra khỏi tủ để xem bên trong còn gì không...")


func _open_wardrobe() -> void:
	_stage = Stage.SEARCHING
	_open_anim = 0.0
	_shake = 0.30
	_play_sfx(SFX_RUSTLE, 0.88)
	_update_step_hint()
	_set_thought("Mấy cái áo treo ngoài cùng toàn là đồ mặc đi học bị tụi nó làm rách... Kéo ra tìm bộ lành lặn thôi.")


func _on_shirt_dragged_out(id: StringName) -> void:
	if id == &"mud_uniform":
		_items[2].unlocked = true
		_shake = 0.42
		_mood_flash = 0.80
		_set_thought("...Áo đồng phục hôm bị tụi nó đẩy ngã ngoài sân, rách toạc vai với dính nguyên dấu giày.")
	elif id == &"ink_shirt":
		_items[1].unlocked = true
		_shake = 0.44
		_mood_flash = 0.85
		_set_thought("...Cái này bị tạt mực với vẽ bậy đầy lên. Giặt mấy lần cũng không ra nổi.")
	elif id == &"torn_jacket":
		_items[0].unlocked = true
		_shake = 0.38
		_mood_flash = 0.70
		_set_thought("...Áo khoác cũng bị rạch rách luôn rồi. May quá, sâu bên trong vẫn còn một bộ nguyên vẹn!")
	_update_step_hint()


func _inspect_removed_item(id: StringName) -> void:
	_play_sfx(SFX_CLICK, 0.9)
	if id == &"mud_uniform":
		_set_thought("Dấu giày với vết rách ở vai... Hôm đó về mình chỉ dám giấu vào tủ.")
	elif id == &"ink_shirt":
		_set_thought("Mực tím loang lổ với mấy nét vẽ bậy... Để lại hết ở đây đi.")
	elif id == &"torn_jacket":
		_set_thought("Áo khoác rách nát rồi, không mang theo làm gì nữa.")


func _collect_clothes() -> void:
	if _stage == Stage.COLLECTED:
		return
	_stage = Stage.COLLECTED
	_items[0].removed = true
	_items[0].visible = false
	_play_sfx(SFX_PICKUP, 1.0)

	GameState.set_flag("ch0.got_clothes", true)
	GameState.add_item("clothes", 1, true)
	_update_step_hint()
	_set_thought("May quá, bộ áo quần này vẫn còn nguyên vẹn. Mang theo về quê thôi.")
	clothes_collected.emit()

	await get_tree().create_timer(1.35).timeout
	if is_inside_tree() and not _closing:
		_close_self()


func _close_self() -> void:
	if _closing:
		return
	_closing = true
	var got_clothes := GameState.has_flag("ch0.got_clothes")
	if is_instance_valid(_player):
		_player.unlock(&"wardrobe_search")
	closed.emit(got_clothes)
	queue_free()


func _torn_removed_count() -> int:
	var n := 0
	for i in [1, 2, 3]:
		if _items[i].removed:
			n += 1
	return n


func _update_step_hint() -> void:
	if _stage == Stage.CLOSED:
		_step_label.text = "Bấm vào tủ áo quần để mở"
	elif _stage == Stage.COLLECTED:
		_step_label.text = "Đã lấy được bộ áo quần nguyên vẹn!"
	elif _torn_removed_count() < 3:
		_step_label.text = "Kéo mấy chiếc áo bị rách ra khỏi tủ (%d/3)" % _torn_removed_count()
	else:
		_step_label.text = "Bấm hoặc kéo bộ áo quần nguyên vẹn để lấy"


func _set_thought(text: String) -> void:
	if _thought_label:
		_thought_label.text = text


func _hit_test_items(mpos: Vector2) -> int:
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
	# Vùng bấm vừa gọn theo thân áo (bỏ phần viền trong suốt thừa)
	var half: Vector2 = (it.size as Vector2) * Vector2(0.42, 0.44)
	return absf(local.x) <= half.x and absf(local.y) <= half.y


func _play_sfx(path: String, pitch: float = 1.0) -> void:
	if _sfx and ResourceLoader.exists(path):
		_sfx.stream = load(path)
		_sfx.pitch_scale = pitch
		_sfx.play()


# ==============================================================================
# VẼ TỦ ÁO QUẦN & ÁO QUẦN PIXEL ART
# ==============================================================================

func _on_draw_stage() -> void:
	var sz := _canvas.size
	var shake_off := (Vector2(sin(_t * 58.0), cos(_t * 47.0)) * (8.0 * _shake)).round()
	var center := (_wardrobe_center() + shake_off).round()

	# 1. Nền tối mờ
	_canvas.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.05, 0.04, 0.08, 0.88))

	# 2. Vẽ tủ áo quần kiểu khối pixel
	if _stage == Stage.CLOSED:
		_draw_wardrobe_closed(center)
	else:
		_draw_wardrobe_open_back(center)
		for i in _items.size():
			if _items[i].visible and not _items[i].removed and _dragging_idx != i:
				_draw_item(_items[i], shake_off, false)
		_draw_wardrobe_open_doors(center)

		for i in _items.size():
			if _items[i].visible and _items[i].removed and _dragging_idx != i:
				_draw_item(_items[i], shake_off, false)

		if _dragging_idx >= 0:
			_draw_item(_items[_dragging_idx], Vector2.ZERO, true)

	# 3. Nháy sắc tối buồn khi kéo áo bị bắt nạt ra
	if _mood_flash > 0.01:
		_canvas.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.45, 0.08, 0.14, 0.22 * _mood_flash))

	# 4. Tooltip nhỏ cạnh con trỏ
	if not _hover_tooltip.is_empty() and _dragging_idx < 0:
		var m := _canvas.get_local_mouse_position()
		var tsize := FONT.get_string_size(_hover_tooltip, HORIZONTAL_ALIGNMENT_LEFT, -1, 32)
		var box_pos := Vector2(clampf(m.x - tsize.x * 0.5, 24.0, sz.x - tsize.x - 44.0), maxf(108.0, m.y - 54.0))
		var rect := Rect2(box_pos - Vector2(12, 6), tsize + Vector2(24, 14))
		_canvas.draw_rect(rect, Color(0.06, 0.06, 0.11, 0.92))
		_canvas.draw_rect(rect, Color(0.95, 0.86, 0.55, 0.9), false, 2.0)
		_canvas.draw_string(FONT, box_pos + Vector2(0, tsize.y - 4), _hover_tooltip, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0.98, 0.95, 0.85))


func _draw_wardrobe_closed(c: Vector2) -> void:
	var hover_glow := 1.0 if _wardrobe_hovered else (0.55 + 0.35 * sin(_t * 3.5))
	_canvas.draw_set_transform(c, 0.0, Vector2.ONE)

	# Bóng pixel dưới chân tủ
	_canvas.draw_rect(Rect2(-224, 256, 448, 24), Color(0, 0, 0, 0.45))

	# Viền pixel sáng báo bấm được
	_canvas.draw_rect(Rect2(-216, -272, 432, 544), Color(1.0, 0.92, 0.58, 0.88 * hover_glow))

	# Khung tủ gỗ nâu tím tối (khớp wardorbe.png)
	_canvas.draw_rect(Rect2(-208, -264, 416, 528), Color8(24, 24, 38))
	_canvas.draw_rect(Rect2(-200, -256, 400, 512), Color8(62, 44, 52))

	# Hai cánh cửa tủ đóng kín (pixel khối 8px)
	_canvas.draw_rect(Rect2(-184, -240, 176, 360), Color8(74, 53, 62))
	_canvas.draw_rect(Rect2(-184, -240, 176, 360), Color8(24, 24, 38), false, 8.0)
	_canvas.draw_rect(Rect2(8, -240, 176, 360), Color8(68, 49, 58))
	_canvas.draw_rect(Rect2(8, -240, 176, 360), Color8(24, 24, 38), false, 8.0)

	# Khung soi gỗ bên trong cánh cửa
	_canvas.draw_rect(Rect2(-160, -216, 128, 312), Color8(52, 36, 44), false, 8.0)
	_canvas.draw_rect(Rect2(32, -216, 128, 312), Color8(52, 36, 44), false, 8.0)

	# Tay nắm kim loại pixel
	var handle_col := Color8(245, 224, 145) if _wardrobe_hovered else Color8(168, 172, 190)
	_canvas.draw_rect(Rect2(-32, -48, 16, 56), Color8(24, 24, 38))
	_canvas.draw_rect(Rect2(-28, -44, 8, 48), handle_col)
	_canvas.draw_rect(Rect2(16, -48, 16, 56), Color8(24, 24, 38))
	_canvas.draw_rect(Rect2(20, -44, 8, 48), handle_col)

	# Hai ngăn kéo phía dưới
	for row_i in 2:
		var dy := 136.0 + row_i * 56.0
		_canvas.draw_rect(Rect2(-184, dy, 368, 48), Color8(56, 40, 48))
		_canvas.draw_rect(Rect2(-184, dy, 368, 48), Color8(24, 24, 38), false, 8.0)
		_canvas.draw_rect(Rect2(-32, dy + 16, 64, 16), Color8(24, 24, 38))
		_canvas.draw_rect(Rect2(-24, dy + 20, 48, 8), Color8(136, 132, 148))

	_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_wardrobe_open_back(c: Vector2) -> void:
	_canvas.draw_set_transform(c, 0.0, Vector2.ONE)
	_canvas.draw_rect(Rect2(-232, 256, 464, 24), Color(0, 0, 0, 0.48))

	# Khung ngoài tủ gỗ
	_canvas.draw_rect(Rect2(-216, -272, 432, 544), Color8(24, 24, 38))
	_canvas.draw_rect(Rect2(-208, -264, 416, 528), Color8(62, 44, 52))

	# Khoang tối bên trong tủ
	_canvas.draw_rect(Rect2(-184, -240, 368, 384), Color8(24, 20, 30))
	_canvas.draw_rect(Rect2(-176, -232, 352, 368), Color8(36, 28, 40))

	# Thanh treo kim loại ngang (khớp đúng vị trí móc áo ở y = -182)
	_canvas.draw_rect(Rect2(-184, -196, 368, 16), Color8(24, 24, 38))
	_canvas.draw_rect(Rect2(-176, -192, 352, 8), Color8(148, 152, 172))

	# Hai ngăn kéo dưới đáy tủ
	for row_i in 2:
		var dy := 152.0 + row_i * 48.0
		_canvas.draw_rect(Rect2(-184, dy, 368, 40), Color8(56, 40, 48))
		_canvas.draw_rect(Rect2(-184, dy, 368, 40), Color8(24, 24, 38), false, 8.0)
		_canvas.draw_rect(Rect2(-24, dy + 16, 48, 8), Color8(136, 132, 148))

	_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_wardrobe_open_doors(c: Vector2) -> void:
	_canvas.draw_set_transform(c, 0.0, Vector2.ONE)
	var wing_w: float = roundf(lerpf(16.0, 56.0, _open_anim) / 8.0) * 8.0
	# Hai cánh cửa mở dựng 2 bên khung tủ kiểu pixel khối
	_canvas.draw_rect(Rect2(-208 - wing_w, -264, wing_w, 528), Color8(24, 24, 38))
	_canvas.draw_rect(Rect2(-200 - wing_w, -256, maxf(8.0, wing_w - 8.0), 512), Color8(52, 36, 44))
	_canvas.draw_rect(Rect2(208, -264, wing_w, 528), Color8(24, 24, 38))
	_canvas.draw_rect(Rect2(208, -256, maxf(8.0, wing_w - 8.0), 512), Color8(52, 36, 44))
	_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_item(it: Dictionary, shake_off: Vector2, is_dragging: bool) -> void:
	var pos: Vector2 = ((it.pos as Vector2) + shake_off).round()
	var rot: float = 0.0 if is_dragging else float(it.rot)
	var sc: float = 1.06 if is_dragging else (1.03 if it.hover and it.unlocked else 1.0)
	var glow: bool = (it.hover and it.unlocked) or (it.id == &"intact_outfit" and it.unlocked and not it.removed)
	var on_hanger: bool = not bool(it.removed) and not is_dragging

	var bundle: Dictionary = _sprites[it.id]
	var tex: Texture2D = bundle["hanger"] if on_hanger else bundle["floor"]
	var glow_tex: Texture2D = bundle["hanger_glow"] if on_hanger else bundle["floor_glow"]

	var sz: Vector2 = it.size
	var half: Vector2 = sz * 0.5
	var rect := Rect2(-half, sz)

	_canvas.draw_set_transform(pos, rot, Vector2.ONE * sc)

	# Bóng pixel nhẹ phía sau
	var shadow_off := Vector2(12, 16) if is_dragging else Vector2(6, 8)
	_canvas.draw_texture_rect(tex, Rect2(-half + shadow_off, sz), false, Color(0, 0, 0, 0.35 if is_dragging else 0.25))

	# Viền sáng 1px pixel art khi hover hoặc bộ nguyên vẹn đã lộ ra
	if glow:
		var pulse := 0.72 + 0.28 * sin(_t * 5.0)
		_canvas.draw_texture_rect(glow_tex, rect, false, Color(1.0, 0.93, 0.58, 0.95 * pulse))

	# Sprite áo quần pixel art sắc nét
	_canvas.draw_texture_rect(tex, rect, false)

	# Đốm sáng pixel lấp lánh quanh bộ đồ nguyên vẹn khi đã mở khoá
	if it.id == &"intact_outfit" and it.unlocked and not it.removed:
		var sp := 0.45 + 0.55 * sin(_t * 5.5)
		_draw_pixel_sparkle(Vector2(-88, -64), Color(1.0, 0.97, 0.75, sp))
		_draw_pixel_sparkle(Vector2(88, 8), Color(1.0, 0.97, 0.75, 1.0 - sp + 0.35))

	_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_pixel_sparkle(c: Vector2, col: Color) -> void:
	var p := c.round()
	_canvas.draw_rect(Rect2(p + Vector2(-12, -4), Vector2(24, 8)), col)
	_canvas.draw_rect(Rect2(p + Vector2(-4, -12), Vector2(8, 24)), col)


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
