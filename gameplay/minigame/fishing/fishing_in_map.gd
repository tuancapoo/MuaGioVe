extends Node2D
## Câu cá NGAY TRÊN MAP bờ mương (không mở scene riêng).
## MinigameSpot (play_in_map = true) tạo node này khi Minh bấm E vào cần câu; cất cần thì node tự xoá.
##
## Cách chơi (giữ cơ chế của minigame câu cá gốc — fishing.gd):
##   0. Minh ngồi xuống ghế đá cạnh cần câu. A/D (di chuyển) = đứng dậy, huỷ câu.
##   1. Cá ẩn dưới nước, chỉ thấy bong bóng sủi lên chỗ cá. Rê chuột trên mặt nước để chọn chỗ thả
##      (click để thả), hoặc W/S dời phao sang điểm kế bên rồi bấm E.
##   2. E: thả phao. Thả trúng chỗ cá → cá rỉa mồi (phao nhúng nhẹ) → phao giật mạnh + "!" → bấm E ngay.
##      Bấm sớm hoặc trễ thì cá chạy. Thả trượt → E để thu phao.
##   3. Kéo cá: GIỮ E để nâng thanh xanh giữ lấy con cá trong cột; đầy tiến độ là câu được.
##   4. Câu được → cá vào túi đồ (hiện "Đã nhận: Cá đồng"), câu tiếp. A/D hoặc Esc: thôi câu.
## Lần đầu câu: bạn đồng hành (An) giải thích từng bước bằng hội thoại và cầm cần câu mẫu 1 con
## (cờ "fishing.tutorial_done" bật sau khi xem xong).

signal closed

enum State { AIM, CAST_EMPTY, WAITING_BITE, BITE_WINDOW, REELING, FEEDBACK }

const FISH_ITEM := "fish"
const FONT := preload("res://assets/fonts/vt323_regular.ttf")
const SFX := {
	"cast": "res://assets/audio/sfx/fishing/cast.wav",
	"nibble": "res://assets/audio/sfx/fishing/nibble.wav",
	"bite": "res://assets/audio/sfx/fishing/bite.wav",
	"catch": "res://assets/audio/sfx/fishing/catch.wav",
	"miss": "res://assets/audio/sfx/fishing/miss.wav",
	"tick": "res://assets/audio/sfx/fishing/reel_tick.wav",
}
const FISH_ICON_PATH := "res://assets/items/fish.png"

## Điểm có cá (so với chỗ đứng câu, toạ độ map). 3 gần (0..2) + 2 xa (3..4)
@export var fish_spots: Array[Vector2] = [
	Vector2(-150, 46), Vector2(-60, 70), Vector2(60, 50), Vector2(170, 66), Vector2(260, 84)]
## Vùng mặt nước được thả phao (so với chỗ đứng câu)
@export var water_rect: Rect2 = Rect2(-300, 34, 620, 62)
## Khi ngồi: hạ hình nhân vật xuống cho chân chạm đất (ngồi trên ghế đá)
@export var sit_drop: float = 15.0

# Thanh kéo cá (giống bản gốc: 0 đáy … 1 đỉnh)
const BAR_HEIGHT := 0.30
const BAR_THRUST := 2.75
const BAR_GRAVITY := 1.95
const BAR_MAX_VEL := 1.45
const BAR_BOUNCE := 0.32
const FISH_RADIUS := 0.045
const GAIN_RATE := 0.28
const DRAIN_RATES := [0.12, 0.15, 0.18]

var player: Player
var state: State = State.AIM
var caught: int = 0              # số cá câu được lượt này (để tăng độ khó)
var aim: Vector2
var bobber: Vector2
var fish_idx := 0
var fish_pos: Vector2
var fish_goal: Vector2
var fish_timer := 0.0
var bubble_timer := 0.0
var wait_t := 0.0
var wait_dur := 1.4
var next_nibble := 0.6
var nibble_dip := 0.0
var bite_t := 0.0
var feedback_t := 0.0
var cast_t := 1.0
var reel_bar := 0.2
var reel_vel := 0.0
var reel_fish := 0.35
var reel_fish_goal := 0.55
var reel_fish_wait := 0.4
var reel_progress := 0.3
var tick_t := 0.0
var t := 0.0
var _bubbles: Array = []
var _ripples: Array = []
var _rng := RandomNumberGenerator.new()
var _sfx: AudioStreamPlayer
var _ui: CanvasLayer
var _hint: Label
var _gauge: Control
var _alert := ""
var _aim_idx := 0
var _mouse_aim := false      # đang ngắm bằng chuột (bỏ hút về điểm câu)
var _mouse_held := false     # giữ chuột trái khi kéo cá
var _demo := false           # bạn đồng hành đang câu mẫu (người chơi chỉ xem)
var _talking := false        # đang hiện hội thoại → tạm dừng mọi thứ
var _demo_aim_target := Vector2.ZERO

