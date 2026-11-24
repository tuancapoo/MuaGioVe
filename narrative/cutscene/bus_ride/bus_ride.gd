class_name BusRideCutscene
extends CanvasLayer
## Cutscene cuối Chương 0: Góc nhìn bên trong xe khách về quê — Minh (animation Idle phóng to từ thắt lưng lên)
## ngồi cạnh cửa sổ lớn nhìn cảnh đồng quê (map field) trôi qua.
## - Chạy độc lập bằng F6 để xem thử ngay.
## - Hoặc gọi từ Chapter0Room khi Minh rời phòng thành phố; phát signal `finished` khi xong.

signal finished

const DIALOGUE_PATH := "res://data/dialogues/ch0_bus_ride.dialogue"
const MINH_FRAMES := preload("res://assets/characters/minh/minh_regular_frames.tres")
const FONT := preload("res://assets/fonts/vt323_regular.ttf")

const CABIN_BACK_PATH := "res://assets/cutscenes/bus_ride/bus_cabin_back.png"
const CABIN_FRONT_PATH := "res://assets/cutscenes/bus_ride/bus_cabin_front.png"

const FIELD_LAYERS := [
	{"path": "res://assets/maps/lang_que_loop/01_Bau_troi.png", "speed": 6.0, "sync_ground": false},
	{"path": "res://assets/maps/lang_que_loop/02_May.png", "speed": 22.0, "sync_ground": false},
	{"path": "res://assets/maps/lang_que_loop/03_Nui.png", "speed": 55.0, "sync_ground": false},
	{"path": "res://assets/maps/lang_que_loop/04_Canh_dong_xa.png", "speed": 220.0, "sync_ground": true},
	{"path": "res://assets/maps/lang_que_loop/05_Nha_lang_tre_chuoi.png", "speed": 220.0, "sync_ground": true},
	{"path": "res://assets/maps/lang_que_loop/07_Duong_di.png", "speed": 220.0, "sync_ground": true},
	{"path": "res://assets/maps/lang_que_loop/08_Co_tien_canh.png", "speed": 220.0, "sync_ground": true},
	{"path": "res://assets/maps/lang_que_loop/92_Cay_tan_rong_tien_canh.png", "speed": 340.0, "sync_ground": false},
]

const AMB_WIND := "res://assets/audio/ambience/soft_wind.mp3"
const AMB_FIELD := "res://assets/audio/ambience/summer_field.mp3"

## Kích thước canvas logic pixel art (1920x1080 = phóng đúng 3x sắc nét)
const LOGICAL_SIZE := Vector2(640.0, 360.0)
const FIELD_WIDTH := 4608.0
const FIELD_Y_OFFSET := -44.0

## Khung cửa sổ toàn cảnh xe khách (toạ độ logic 640x360)
const WIN_RECT := Rect2(0.0, 88.0, 640.0, 198.0)

## Vị trí gốc của Minh (đảo gương sang bên trái, hướng mặt về phía phải, hiện từ phần áo trắng lên)
const MINH_BASE_POS := Vector2(226.0, 344.0)
const MINH_SCALE := Vector2(3.35, 3.35)

var _t: float = 0.0
var _speed_mult: float = 1.0
var _bump_y: float = 0.0
var _bump_timer: float = 0.8
var _glare_x: float = 0.0
var _standalone: bool = false
var _skipping: bool = false
var _done: bool = false

var _dialogue_res: DialogueResource
var _layer_entries: Array[Dictionary] = []
var _hidden_player: Node2D = null

var _viewport_root: Node2D
var _bg_container: Node2D
var _glass_fx: Node2D
var _cabin_back: Sprite2D
var _minh_sprite: AnimatedSprite2D
var _cabin_front: Sprite2D
var _front_fx: Node2D
var _ui_root: Control
var _fade_rect: ColorRect
var _title_box: VBoxContainer
var _skip_label: Label
var _replay_label: Label
var _amb_wind: AudioStreamPlayer
var _amb_field: AudioStreamPlayer


var _talking := false   # đang hiện một đoạn hội thoại của cutscene

