extends Node2D
## Vòi nước ngoài vườn rau (map garden):
## - Trước khi sửa (chưa có cờ "ch1.pipe_fixed"): vòi nước nứt khớp nối + tia nước phun bắn lên.
## - Sau khi sửa xong ("ch1.pipe_fixed" = true): vòi nước đã lắp kẹp sửa kín, hết rỉ nước.
## - Sau khi An rơi xuống đè vỡ ("ch1.pipe_burst_by_an" = true và chưa có "ch1.pipe_fixed_after_an"):
##   vòi nước vỡ tung mạnh hơn trước, rung lắc áp lực và phun cột nước cao tung tóe gấp nhiều lần!

const TEX_BROKEN_PATH := "res://assets/objects/garden_faucet_broken.png"
const TEX_FIXED_PATH := "res://assets/objects/garden_faucet_fixed.png"
const DIALOGUE_PATH := "res://data/dialogues/ch1_pipe_intro.dialogue"
const HIGHLIGHT_SHADER := preload("res://world/effects/interact_highlight.gdshader")

const FLAG_PIPE_FIXED := "ch1.pipe_fixed"
const FLAG_PIPE_BURST := "ch1.pipe_burst_by_an"
const FLAG_PIPE_FIXED_AFTER_AN := "ch1.pipe_fixed_after_an"
## Vị trí vết nứt (tọa độ local so với chân bệ vòi nước ở (0, 0))
const LEAK_ORIGIN := Vector2(0.0, -24.0)
const SPRITE_BASE_POS := Vector2(-19.0, -60.0)

var _sprite: Sprite2D
var _highlight_mat: ShaderMaterial
var _highlight_val: float = 0.0
var _player: Player = null
var _tex_broken: Texture2D
var _tex_fixed: Texture2D
var _interactable: Interactable
var _is_leaking: bool = true
var _is_burst: bool = false
var _time: float = 0.0
var _spawn_acc: float = 0.0
var _drops: Array[Dictionary] = []
var _splashes: Array[Dictionary] = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -2 # Nằm trên đất vườn & luống rau (z -10), phía sau Player (z 0) và hàng rào tiền cảnh (z 50)

	_tex_broken = _load_png(TEX_BROKEN_PATH)
	_tex_fixed = _load_png(TEX_FIXED_PATH)

	_sprite = Sprite2D.new()
	_sprite.name = "FaucetSprite"
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = false
	_sprite.position = SPRITE_BASE_POS
	_highlight_mat = ShaderMaterial.new()
	_highlight_mat.shader = HIGHLIGHT_SHADER
	_highlight_mat.set_shader_parameter(&"highlight", 0.0)
	_highlight_mat.set_shader_parameter(&"outline_color", Color(1.0, 0.93, 0.56, 1.0))
	_sprite.material = _highlight_mat
	add_child(_sprite)

	_setup_interactable()
	GameState.changed.connect(_refresh_state)
	_refresh_state()

	# Khởi tạo sẵn vài giọt nước đang bay để vừa bước vào map là thấy nước đang phun ngay
	if _is_leaking:
		var pre_count: int = 40 if _is_burst else 18
		for i: int in range(pre_count):
			_spawn_drop(true)

	await get_tree().process_frame
	if is_inside_tree():
		_player = get_tree().get_first_node_in_group(&"player") as Player


func trigger_burst_explosion() -> void:
	## Gọi trực tiếp từ cutscene An rơi xuống để bùng nổ tia nước ngay tức khắc.
	GameState.set_flag(FLAG_PIPE_BURST, true)
	for i: int in range(36):
		_spawn_drop(false)
	queue_redraw()