const TUTORIAL_FLAG := "fishing.tutorial_done"


func start(p: Player) -> void:
	player = p
	_rng.randomize()
	z_index = 30
	player.can_move = false
	player.velocity = Vector2.ZERO
	player.global_position.x = global_position.x
	player.anim.flip_h = false
	player.sit_drop = sit_drop
	player.set_pose(Player.POSE_SIT)
	_sfx = AudioStreamPlayer.new()
	_sfx.volume_db = -6.0
	add_child(_sfx)
	_build_ui()
	_spawn_fish()
	_aim_idx = 0
	aim = _spot(_ordered()[0])
	_set_hint("Canh chỗ bong bóng sủi lên · Chuột / W,S chọn chỗ · Click / E thả câu · A/D đứng dậy")
	if not GameState.has_flag(TUTORIAL_FLAG) and _buddy() != null:
		_run_tutorial()


func stage() -> int:
	return 1 if caught < 2 else (2 if caught < 4 else 3)


func _spot(i: int) -> Vector2:
	return global_position + fish_spots[i]


func _water() -> Rect2:
	return Rect2(global_position + water_rect.position, water_rect.size)


func _clamp_water(p: Vector2) -> Vector2:
	var r := _water()
	return Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))


func _hit_radius() -> float:
	return 46.0 if stage() <= 2 else 36.0


func _bite_window() -> float:
	return [1.0, 0.8, 0.7][stage() - 1]


# --- Cá ---------------------------------------------------------------------------------

func _spawn_fish() -> void:
	var c: Array = [0, 1, 2] if stage() == 1 else ([0, 1, 2, 3, 4] if stage() == 2 else [3, 4])
	var next: int = c[_rng.randi_range(0, c.size() - 1)]
	if next == fish_idx and c.size() > 1:
		next = c[(c.find(next) + 1) % c.size()]
	fish_idx = next
	fish_goal = _spot(fish_idx)
	if fish_pos == Vector2.ZERO:
		fish_pos = fish_goal
	fish_timer = [7.5, 5.5, 3.8][stage() - 1]
	bubble_timer = 0.4


func _update_fish(delta: float) -> void:
	var speed: float = [34.0, 56.0, 96.0][stage() - 1]
	if state in [State.AIM, State.CAST_EMPTY]:
		fish_timer -= delta
		if fish_timer <= 0.0:
			_spawn_fish()
		var goal := fish_goal + Vector2(sin(t * 1.5) * 14.0, cos(t * 2.1) * 4.0)
		if state == State.CAST_EMPTY and fish_pos.distance_to(bobber) <= _hit_radius() * 1.15:
			goal = bobber
		fish_pos += (goal - fish_pos).limit_length(speed * delta)
		bubble_timer -= delta
		if bubble_timer <= 0.0:
			bubble_timer = _rng.randf_range(1.2, 2.2)
			_bubble_cluster(fish_pos, _rng.randi_range(2, 4))
	elif state == State.WAITING_BITE:
		fish_pos += (bobber + Vector2(-8, 2) - fish_pos).limit_length(speed * 1.2 * delta)
		bubble_timer -= delta
		if bubble_timer <= 0.0:
			bubble_timer = _rng.randf_range(0.55, 0.95)
			_bubble_cluster(fish_pos, 2)


