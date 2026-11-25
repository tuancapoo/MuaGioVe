extends Node
## Cảnh kết thúc Chương 0 dưới Góc cây đa sau cutscene xe buýt:
## 1. Xe khách Phương Trang đậu trước căn nhà dưới gốc cây đa rồi chạy khuất sang trái.
## 2. Lộ ra Ông Nội, Minh và Bố đang đứng dưới gốc cây đa.
## 3. Diễn ra đoạn hội thoại căng thẳng giữa Bố, Minh và Ông Nội.
## 4. Kết thúc Chương 0 → fade đen → hiện màn hình tên "Chương 1 — Mùa hè ở Làng Cỏ"
##    → Bố rời đi, chỉ còn lại Minh và Ông Nội bắt đầu Chương 1.

const BUS_TEX_PATH := "res://assets/objects/bus_phuong_trang.png"
const DIALOGUE_PATH := "res://data/dialogues/ch1_arrival.dialogue"
const FONT := preload("res://assets/fonts/vt323_regular.ttf")

const FLAG_ARRIVING := "ch0.bus_arriving"
const FLAG_ARRIVED := "ch0.arrived_village"
const FLAG_CH0_COMPLETE := "ch0.complete"

var _bus_sprite: Sprite2D = null
var _bus_base_y: float = 256.0
var _bus_running: bool = false
var _bus_t: float = 0.0
var _dust_timer: float = 0.0
var _dust_layer: Node2D = null
var _puffs: Array[Dictionary] = []

var _title_layer: CanvasLayer = null
var _fade_rect: ColorRect = null
var _title_box: VBoxContainer = null


func _ready() -> void:
	if not GameState.has_flag(FLAG_ARRIVING):
		return
	call_deferred("_run_arrival")