func _setup_interactable() -> void:
	_interactable = Interactable.new()
	_interactable.name = "Interactable"
	_interactable.prompt_text = "Xem vòi nước"
	_interactable.prompt_offset = Vector2(0.0, -70.0)
	_interactable.position = Vector2(0.0, -24.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(56.0, 74.0)
	shape.shape = rect
	_interactable.add_child(shape)
	_interactable.interacted.connect(_on_interacted)
	add_child(_interactable)


func _refresh_state() -> void:
	var burst_now: bool = GameState.has_flag(FLAG_PIPE_BURST) and not GameState.has_flag(FLAG_PIPE_FIXED_AFTER_AN)
	var fixed_first: bool = GameState.has_flag(FLAG_PIPE_FIXED)
	_is_burst = burst_now
	_is_leaking = burst_now or not fixed_first

	if _sprite:
		_sprite.texture = _tex_broken if _is_leaking else _tex_fixed
		if not _is_burst:
			_sprite.position = SPRITE_BASE_POS
	if _interactable:
		if _can_repair_now():
			_interactable.prompt_text = "Sửa vòi nước"
		else:
			_interactable.prompt_text = "Xem vòi nước"
	if not _is_leaking:
		_drops.clear()
		_splashes.clear()
	queue_redraw()


func _can_repair_now() -> bool:
	return _is_leaking and not _is_burst and GameState.count_pipe_parts_missing() == 0


func _process(delta: float) -> void:
	_time += delta

	# Sáng viền nhẹ khi đang tới gần hoặc đang ở bước cần kiểm tra / đủ đồ sửa vòi nước
	if _highlight_mat:
		var want: float = 0.0
		var need_action: bool = (GameState.is_quest_active("fix_pipe") and not GameState.has_flag("ch1.inspected_faucet")) or _can_repair_now()
		if _player and _player.can_move and absf(_player.global_position.x - global_position.x) <= 68.0:
			want = 1.0 if need_action else 0.55
		elif need_action:
			want = 0.35 + 0.15 * sin(_time * 4.0)
		_highlight_val = lerpf(_highlight_val, want, clampf(delta * 8.0, 0.0, 1.0))
		_highlight_mat.set_shader_parameter(&"highlight", _highlight_val)

	if not _is_leaking:
		return

	# Khi bị vỡ tung lần 2: thân vòi rung nhẹ liên tục vì áp lực nước quá mạnh
	if _sprite:
		if _is_burst:
			var jx: float = roundf(sin(_time * 52.0) * 1.0)
			_sprite.position = SPRITE_BASE_POS + Vector2(jx, 0.0)
		else:
			_sprite.position = SPRITE_BASE_POS

	var spawn_step: float = 0.011 if _is_burst else 0.032
	_spawn_acc += delta
	while _spawn_acc >= spawn_step:
		_spawn_acc -= spawn_step
		_spawn_drop(false)

	var gravity: float = 235.0 if _is_burst else 210.0
	var kept_drops: Array[Dictionary] = []
	for d: Dictionary in _drops:
		var pos: Vector2 = d["pos"]
		var vel: Vector2 = d["vel"]
		var life: float = float(d["life"]) + delta
		var max_life: float = float(d["max_life"])
		vel.y += gravity * delta
		pos += vel * delta
		d["pos"] = pos
		d["vel"] = vel
		d["life"] = life

		var ground_y: float = float(d["ground_y"])
		if pos.y >= ground_y:
			_splashes.append({
				"pos": Vector2(pos.x, ground_y),
				"life": 0.0,
				"max_life": randf_range(0.20, 0.36) if _is_burst else randf_range(0.18, 0.30),
				"big": _is_burst,
			})
		elif life < max_life:
			kept_drops.append(d)
	_drops = kept_drops

	var kept_splashes: Array[Dictionary] = []
	for s: Dictionary in _splashes:
		var sl: float = float(s["life"]) + delta
		s["life"] = sl
		if sl < float(s["max_life"]):
			kept_splashes.append(s)
	_splashes = kept_splashes

	queue_redraw()


func _spawn_drop(prewarm: bool) -> void:
	var roll: float = randf()
	var vx: float
	var vy: float
	var grav: float = 235.0 if _is_burst else 210.0

	if _is_burst:
		# Vỡ tung lần 2: phun cực mạnh, vọt cao và văng rộng cả hai bên!
		if roll < 0.24:
			vx = randf_range(-110.0, -48.0)
			vy = randf_range(-195.0, -135.0)
		elif roll < 0.48:
			vx = randf_range(-46.0, -8.0)
			vy = randf_range(-230.0, -172.0)
		elif roll < 0.66:
			vx = randf_range(-12.0, 14.0)
			vy = randf_range(-248.0, -195.0)
		elif roll < 0.84:
			vx = randf_range(12.0, 58.0)
			vy = randf_range(-225.0, -165.0)
		else:
			vx = randf_range(55.0, 120.0)
			vy = randf_range(-192.0, -132.0)
	else:
		# Rỉ nước ban đầu
		if roll < 0.32:
			vx = randf_range(-44.0, -14.0)
			vy = randf_range(-132.0, -96.0)
		elif roll < 0.62:
			vx = randf_range(-12.0, 14.0)
			vy = randf_range(-154.0, -118.0)
		else:
			vx = randf_range(16.0, 52.0)
			vy = randf_range(-138.0, -94.0)

	var pos: Vector2 = LEAK_ORIGIN + Vector2(randf_range(-3.5, 3.5), randf_range(-2.0, 1.0))
	var vel: Vector2 = Vector2(vx, vy)
	var ground_y: float = randf_range(-2.0, 10.0) if _is_burst else randf_range(-1.0, 6.0)
	var life: float = 0.0

	if prewarm:
		var step: float = randf_range(0.05, 0.85 if _is_burst else 0.65)
		pos.x += vel.x * step
		pos.y += vel.y * step + 0.5 * grav * step * step
		vel.y += grav * step
		life = step
		if pos.y >= ground_y:
			return

	_drops.append({
		"pos": pos,
		"vel": vel,
		"life": life,
		"max_life": randf_range(0.95, 1.55) if _is_burst else randf_range(0.75, 1.15),
		"ground_y": ground_y,
		"size": (3.0 if randf() < 0.28 else 2.0) if _is_burst else (2.0 if randf() < 0.55 else 1.0),
		"bright": randf() < 0.50,
	})


func _draw() -> void:
	if not _is_leaking:
		return

	var col_puddle_dk := Color(0.24, 0.35, 0.46, 0.50 if _is_burst else 0.42)
	var col_puddle_hi := Color(0.58, 0.88, 1.0, 0.60 if _is_burst else 0.48)
	var col_blue := Color(0.14, 0.56, 0.94, 0.98)
	var col_cyan := Color(0.48, 0.88, 1.0, 0.98)
	var col_white := Color(0.94, 0.99, 1.0, 1.0)

	# 1. Vũng nước thấm ướt trên nền đất quanh chân ống (rộng gấp đôi khi vỡ tung lần 2)
	if _is_burst:
		draw_rect(Rect2(Vector2(-64.0, -2.0), Vector2(128.0, 10.0)), col_puddle_dk)
		draw_rect(Rect2(Vector2(-46.0, 0.0), Vector2(92.0, 6.0)), col_puddle_dk)
		var rw1: float = 18.0 + roundf(sin(_time * 10.0) * 6.0)
		draw_rect(Rect2(Vector2(-32.0 - rw1 * 0.5, 1.0).round(), Vector2(rw1, 2.0)), col_puddle_hi)
		var rw2: float = 16.0 + roundf(cos(_time * 9.0) * 5.0)
		draw_rect(Rect2(Vector2(24.0 - rw2 * 0.5, 3.0).round(), Vector2(rw2, 2.0)), col_puddle_hi)
		draw_rect(Rect2(Vector2(-8.0, 5.0), Vector2(18.0, 1.0)), col_white)
	else:
		draw_rect(Rect2(Vector2(-24.0, -1.0), Vector2(46.0, 6.0)), col_puddle_dk)
		draw_rect(Rect2(Vector2(-18.0, 0.0), Vector2(34.0, 4.0)), col_puddle_dk)
		var ripple_w: float = 10.0 + roundf(sin(_time * 7.5) * 4.0)
		draw_rect(Rect2(Vector2(-ripple_w * 0.5, 1.0).round(), Vector2(ripple_w, 1.0)), col_puddle_hi)
		var ripple2_x: float = 8.0 + roundf(cos(_time * 6.0) * 3.0)
		draw_rect(Rect2(Vector2(ripple2_x, 2.0), Vector2(6.0, 1.0)), col_puddle_hi)

	# 2. Cột nước áp lực phun vọt lên từ khe nứt ống
	if _is_burst:
		var p1: float = 54.0 + sin(_time * 24.0) * 7.0
		var p2: float = 72.0 + cos(_time * 28.0 + 0.6) * 9.0
		var p3: float = 84.0 + sin(_time * 26.0 + 1.4) * 10.0
		var p4: float = 70.0 + cos(_time * 22.0 + 2.2) * 8.0
		var p5: float = 56.0 + sin(_time * 25.0 + 3.0) * 7.0

		_draw_pixel_jet(LEAK_ORIGIN + Vector2(-4.0, 0.0), -46.0, p1, col_blue, col_cyan, col_white, 20, true)
		_draw_pixel_jet(LEAK_ORIGIN + Vector2(-2.0, -1.0), -22.0, p2, col_blue, col_cyan, col_white, 24, true)
		_draw_pixel_jet(LEAK_ORIGIN + Vector2(0.0, -2.0), 2.0, p3, col_blue, col_cyan, col_white, 28, true)
		_draw_pixel_jet(LEAK_ORIGIN + Vector2(2.0, -1.0), 28.0, p4, col_blue, col_cyan, col_white, 24, true)
		_draw_pixel_jet(LEAK_ORIGIN + Vector2(4.0, 0.0), 50.0, p5, col_blue, col_cyan, col_white, 20, true)

		# Bọt nước trắng trào mạnh ngay miệng ống vỡ
		var fw: float = 12.0 + roundf(sin(_time * 30.0) * 3.0)
		draw_rect(Rect2(Vector2(LEAK_ORIGIN.x - fw * 0.5, LEAK_ORIGIN.y - 4.0).round(), Vector2(fw, 6.0)), col_cyan)
		draw_rect(Rect2(Vector2(LEAK_ORIGIN.x - 4.0, LEAK_ORIGIN.y - 3.0), Vector2(8.0, 4.0)), col_white)
	else:
		var pulse_l: float = 28.0 + sin(_time * 18.0) * 4.5
		var pulse_c: float = 38.0 + cos(_time * 22.0 + 0.8) * 5.5
		var pulse_r: float = 32.0 + sin(_time * 16.0 + 1.9) * 5.0

		_draw_pixel_jet(LEAK_ORIGIN + Vector2(-2.0, 0.0), -14.0, pulse_l, col_blue, col_cyan, col_white, 14, false)
		_draw_pixel_jet(LEAK_ORIGIN + Vector2(0.0, -1.0), 2.0, pulse_c, col_blue, col_cyan, col_white, 18, false)
		_draw_pixel_jet(LEAK_ORIGIN + Vector2(2.0, 0.0), 19.0, pulse_r, col_blue, col_cyan, col_white, 16, false)

		var foam_w: float = 6.0 + roundf(sin(_time * 24.0) * 2.0)
		draw_rect(Rect2(Vector2(LEAK_ORIGIN.x - foam_w * 0.5, LEAK_ORIGIN.y - 2.0).round(), Vector2(foam_w, 3.0)), col_cyan)
		draw_rect(Rect2(Vector2(LEAK_ORIGIN.x - 2.0, LEAK_ORIGIN.y - 1.0), Vector2(4.0, 2.0)), col_white)

	# 3. Các giọt nước bắn tung lên và rơi theo đường parabol
	for d: Dictionary in _drops:
		var p: Vector2 = (d["pos"] as Vector2).round()
		var sz: float = float(d["size"])
		var bright: bool = bool(d["bright"])
		if sz >= 3.0:
			draw_rect(Rect2(p, Vector2(3.0, 3.0)), col_blue)
			draw_rect(Rect2(p, Vector2(2.0, 2.0)), col_cyan)
			draw_rect(Rect2(p, Vector2(1.0, 1.0)), col_white)
		elif sz >= 2.0:
			draw_rect(Rect2(p, Vector2(2.0, 2.0)), col_blue)
			draw_rect(Rect2(p, Vector2(1.0, 1.0)), col_white if bright else col_cyan)
		else:
			draw_rect(Rect2(p, Vector2(1.0, 2.0)), col_white if bright else col_cyan)

	# 4. Bọt nước bắn tung khi giọt rơi xuống đất
	for s: Dictionary in _splashes:
		var sp: Vector2 = (s["pos"] as Vector2).round()
		var k: float = float(s["life"]) / float(s["max_life"])
		var is_big: bool = bool(s.get("big", false))
		var spread: float = roundf(1.0 + k * (8.0 if is_big else 5.0))
		var alpha: float = clampf(1.0 - k, 0.0, 1.0)
		var sc := Color(0.76, 0.95, 1.0, alpha)
		var dot_sz: float = 2.0 if is_big else 1.0
		draw_rect(Rect2(sp + Vector2(-spread, -1.0), Vector2(dot_sz, 1.0)), sc)
		draw_rect(Rect2(sp + Vector2(spread, -1.0), Vector2(dot_sz, 1.0)), sc)
		if k < 0.55:
			draw_rect(Rect2(sp + Vector2(0.0, -3.0 if is_big else -2.0), Vector2(2.0, 1.0)), Color(0.95, 1.0, 1.0, alpha))


func _draw_pixel_jet(origin: Vector2, drift_x: float, peak_h: float, col_blue: Color, col_cyan: Color, col_white: Color, steps: int, thick: bool) -> void:
	for i: int in range(steps):
		var t: float = float(i) / float(steps)
		var wobble: float = sin(_time * 24.0 - t * 8.0) * (1.8 if thick else 1.2) * t
		var px: float = roundf(origin.x + drift_x * t + wobble)
		var py: float = roundf(origin.y - sin(t * PI * 0.72) * peak_h)
		var w: float = (5.0 if t < 0.35 else 3.0) if thick else (3.0 if t < 0.35 else 2.0)
		var h: float = 3.0 if thick else 2.0
		draw_rect(Rect2(Vector2(px - 1.0, py), Vector2(w, h)), col_blue)
		draw_rect(Rect2(Vector2(px, py), Vector2(maxf(1.0, w - 2.0 if thick else w - 1.0), h)), col_cyan)
		if i % 3 == int(floor(_time * 18.0)) % 3:
			draw_rect(Rect2(Vector2(px, py), Vector2(2.0 if thick else 1.0, 1.0)), col_white)


func _on_interacted(_player_node: Node) -> void:
	# Đã tìm đủ 3 vật dụng sửa ống lần đầu → mở thẳng minigame sửa ống nước ngay tại vòi!
	if _can_repair_now():
		if not MinigameManager.is_running():
			MinigameManager.start("fix_pipe")
		return

	var dlg := _load_dialogue()
	if dlg == null:
		return
	var cue: String
	if _is_burst:
		cue = "faucet_burst_after_an"
	elif not _is_leaking:
		cue = "faucet_fixed"
	elif not GameState.is_quest_active("fix_pipe"):
		cue = "faucet_broken_before_quest"
	elif not GameState.has_flag("ch1.inspected_faucet"):
		cue = "faucet_inspect"
	elif not GameState.has_flag("ch1.asked_ong_tools"):
		cue = "faucet_after_inspect"
	else:
		cue = "faucet_after_asked"
	DialogueManager.show_dialogue_balloon(dlg, cue)


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