# --- Vòng lặp ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if player == null:
		return
	t += delta
	cast_t = minf(1.0, cast_t + delta * 4.5)
	nibble_dip = maxf(0.0, nibble_dip - delta)
	_update_particles(delta)

	if _talking:
		queue_redraw()
		return
	# Di chuyển (A/D, mũi tên trái/phải) = đứng dậy, thôi câu
	if not _demo and Input.get_axis(&"move_left", &"move_right") != 0.0:
		close()
		return
	if state == State.AIM and _demo:
		aim = aim.lerp(_demo_aim_target, clampf(delta * 3.0, 0.0, 1.0))
	elif state == State.AIM and not _mouse_aim:
		# Phao trượt mượt tới điểm đang chọn (W/S)
		aim = aim.lerp(_spot(_ordered()[_aim_idx]), clampf(delta * 12.0, 0.0, 1.0))
	_update_fish(delta)

	match state:
		State.CAST_EMPTY:
			wait_t += delta
			if fish_pos.distance_to(bobber) <= _hit_radius():
				_enter_waiting()
			elif wait_t >= 1.05:
				_set_hint("Chỗ này không có cá. Thu phao, thả chỗ bong bóng thử xem.")
				_back_to_aim()
		State.WAITING_BITE:
			wait_t += delta
			if wait_t >= next_nibble and wait_t < wait_dur:
				nibble_dip = 0.16
				next_nibble += _rng.randf_range(0.55, 0.85)
				_ripple(bobber, 0.65)
				_play("nibble")
			if wait_t >= wait_dur:
				state = State.BITE_WINDOW
				bite_t = 0.0
				_alert = "!"
				_ripple(bobber, 1.6)
				_play("bite")
				_set_hint("CÁ CẮN CÂU! Bấm E ngay!")
		State.BITE_WINDOW:
			bite_t += delta
			if bite_t > _bite_window():
				_miss("Trễ quá, cá nhả mồi lặn mất rồi…")
		State.REELING:
			_update_reel(delta)
		State.FEEDBACK:
			feedback_t -= delta
			if feedback_t <= 0.0:
				_back_to_aim()
	queue_redraw()
	_gauge.visible = state == State.REELING
	_gauge.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if player == null or _demo or _talking:
		return
	if event.is_action_pressed(&"cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close()
		return
	# --- Chuột: rê để ngắm trên mặt nước, click để thả / giật / thu phao, giữ để kéo cá
	if event is InputEventMouseMotion:
		if state == State.AIM:
			var wp := _mouse_world((event as InputEventMouseMotion).position)
			if _water().grow(18.0).has_point(wp):
				_mouse_aim = true
				aim = _clamp_water(wp)
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			_mouse_held = false
			return
		get_viewport().set_input_as_handled()
		if state == State.AIM:
			var wp := _mouse_world(mb.position)
			if _water().grow(18.0).has_point(wp):
				aim = _clamp_water(wp)
			_cast()
		elif state == State.REELING:
			_mouse_held = true
		else:
			_primary()
			if state == State.REELING:
				_mouse_held = true
		return
	if state == State.AIM and (event.is_action_pressed(&"move_up") or event.is_action_pressed(&"move_down")):
		get_viewport().set_input_as_handled()
		var n := fish_spots.size()
		if _mouse_aim:
			# chuyển từ chuột sang phím: bắt đầu từ điểm câu gần chỗ đang ngắm
			_mouse_aim = false
			_aim_idx = _ordered().find(fish_spots.find(_nearest_spot(aim) - global_position))
		_aim_idx = clampi(_aim_idx + (1 if event.is_action_pressed(&"move_down") else -1), 0, n - 1)
		return
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		_primary()


## E / click: thả phao, thu phao, giật cần tuỳ lúc
func _primary() -> void:
	match state:
		State.AIM:
			_cast()
		State.CAST_EMPTY:
			_back_to_aim()
		State.WAITING_BITE:
			_miss("Sớm quá! Cá giật mình chạy mất…")
		State.BITE_WINDOW:
			_enter_reel()


## Vị trí chuột trên màn hình → toạ độ map
func _mouse_world(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos


func _cast() -> void:
	bobber = aim
	cast_t = 0.0
	_play("cast")
	_ripple(bobber, 1.1)
	if bobber.distance_to(fish_pos) <= _hit_radius() or bobber.distance_to(fish_goal) <= _hit_radius():
		_enter_waiting()
	else:
		state = State.CAST_EMPTY
		wait_t = 0.0
		_set_hint("Thả phao rồi… đợi chút xem có cá lại không. (E: thu phao)")


func _enter_waiting() -> void:
	state = State.WAITING_BITE
	wait_t = 0.0
	wait_dur = _rng.randf_range(0.95, 1.95)
	next_nibble = minf(wait_dur * 0.48, 0.7)
	_set_hint("Suỵt… cá đang rỉa mồi, đợi phao giật mạnh hãy kéo!")


func _enter_reel() -> void:
	state = State.REELING
	_alert = ""
	reel_fish = 0.35
	reel_fish_goal = _pick_reel_goal()
	reel_fish_wait = 0.35
	reel_bar = clampf(reel_fish - BAR_HEIGHT * 0.5, 0.0, 1.0 - BAR_HEIGHT)
	reel_vel = 0.0
	reel_progress = 0.3
	_ripple(bobber, 1.3)
	_set_hint("Dính câu rồi! GIỮ E (hoặc giữ chuột) để thanh xanh giữ lấy con cá!")


func _pick_reel_goal() -> float:
	var s := stage()
	var lo: float = [0.14, 0.09, 0.06][s - 1]
	var hi: float = [0.84, 0.90, 0.94][s - 1]
	var jump: float = [0.36, 0.50, 0.66][s - 1]
	return clampf(reel_fish + _rng.randf_range(-jump, jump), lo, hi)


func _update_reel(delta: float) -> void:
	var held := (_demo and reel_fish > reel_bar + BAR_HEIGHT * 0.5) or _mouse_held or Input.is_action_pressed(&"interact") or Input.is_action_pressed(&"move_up") or Input.is_action_pressed(&"ui_accept")
	reel_vel = clampf(reel_vel + (BAR_THRUST if held else -BAR_GRAVITY) * delta, -BAR_MAX_VEL, BAR_MAX_VEL)
	reel_bar += reel_vel * delta
	var top := 1.0 - BAR_HEIGHT
	if reel_bar <= 0.0:
		reel_bar = 0.0
		reel_vel = -reel_vel * BAR_BOUNCE if reel_vel < -0.35 else 0.0
	elif reel_bar >= top:
		reel_bar = top
		reel_vel = minf(reel_vel, 0.0)
	var s := stage()
	var speed: float = [0.40, 0.62, 0.86][s - 1]
	var d := reel_fish_goal - reel_fish
	if absf(d) > 0.015:
		reel_fish += signf(d) * minf(absf(d), speed * delta)
	else:
		reel_fish_wait -= delta
		if reel_fish_wait <= 0.0:
			reel_fish_goal = _pick_reel_goal()
			reel_fish_wait = _rng.randf_range(0.75, 1.35) if s == 1 else (_rng.randf_range(0.4, 0.9) if s == 2 else _rng.randf_range(0.2, 0.55))
	var inside := reel_fish >= reel_bar - FISH_RADIUS and reel_fish <= reel_bar + BAR_HEIGHT + FISH_RADIUS
	if inside:
		reel_progress = minf(1.0, reel_progress + GAIN_RATE * delta)
		tick_t -= delta
		if tick_t <= 0.0:
			tick_t = 0.14
			_play("tick")
	else:
		reel_progress = maxf(0.0, reel_progress - float(DRAIN_RATES[s - 1]) * delta)
	if reel_progress >= 1.0:
		_catch()
	elif reel_progress <= 0.0:
		_miss("Ôi! Cá vùng thoát mất rồi…")


func _catch() -> void:
	caught += 1
	_play("catch")
	_ripple(bobber, 1.4)
	GameState.add_item(FISH_ITEM, 1)   # hiện "Đã nhận: Cá đồng"
	_set_hint("Câu được rồi! (%d con lượt này) · E thả câu tiếp · A/D đứng dậy" % caught)
	state = State.FEEDBACK
	feedback_t = 0.8
	fish_pos = Vector2.ZERO
	_spawn_fish()


func _miss(msg: String) -> void:
	_alert = ""
	_play("miss")
	_ripple(bobber, 0.9)
	_set_hint(msg + " Thả lại nào.")
	state = State.FEEDBACK
	feedback_t = 0.8
	_spawn_fish()


func _back_to_aim() -> void:
	state = State.AIM
	_mouse_held = false
	_alert = ""
	cast_t = 1.0


func close() -> void:
	if player:
		player.set_pose(&"")
		player.can_move = true
	player = null
	closed.emit()
	queue_free()


# --- Hiệu ứng ---------------------------------------------------------------------------

## Các điểm câu xếp từ trái sang phải (W/S đi qua lại theo thứ tự này)
func _ordered() -> Array:
	var idx := range(fish_spots.size())
	idx.sort_custom(func(a, b): return fish_spots[a].x < fish_spots[b].x)
	return idx


func _nearest_spot(p: Vector2) -> Vector2:
	var best := _spot(0)
	for i in fish_spots.size():
		if _spot(i).distance_to(p) < best.distance_to(p):
			best = _spot(i)
	return best


func _bubble_cluster(p: Vector2, n: int) -> void:
	for i in n:
		_bubbles.append({"p": p + Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-2, 2)), "life": 0.0, "max": _rng.randf_range(0.7, 1.2), "delay": i * 0.12})


