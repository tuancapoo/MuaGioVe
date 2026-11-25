class_name MelonCarryCutscene
extends CanvasLayer
## Cutscene màn hình đen sau khi hái hết dưa hấu ở Ruộng dưa:
## Quả dưa siêu to khổng lồ (lấy trực tiếp từ sprite DuaHau4 trong map) lăn tròn băng qua màn hình!

signal finished

const MELON_TEX_PATH := "res://assets/objects/dua_hau.png"
const FONT := preload("res://assets/fonts/vt323_regular.ttf")

# Giống tỉ lệ DuaHau4 trong ruong_dua.tscn (7.39 x 10.59 -> stretch dọc ~1.43x thành quả dưa tròn!)
const STRETCH_Y := 1.43
const ROLL_SCALE := 13.5
const MELON_RADIUS := 12.0 * ROLL_SCALE # ~162 px bán kính hiển thị
const ROLL_SPEED := 520.0               # Tốc độ lăn nhanh gọn (~4.5s qua hết màn hình)

var _canvas: Control
var _melon_pivot: Node2D
var _melon_sprite: Sprite2D

var _t: float = 0.0
var _fade_alpha: float = 0.0
var _closing: bool = false
var _can_skip: bool = false
var _melon_x: float = -240.0
var _melon_angle: float = 0.0
var _fireflies: Array[Dictionary] = []
var _dusts: Array[Dictionary] = []
var _dust_timer: float = 0.05


func _ready() -> void:
	layer = 92

	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.draw.connect(_on_draw)
	add_child(_canvas)

	# Pivot xoay đồng đều -> quả dưa sau khi kéo tròn tỉ lệ DuaHau4 sẽ lăn tròn đều không bị méo!
	_melon_pivot = Node2D.new()
	_melon_pivot.scale = Vector2(ROLL_SCALE, ROLL_SCALE)
	_melon_pivot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_melon_pivot)

	_melon_sprite = Sprite2D.new()
	_melon_sprite.texture = _build_clean_melon_texture()
	_melon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_melon_sprite.scale = Vector2(1.0, STRETCH_Y)
	# Tâm phần thân quả dưa nằm ở (13.5, 10.5) trong ảnh 28x20 -> chỉnh offset để xoay đúng tâm quả dưa!
	_melon_sprite.offset = Vector2(0.5, -0.5)
	_melon_pivot.add_child(_melon_sprite)

	# Khởi tạo vài con đom đóm vàng dịu bay trong màn đêm
	for i: int in range(20):
		_fireflies.append({
			"pos": Vector2(randf_range(80.0, 1840.0), randf_range(160.0, 860.0)),
			"phase": randf_range(0.0, TAU),
			"spd": randf_range(22.0, 48.0),
			"drift": randf_range(1.0, 2.4),
		})

	_melon_x = -240.0
	_update_melon_transform()

	var tw_in := create_tween()
	tw_in.tween_property(self, "_fade_alpha", 1.0, 0.35)


func _build_clean_melon_texture() -> Texture2D:
	var src_tex: Texture2D = load(MELON_TEX_PATH) as Texture2D
	if src_tex == null:
		return null
	var img: Image = src_tex.get_image()
	if img == null:
		return src_tex
	img = img.duplicate() as Image
	# Xóa dòng bóng đáy (y = 19) của dua_hau.png để khi quả dưa lăn tròn không bị vệt bóng quay theo!
	var w: int = img.get_width()
	var h: int = img.get_height()
	if h >= 20:
		for x: int in range(w):
			img.set_pixel(x, h - 1, Color(0.0, 0.0, 0.0, 0.0))
	return ImageTexture.create_from_image(img)


func _update_melon_transform() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var ground_y: float = vp.y * 0.5 + 150.0
	# Nhún rất nhẹ theo mỗi vòng lăn cho vui mắt
	var bounce: float = absf(sin(_melon_angle * 2.0)) * 7.0
	_melon_pivot.position = Vector2(_melon_x, ground_y - MELON_RADIUS + 8.0 - bounce)
	_melon_pivot.rotation = _melon_angle
	_melon_pivot.modulate = Color(1.0, 1.0, 1.0, _fade_alpha)