func _ready() -> void:
	layer = 88 # Dưới DialogueBalloon (100) để hộp thoại hiện phía trên cutscene
	_standalone = get_tree().current_scene == self
	_dialogue_res = _load_dialogue()
	DialogueManager.dialogue_ended.connect(func(_r): _talking = false)
	# Ẩn tạm Player phía sau (nếu chạy từ Main) để hộp thoại Minh căn giữa gọn đẹp phía dưới màn hình
	var p := get_tree().get_first_node_in_group(&"player") as Node2D
	if p and p.visible:
		_hidden_player = p
		_hidden_player.visible = false
	_build_scene()
	_setup_audio()
	_fit_viewport()
	_run_sequence()


func _build_scene() -> void:
	var bg_black := ColorRect.new()
	bg_black.color = Color.BLACK
	bg_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_black.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg_black)

	_viewport_root = Node2D.new()
	_viewport_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_viewport_root)

	# 1. Các lớp cảnh map Field trôi ngoài cửa sổ
	_bg_container = Node2D.new()
	_bg_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_viewport_root.add_child(_bg_container)

	var ground_start_offset := randf_range(0.0, 900.0)
	for cfg: Dictionary in FIELD_LAYERS:
		var path: String = cfg["path"]
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		var s1 := Sprite2D.new()
		s1.texture = tex
		s1.centered = false
		s1.position = Vector2(0.0, FIELD_Y_OFFSET)
		var s2 := Sprite2D.new()
		s2.texture = tex
		s2.centered = false
		s2.position = Vector2(FIELD_WIDTH, FIELD_Y_OFFSET)
		_bg_container.add_child(s1)
		_bg_container.add_child(s2)
		var init_off: float = ground_start_offset if bool(cfg["sync_ground"]) else 0.0
		_layer_entries.append({
			"s1": s1,
			"s2": s2,
			"speed": float(cfg["speed"]),
			"offset": init_off,
		})

	# 2. Vệt sáng lướt nhẹ trên mặt kính cửa sổ (phía sau rèm & nội thất xe)
	_glass_fx = Node2D.new()
	_glass_fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_glass_fx.draw.connect(_draw_glass_fx)
	_viewport_root.add_child(_glass_fx)

	# 3. Lớp nội thất xe phía sau Minh (đảo gương ngang: rèm & ghế Minh bên trái, xe chạy về bên phải)
	_cabin_back = Sprite2D.new()
	_cabin_back.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cabin_back.centered = false
	_cabin_back.flip_h = true
	_cabin_back.texture = _load_png(CABIN_BACK_PATH)
	_viewport_root.add_child(_cabin_back)

	# 4. Minh dùng animation Idle gốc phóng to, hướng mặt sang phải (đúng chiều xe chạy), hiện từ phần áo lên
	_minh_sprite = AnimatedSprite2D.new()
	_minh_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_minh_sprite.sprite_frames = MINH_FRAMES
	_minh_sprite.animation = &"Idle"
	_minh_sprite.flip_h = false
	_minh_sprite.play(&"Idle")
	_minh_sprite.scale = MINH_SCALE
	_minh_sprite.position = MINH_BASE_POS
	_minh_sprite.modulate = Color(0.95, 0.94, 0.92)
	_viewport_root.add_child(_minh_sprite)

	# 5. Lớp tiền cảnh ghế trước bên phải + ghế lối đi bên trái (đảo gương ngang khớp _cabin_back)
	_cabin_front = Sprite2D.new()
	_cabin_front.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cabin_front.centered = false
	_cabin_front.flip_h = true
	_cabin_front.texture = _load_png(CABIN_FRONT_PATH)
	_viewport_root.add_child(_cabin_front)

	# 6. Vệt nắng hắt từ cửa sổ + letterbox đen điện ảnh + che mép ngoài 640x360
	_front_fx = Node2D.new()
	_front_fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_front_fx.draw.connect(_draw_front_fx)
	_viewport_root.add_child(_front_fx)

	# 7. UI lớp trên (gợi ý bỏ qua, fade đen, thẻ tên chương)
	_ui_root = Control.new()
	_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui_root)

	_skip_label = Label.new()
	_skip_label.text = "[Esc] Bỏ qua"
	_skip_label.add_theme_font_override(&"font", FONT)
	_skip_label.add_theme_font_size_override(&"font_size", 32)
	_skip_label.add_theme_color_override(&"font_color", Color(0.86, 0.86, 0.90, 0.65))
	_skip_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_skip_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_skip_label.offset_right = -28
	_skip_label.offset_top = 18
	_ui_root.add_child(_skip_label)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 1)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(_fade_rect)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(center)

	_title_box = VBoxContainer.new()
	_title_box.add_theme_constant_override(&"separation", 14)
	_title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_title_box.modulate.a = 0.0
	_title_box.hide()
	center.add_child(_title_box)

	var t1 := _make_label("Chương 1", 44, Color(0.96, 0.84, 0.48))
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(t1)

	var t2 := _make_label("Mùa hè ở Làng Cỏ", 74, Color(0.98, 0.96, 0.90))
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(t2)

	_replay_label = _make_label("[R] Xem lại cutscene   ·   [E] Thoát", 34, Color(0.68, 0.78, 0.95))
	_replay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_replay_label.hide()
	_title_box.add_child(_replay_label)