func _ripple(p: Vector2, s: float) -> void:
	_ripples.append({"p": p, "life": 0.0, "s": s})


func _update_particles(delta: float) -> void:
	for b in _bubbles:
		if b.delay > 0.0:
			b.delay -= delta
		else:
			b.life += delta
	_bubbles = _bubbles.filter(func(b): return b.life < b.max)
	for r in _ripples:
		r.life += delta
	_ripples = _ripples.filter(func(r): return r.life < 0.9)


func _play(key: String) -> void:
	if ResourceLoader.exists(SFX[key]):
		_sfx.stream = load(SFX[key])
		_sfx.play()


func _draw() -> void:
	var o := global_position
	# gợn sóng
	for r in _ripples:
		var k: float = r.life / 0.9
		var rad: float = (6.0 + 16.0 * k) * float(r.s)
		_ellipse_outline(r.p - o, Vector2(rad, rad * 0.32), Color(0.9, 0.97, 1.0, 0.6 * (1.0 - k)))
	# bong bóng chỗ cá
	for b in _bubbles:
		if b.delay > 0.0:
			continue
		var k: float = b.life / b.max
		var pp: Vector2 = b.p - o + Vector2(sin(b.life * 9.0) * 1.0, -k * 5.0)
		draw_rect(Rect2(pp.round(), Vector2(2, 2)), Color(0.92, 0.98, 1.0, 0.85 * (1.0 - k)))
	# điểm ngắm
	if state == State.AIM:
		var a := aim - o
		var c := Color(1, 0.95, 0.75, 0.9)
		_ellipse_outline(a, Vector2(9, 3.5), c)
		draw_rect(Rect2(a + Vector2(-1, -1), Vector2(2, 2)), c)
	# cần câu + dây + phao
	if player:
		# Minh quay mặt ra mương: cần chĩa từ tay xuống phía mặt nước, nghiêng về phía phao
		var target_x: float = (bobber.x if state != State.AIM else aim.x)
		var dir := 1.0 if target_x >= player.global_position.x else -1.0
		var hand := player.global_position + Vector2(dir * 2, 22) - o   # hai tay chắp trên đùi khi ngồi
		var buddy := _buddy()
		if _demo and buddy:
			# bạn đồng hành cầm cần (gốc toạ độ NPC ở chân → tay cao hơn chân ~34 px khi ngồi)
			dir = 1.0 if target_x >= buddy.global_position.x else -1.0
			hand = buddy.global_position + Vector2(dir * 2, 22 - 56) - o
		var tip := hand + Vector2(dir * 30, -34)                          # cần chéo lên
		draw_line(hand, tip, Color8(39, 39, 54), 4.0)          # viền
		draw_line(hand, tip, Color8(144, 94, 55), 2.0)         # cần tre
		draw_line(hand.lerp(tip, 0.6), tip, Color8(207, 162, 89), 1.0)
		if state != State.AIM:
			var bob := bobber - o
			var k := cast_t
			var cur := tip.lerp(bob, k) + Vector2(0, -sin(k * PI) * 30.0)
			if state == State.BITE_WINDOW or state == State.REELING:
				cur += Vector2(sin(t * 40.0) * 1.0, 2.0)
			elif nibble_dip > 0.0:
				cur += Vector2(0, 1.5)
			var mid := tip.lerp(cur, 0.5) + Vector2(dir * 4, 4)              # dây hơi chùng
			draw_polyline(PackedVector2Array([tip, mid, cur]), Color(0.9, 0.9, 0.95, 0.7), 1.0)
			draw_rect(Rect2(cur + Vector2(-1.5, -3), Vector2(3, 2)), Color8(235, 86, 75))
			draw_rect(Rect2(cur + Vector2(-1.5, -1), Vector2(3, 2)), Color8(255, 255, 235))
			if state == State.BITE_WINDOW:
				# Vòng thời gian thu hẹp quanh phao (xanh → cam khi sắp hết) + khung "!" — như bản gốc
				var ratio := clampf(1.0 - bite_t / maxf(0.01, _bite_window()), 0.0, 1.0)
				var ring_col := Color(0.32, 0.96, 0.48, 0.95) if ratio > 0.35 else Color(0.98, 0.64, 0.22, 0.98)
				draw_arc(bob, 16.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 24, ring_col, 2.5)
				var ap := (bob + Vector2(0, -24 - absf(sin(t * 10.0)) * 2.0)).round()
				draw_rect(Rect2(ap.x - 6, ap.y - 10, 12, 16), Color(0.08, 0.06, 0.12, 0.92))
				draw_rect(Rect2(ap.x - 5, ap.y - 9, 10, 14), Color(0.98, 0.80, 0.28))
				draw_rect(Rect2(ap.x - 1.5, ap.y - 7, 3, 7), Color(0.10, 0.08, 0.14))
				draw_rect(Rect2(ap.x - 1.5, ap.y + 1.5, 3, 2.5), Color(0.10, 0.08, 0.14))