func _run_arrival() -> void:
	# Đợi 1 frame để Main đặt Player xong ở Spawns/from_bus
	await get_tree().process_frame
	if not is_inside_tree():
		return

	var player := get_tree().get_first_node_in_group(&"player") as Player
	var ong_noi := get_parent().get_node_or_null("NPCs/OngNoi") as Node2D
	var bo := get_parent().get_node_or_null("NPCs/Bo") as Node2D

	if player:
		player.lock(&"bus_arrival")
		player.anim.flip_h = true # Minh quay mặt sang trái nhìn Ông Nội / theo hướng xe chạy
	if ong_noi:
		var spr := ong_noi.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if spr:
			spr.flip_h = false # Ông Nội đứng bên trái nhìn sang phải về phía Minh & Bố
	if bo:
		var spr_bo := bo.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if spr_bo:
			spr_bo.flip_h = true # Bố đứng bên phải nhìn sang trái về phía Minh & Ông Nội

	# Lớp khói bụi + xe khách Phương Trang đậu ngay phía trước 3 người
	_dust_layer = Node2D.new()
	_dust_layer.z_index = 14
	_dust_layer.draw.connect(_draw_dust)
	get_parent().add_child(_dust_layer)

	_bus_sprite = Sprite2D.new()
	_bus_sprite.name = "PhuongTrangBus"
	_bus_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bus_sprite.texture = _load_png(BUS_TEX_PATH)
	_bus_sprite.scale = Vector2(1.45, 1.45)
	_bus_sprite.z_index = 15 # Che phía trước Minh, Ông Nội, Bố; nằm sau tiền cảnh đường (z 50)
	_bus_base_y = 256.0
	_bus_sprite.position = Vector2(490.0, _bus_base_y)
	get_parent().add_child(_bus_sprite)

	_bus_running = true

	# Chờ SceneManager fade sáng xong + xe nổ máy một nhịp ngắn
	await get_tree().create_timer(1.05).timeout
	if not is_inside_tree():
		return

	# Xe khách Phương Trang tăng tốc chạy khuất sang trái
	var tw := create_tween()
	tw.tween_property(_bus_sprite, "position:x", -340.0, 2.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	if not is_inside_tree():
		return

	_bus_running = false
	if is_instance_valid(_bus_sprite):
		_bus_sprite.queue_free()
	_bus_sprite = null

	# Khoảng lặng ngắn khi xe đã khuất, lộ ra Ông Nội, Minh và Bố
	await get_tree().create_timer(0.45).timeout
	if not is_inside_tree():
		return

	if player and ong_noi:
		player.anim.flip_h = ong_noi.global_position.x < player.global_position.x

	# Hội thoại căng thẳng giữa Bố, Minh và Ông Nội
	var dlg := _load_dialogue()
	if dlg:
		DialogueManager.show_dialogue_balloon(dlg, "arrival_confrontation")
		await DialogueManager.dialogue_ended

	if not is_inside_tree():
		return

	# Kết thúc Chương 0 → Fade đen → Hiện thẻ tên Chương 1
	_build_chapter_title_overlay()
	var tw_dark := create_tween()
	tw_dark.tween_property(_fade_rect, "color:a", 1.0, 1.0)
	await tw_dark.finished
	if not is_inside_tree():
		return

	# Dọn bụi & chuyển trạng thái sang Chương 1 (Bố rời đi, chỉ còn Minh và Ông Nội)
	if is_instance_valid(_dust_layer):
		_dust_layer.queue_free()
	GameState.chapter = 1
	GameState.set_flag(FLAG_CH0_COMPLETE, true)
	GameState.set_flag(FLAG_ARRIVING, false)
	GameState.set_flag(FLAG_ARRIVED, true)

	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree():
		return

	# Hiện "Chương 1 — Mùa hè ở Làng Cỏ"
	_title_box.show()
	var tw_in := create_tween()
	tw_in.tween_property(_title_box, "modulate:a", 1.0, 0.85)
	await tw_in.finished
	if not is_inside_tree():
		return

	await get_tree().create_timer(2.2).timeout
	if not is_inside_tree():
		return

	var tw_out := create_tween()
	tw_out.tween_property(_title_box, "modulate:a", 0.0, 0.7)
	await tw_out.finished
	if not is_inside_tree():
		return

	# Giữ màn hình đen và chuyển thẳng sang phòng ngủ Minh ở quê bắt đầu nhiệm vụ sửa ống nước (Chương 1)
	if is_instance_valid(player):
		player.unlock(&"bus_arrival")
	var main := get_tree().current_scene
	if main and main.has_method("load_map"):
		main.load_map(load("res://world/areas/phong_ngu_minh/phong_ngu_minh.tscn"), "wake_up")
		return

	if is_instance_valid(_title_layer):
		_title_layer.queue_free()


func _build_chapter_title_overlay() -> void:
	_title_layer = CanvasLayer.new()
	_title_layer.name = "Chapter1TitleOverlay"
	_title_layer.layer = 92
	add_child(_title_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_title_layer.add_child(_fade_rect)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_layer.add_child(center)

	_title_box = VBoxContainer.new()
	_title_box.add_theme_constant_override(&"separation", 14)
	_title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_title_box.modulate.a = 0.0
	_title_box.hide()
	center.add_child(_title_box)

	var t1 := _make_label("Chương 1", 50, Color(0.96, 0.84, 0.48))
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(t1)

	var t2 := _make_label("Mùa hè ở Làng Cỏ", 80, Color(0.98, 0.96, 0.90))
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(t2)


func _process(delta: float) -> void:
	if _bus_running and is_instance_valid(_bus_sprite):
		_bus_t += delta
		_bus_sprite.position.y = _bus_base_y + roundf(sin(_bus_t * 34.0) * 1.1)
		_dust_timer -= delta
		if _dust_timer <= 0.0:
			_dust_timer = 0.09
			var tail_x: float = _bus_sprite.position.x + 215.0
			_puffs.append({
				"pos": Vector2(tail_x + randf_range(-10.0, 14.0), 336.0 + randf_range(-6.0, 4.0)),
				"vel": Vector2(randf_range(26.0, 64.0), randf_range(-18.0, -6.0)),
				"rad": randf_range(6.0, 12.0),
				"life": 0.0,
				"max": randf_range(0.55, 0.95),
			})

	if not _puffs.is_empty():
		for p: Dictionary in _puffs:
			p["life"] = float(p["life"]) + delta
			p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
			p["rad"] = float(p["rad"]) + delta * 14.0
		_puffs = _puffs.filter(func(p: Dictionary) -> bool: return float(p["life"]) < float(p["max"]))
		if is_instance_valid(_dust_layer):
			_dust_layer.queue_redraw()


func _draw_dust() -> void:
	if not is_instance_valid(_dust_layer):
		return
	for p: Dictionary in _puffs:
		var k: float = float(p["life"]) / float(p["max"])
		var col := Color(0.84, 0.80, 0.72, 0.42 * (1.0 - k))
		var r: float = roundf(float(p["rad"]))
		var pos: Vector2 = (p["pos"] as Vector2).round()
		_dust_layer.draw_rect(Rect2(pos - Vector2(r, r * 0.7), Vector2(r * 2.0, r * 1.4)), col)


func _make_label(txt: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override(&"font", FONT)
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", col)
	return l


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
		var res: Resource = load(res_path)
		if res is Texture2D:
			return res
	var abs_path := ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img:
			return ImageTexture.create_from_image(img)
	return null