func _setup_audio() -> void:
	_amb_wind = _make_loop_player(AMB_WIND, -18.0)
	_amb_field = _make_loop_player(AMB_FIELD, -22.0)


func _make_loop_player(path: String, vol_db: float) -> AudioStreamPlayer:
	if not ResourceLoader.exists(path):
		return null
	var stream: AudioStream = load(path)
	if "loop" in stream:
		stream.loop = true
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = -50.0
	add_child(p)
	p.play()
	create_tween().tween_property(p, "volume_db", vol_db, 2.0)
	return p


func _fit_viewport() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return
	var sc := minf(vp.x / LOGICAL_SIZE.x, vp.y / LOGICAL_SIZE.y)
	_viewport_root.scale = Vector2(sc, sc)
	_viewport_root.position = ((vp - LOGICAL_SIZE * sc) * 0.5).round()


func _process(delta: float) -> void:
	_t += delta
	_fit_viewport()

	# Cuộn các lớp map field ngoài cửa sổ xe buýt
	for entry in _layer_entries:
		var spd: float = float(entry["speed"]) * _speed_mult
		var off: float = fposmod(float(entry["offset"]) + spd * delta, FIELD_WIDTH)
		entry["offset"] = off
		var s1: Sprite2D = entry["s1"]
		var s2: Sprite2D = entry["s2"]
		var x1: float = -floorf(off)
		s1.position.x = x1
		s2.position.x = x1 + FIELD_WIDTH

	# Nhịp xóc nhẹ của xe khách chạy trên đường làng
	_bump_timer -= delta
	if _bump_timer <= 0.0 and _speed_mult > 0.15:
		_bump_timer = randf_range(0.75, 1.65)
		_bump_y = 1.6 * _speed_mult
	_bump_y = lerpf(_bump_y, 0.0, clampf(delta * 10.0, 0.0, 1.0))

	var micro_vib: float = sin(_t * 19.0) * 0.35 * _speed_mult
	var cabin_y: float = roundf(_bump_y + micro_vib)
	_cabin_back.position.y = cabin_y
	_cabin_front.position.y = cabin_y
	_minh_sprite.position.y = MINH_BASE_POS.y + roundf(cabin_y + sin(_t * 4.5 - 0.4) * 0.5 * _speed_mult)

	# Vệt sáng phản chiếu lướt nhẹ qua mặt kính cửa sổ
	_glare_x = fposmod(_glare_x + 150.0 * _speed_mult * delta, 900.0)

	_glass_fx.queue_redraw()
	_front_fx.queue_redraw()


func _input(event: InputEvent) -> void:
	if _done and _standalone:
		if event.is_action_pressed(&"restart"):
			get_viewport().set_input_as_handled()
			get_tree().reload_current_scene()
		elif event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"pause"):
			get_viewport().set_input_as_handled()
			get_tree().quit()
		return

	if not _skipping and event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_skip_cutscene()


# --- Kịch bản diễn tiến cutscene ---------------------------------------------

func _run_sequence() -> void:
	await _tween_fade(0.0, 1.5)
	if not await _wait(2.2): return

	await _say("beat_1")
	if not await _wait(1.3): return

	await _say("beat_2")
	if not await _wait(1.2): return

	await _say("beat_3")
	if not await _wait(0.9): return

	# Xe chạy chậm dần khi tới gần Làng Cỏ
	create_tween().tween_property(self, "_speed_mult", 0.22, 3.2).set_trans(Tween.TRANS_SINE)
	await _say("beat_4")
	if not await _wait(1.1): return

	await _finish_sequence()


func _skip_cutscene() -> void:
	if _skipping or _done:
		return
	_skipping = true
	for child in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if child is DialogueBalloon:
			child.queue_free()
	await _finish_sequence()