func _ellipse_outline(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 21:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_polyline(pts, col, 1.0)


# --- Giao diện: dòng gợi ý + cột kéo cá -------------------------------------------------

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 70
	add_child(_ui)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.1, 0.85)
	sb.border_color = Color(0.98, 0.95, 0.85)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 22; sb.content_margin_right = 22
	sb.content_margin_top = 6; sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override(&"panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.offset_top = 24
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_ui.add_child(panel)
	_hint = Label.new()
	_hint.add_theme_font_override(&"font", FONT)
	_hint.add_theme_font_size_override(&"font_size", 40)
	_hint.add_theme_color_override(&"font_color", Color(0.98, 0.95, 0.85))
	panel.add_child(_hint)
	_gauge = Control.new()
	_gauge.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.draw.connect(_draw_gauge)
	_ui.add_child(_gauge)


func _set_hint(text: String) -> void:
	if _hint:
		_hint.text = text


func _draw_gauge() -> void:
	if state != State.REELING or player == null:
		return
	var vp := get_viewport()
	var head: Vector2 = vp.get_canvas_transform() * (player.global_position + Vector2(70, -40))
	var size := Vector2(34, 260)
	var pos := head + Vector2(0, -size.y * 0.5)
	_gauge.draw_rect(Rect2(pos - Vector2(4, 4), size + Vector2(8, 8)), Color(0.07, 0.06, 0.1, 0.9))
	_gauge.draw_rect(Rect2(pos - Vector2(4, 4), size + Vector2(8, 8)), Color(0.98, 0.95, 0.85), false, 3.0)
	_gauge.draw_rect(Rect2(pos, size), Color(0.13, 0.33, 0.5))
	# thanh xanh
	var bar_h := size.y * BAR_HEIGHT
	var bar_y := pos.y + size.y * (1.0 - reel_bar) - bar_h
	_gauge.draw_rect(Rect2(Vector2(pos.x + 2, bar_y), Vector2(size.x - 4, bar_h)), Color(0.56, 0.87, 0.36, 0.85))
	# cá
	var fy := pos.y + size.y * (1.0 - reel_fish)
	if ResourceLoader.exists(FISH_ICON_PATH):
		var tex: Texture2D = load(FISH_ICON_PATH)
		var s := 2.0
		_gauge.draw_texture_rect(tex, Rect2(Vector2(pos.x + size.x * 0.5 - tex.get_width() * s * 0.5, fy - tex.get_height() * s * 0.5), tex.get_size() * s), false)
	else:
		_gauge.draw_rect(Rect2(Vector2(pos.x + 8, fy - 5), Vector2(18, 10)), Color(0.9, 0.6, 0.3))
	# tiến độ
	var px := pos.x + size.x + 12
	_gauge.draw_rect(Rect2(Vector2(px, pos.y), Vector2(12, size.y)), Color(0.17, 0.14, 0.25))
	var ph := size.y * reel_progress
	var pc := Color(0.67, 0.81, 0.22) if reel_progress > 0.3 else Color(0.92, 0.34, 0.29)
	_gauge.draw_rect(Rect2(Vector2(px, pos.y + size.y - ph), Vector2(12, ph)), pc)


# --- Hướng dẫn lần đầu: bạn đồng hành nói + câu mẫu ------------------------------------

func _buddy() -> Node2D:
	var b := get_tree().get_first_node_in_group(&"companion") as Node2D
	return b if b and b.is_visible_in_tree() else null


func _buddy_name() -> String:
	var b := _buddy()
	return String(b.get("speaker_name")) if b and b.get("speaker_name") else "An"


## Hiện vài câu thoại của bạn đồng hành, tạm dừng câu cá cho tới khi đọc xong.
func _say(lines: Array) -> void:
	_talking = true
	var who := _buddy_name()
	var text := "~ start" + "\n"
	for l in lines:
		text += "%s: %s" % [who, l] + "\n"
	text += "=> END" + "\n"
	var res = DialogueManager.create_resource_from_text(text)
	DialogueManager.show_dialogue_balloon(res, "start")
	await DialogueManager.dialogue_ended
	if is_instance_valid(player):
		player.can_move = false   # hội thoại xong vẫn đang ngồi câu
	_talking = false


func _wait_state(st: State, timeout: float = 8.0) -> void:
	var left := timeout
	while state != st and left > 0.0 and is_inside_tree():
		await get_tree().process_frame
		if not _talking:
			left -= get_process_delta_time()


func _run_tutorial() -> void:
	_demo = true
	_set_hint("%s đang câu mẫu cho Minh xem…" % _buddy_name())
	await _say(["Để mình câu thử cho Minh coi nha!",
		"Nhìn mặt nước nè. Chỗ nào thỉnh thoảng có bong bóng sủi lên là chỗ đó có cá."])
	if not is_inside_tree(): return
	# Đợi một đợt bong bóng rồi dời phao tới chỗ cá
	_bubble_cluster(fish_pos, 4)
	await get_tree().create_timer(1.0).timeout
	_demo_aim_target = fish_pos
	await get_tree().create_timer(1.2).timeout
	await _say(["Rê chuột trên mặt nước hoặc bấm W/S để chọn chỗ thả phao.",
		"Ngay chỗ bong bóng thì click chuột hoặc bấm E để quăng câu."])
	if not is_inside_tree(): return
	aim = fish_pos
	_cast()
	await get_tree().create_timer(0.5).timeout
	await _say(["Phao nhúng nhẹ nhẹ là cá đang rỉa mồi, đừng kéo vội nha."])
	await _wait_state(State.BITE_WINDOW)
	if not is_inside_tree(): return
	await _say(["Thấy dấu chấm than với cái vòng xanh quanh phao là giật liền!",
		"Phải bấm trước khi vòng xanh chạy hết đó."])
	if state == State.BITE_WINDOW:
		bite_t = 0.0
		_enter_reel()
	await _say(["Dính rồi! Giờ giữ E hoặc giữ chuột để thanh xanh bám theo con cá.",
		"Cá ở trong thanh xanh thì cột bên cạnh đầy dần, đầy là kéo lên được."])
	await _wait_state(State.FEEDBACK, 15.0)
	if not is_inside_tree(): return
	await get_tree().create_timer(0.6).timeout
	await _say(["Đó, dễ ợt! Con này cho Minh luôn.", "Tới lượt Minh câu đó, cố lên!"])
	_demo = false
	GameState.set_flag(TUTORIAL_FLAG, true)
	_back_to_aim()
	_set_hint("Canh chỗ bong bóng sủi lên · Chuột / W,S chọn chỗ · Click / E thả câu · A/D đứng dậy")