func _process(delta: float) -> void:
	_t += delta
	if _t >= 0.8:
		_can_skip = true

	# Quả dưa lăn tròn từ trái sang phải đúng vật lý (v = omega * R)
	_melon_x += ROLL_SPEED * delta
	_melon_angle += (ROLL_SPEED / MELON_RADIUS) * delta
	_update_melon_transform()

	# Tự kết thúc mượt sau khi quả dưa lăn qua hết cạnh phải
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if _melon_x > vp.x + 260.0 and not _closing:
		_end_cutscene()

	# Bụi pixel nhỏ tung ra phía sau điểm tiếp đất khi quả dưa siêu to lăn qua
	var ground_y: float = vp.y * 0.5 + 150.0
	_dust_timer -= delta
	if _dust_timer <= 0.0 and _melon_x > -80.0 and _melon_x < vp.x + 80.0:
		_dust_timer = randf_range(0.06, 0.12)
		_dusts.append({
			"pos": Vector2(_melon_x - randf_range(24.0, 72.0), ground_y - randf_range(2.0, 10.0)),
			"vel": Vector2(randf_range(-130.0, -45.0), randf_range(-65.0, -18.0)),
			"size": randf_range(8.0, 16.0),
			"life": 0.0,
			"max_life": randf_range(0.32, 0.52),
		})

	var kept_dusts: Array[Dictionary] = []
	for d: Dictionary in _dusts:
		var life: float = float(d["life"]) + delta
		d["life"] = life
		if life < float(d["max_life"]):
			var pos: Vector2 = d["pos"]
			var vel: Vector2 = d["vel"]
			vel.y += 140.0 * delta
			pos += vel * delta
			d["pos"] = pos
			d["vel"] = vel
			kept_dusts.append(d)
	_dusts = kept_dusts

	for ff: Dictionary in _fireflies:
		var pos: Vector2 = ff["pos"]
		var phase: float = float(ff["phase"]) + delta * float(ff["drift"])
		ff["phase"] = phase
		pos.x -= float(ff["spd"]) * delta
		pos.y += sin(phase) * 14.0 * delta
		if pos.x < -20.0:
			pos.x = vp.x + 20.0
		ff["pos"] = pos

	if is_instance_valid(_canvas):
		_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if _closing or not _can_skip:
		return
	var clicked: bool = event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	var pressed_next: bool = event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept")
	if clicked or pressed_next:
		get_viewport().set_input_as_handled()
		_end_cutscene()


func _end_cutscene() -> void:
	if _closing:
		return
	_closing = true
	var tw := create_tween()
	tw.tween_property(self, "_fade_alpha", 0.0, 0.35)
	await tw.finished
	finished.emit()
	queue_free()


func _on_draw() -> void:
	var vp: Vector2 = _canvas.size
	_canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.015, 0.015, 0.025, _fade_alpha))
	if _fade_alpha <= 0.02:
		return

	var ground_y: float = vp.y * 0.5 + 150.0

	# Đom đóm bay nhẹ trên màn hình đen
	for ff: Dictionary in _fireflies:
		var pos: Vector2 = (ff["pos"] as Vector2).round()
		var blink: float = 0.25 + 0.75 * (0.5 + 0.5 * sin(float(ff["phase"]) * 2.2))
		var a: float = blink * 0.72 * _fade_alpha
		_canvas.draw_rect(Rect2(pos - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), Color(0.95, 0.90, 0.45, a * 0.35))
		_canvas.draw_rect(Rect2(pos - Vector2(1.0, 1.0), Vector2(3.0, 3.0)), Color(1.0, 0.96, 0.62, a))

	# Đường mặt đất mờ + bóng quả dưa lăn phía dưới
	_canvas.draw_rect(Rect2(Vector2(0.0, ground_y), Vector2(vp.x, 4.0)), Color(0.14, 0.16, 0.22, 0.45 * _fade_alpha))
	var shadow_w: float = 240.0
	_canvas.draw_rect(Rect2(Vector2(_melon_x - shadow_w * 0.5, ground_y - 4.0), Vector2(shadow_w, 12.0)), Color(0.0, 0.0, 0.0, 0.65 * _fade_alpha))

	# Vẽ hạt bụi pixel tung ra phía sau quả dưa
	for d: Dictionary in _dusts:
		var k: float = float(d["life"]) / float(d["max_life"])
		var sz: float = float(d["size"]) * (1.0 - k * 0.5)
		var p: Vector2 = (d["pos"] as Vector2).round()
		var a: float = (1.0 - k) * 0.65 * _fade_alpha
		_canvas.draw_rect(Rect2(p - Vector2(sz * 0.5, sz * 0.5), Vector2(sz, sz)), Color(0.76, 0.74, 0.64, a))

	if _can_skip:
		var skip_txt: String = "[E] Tiếp tục"
		var sw2: float = FONT.get_string_size(skip_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
		var sa: float = (0.55 + 0.35 * sin(_t * 4.0)) * _fade_alpha
		_canvas.draw_string(FONT, Vector2((vp.x - sw2) * 0.5, vp.y - 54.0), skip_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0.70, 0.78, 0.94, sa))