func _finish_sequence() -> void:
	if _done:
		return
	_done = true
	_skip_label.hide()

	if _amb_wind:
		create_tween().tween_property(_amb_wind, "volume_db", -55.0, 1.2)
	if _amb_field:
		create_tween().tween_property(_amb_field, "volume_db", -55.0, 1.2)

	await _tween_fade(1.0, 1.1)
	if not is_inside_tree():
		return

	# Khi chạy độc lập bằng F6 thì hiện nút xem lại; khi chạy trong Chương 0 thì nối thẳng sang Góc cây đa
	if _standalone:
		_title_box.show()
		_replay_label.show()
		var tw := create_tween()
		tw.tween_property(_title_box, "modulate:a", 1.0, 0.6)
		await tw.finished
		return

	if is_instance_valid(_hidden_player):
		_hidden_player.visible = true
	finished.emit()
	queue_free()


func _wait(sec: float) -> bool:
	var left := sec
	while left > 0.0 and is_inside_tree() and not _skipping:
		await get_tree().process_frame
		left -= get_process_delta_time()
	return is_inside_tree() and not _skipping


func _say(cue: String) -> void:
	if _skipping or _dialogue_res == null:
		return
	# Hộp thoại được gắn vào scene hiện tại (Main khi chơi thật), không phải gốc cây —
	# nên chờ tín hiệu kết thúc hội thoại: người chơi bấm E qua hết các câu mới đi tiếp.
	_talking = true
	DialogueManager.show_dialogue_balloon(_dialogue_res, cue)
	while _talking and is_inside_tree() and not _skipping:
		await get_tree().process_frame


func _tween_fade(alpha: float, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", alpha, duration)
	await tw.finished


func _load_dialogue() -> DialogueResource:
	if FileAccess.file_exists(DIALOGUE_PATH):
		var raw := FileAccess.get_file_as_string(DIALOGUE_PATH)
		if not raw.is_empty():
			return DialogueManager.create_resource_from_text(raw)
	if ResourceLoader.exists(DIALOGUE_PATH):
		return load(DIALOGUE_PATH) as DialogueResource
	return null


func _load_png(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		var res := load(res_path)
		if res is Texture2D:
			return res
	var abs_path := ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img:
			return ImageTexture.create_from_image(img)
	return null


# ==============================================================================
# HIỆU ỨNG KÍNH, ÁNH NẮNG & KHUNG ĐIỆN ẢNH
# ==============================================================================

func _draw_glass_fx() -> void:
	var r := WIN_RECT
	_glass_fx.draw_rect(r, Color(0.88, 0.96, 1.0, 0.05))
	var gx := 820.0 - _glare_x
	for off_x: float in [0.0, 38.0]:
		var bw := 22.0 if off_x == 0.0 else 9.0
		var poly := PackedVector2Array([
			Vector2(gx + off_x, r.position.y),
			Vector2(gx + off_x + bw, r.position.y),
			Vector2(gx + off_x + 74.0 + bw, r.end.y),
			Vector2(gx + off_x + 74.0, r.end.y),
		])
		_glass_fx.draw_colored_polygon(poly, Color(1.0, 0.99, 0.92, 0.08))


func _draw_front_fx() -> void:
	var w := LOGICAL_SIZE.x
	var h := LOGICAL_SIZE.y

	# Vệt nắng ấm nhẹ hắt từ cửa sổ sang vai Minh (đảo gương sang bên trái)
	_front_fx.draw_colored_polygon(PackedVector2Array([
		Vector2(200, 88), Vector2(400, 88), Vector2(330, 344), Vector2(130, 344)
	]), Color(1.0, 0.94, 0.72, 0.065))

	# Thanh letterbox đen + che viền ngoài 640x360 (không lộ nền field trên màn rộng)
	var bar_h := 20.0
	_front_fx.draw_rect(Rect2(-1200, -400, w + 2400, 400 + bar_h), Color.BLACK)
	_front_fx.draw_rect(Rect2(-1200, h - bar_h, w + 2400, 400 + bar_h), Color.BLACK)
	_front_fx.draw_rect(Rect2(-1200, -400, 1200, h + 800), Color.BLACK)
	_front_fx.draw_rect(Rect2(w, -400, 1200, h + 800), Color.BLACK)


func _make_label(txt: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override(&"font", FONT)
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", col)
	return l
