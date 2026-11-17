class_name FishingMinigame
extends MinigameBase
## Mini-game 1.2: Câu cá bên mương (GDD Bảng 13, 36, 40, 56, 59, 61, 62, 66).
##
## Cơ chế:
## 1. Quan sát gợn sóng & bóng cá trên 5 điểm câu (3 gần, 2 xa).
## 2. Căn chỉnh điểm thả cần (Chuột hoặc A/D/W/S / Analog trái) và thả cần (Click / E / A).
## 3. Khi cá cắn câu (tín hiệu "!" + phao chìm + sóng nước), nhấn giật cần trong cửa sổ w:
##    - Giai đoạn 1 (cá gần): w = 1,0 s
##    - Giai đoạn 2 (cá thường): w = 0,8 s
##    - Giai đoạn 3 (cá nhanh & xa): w = 0,7 s (nới theo chỉ số F và chế độ hỗ trợ)
## 4. "Nhờ Na" (Space / nút X): Na chỉ rõ vị trí cá và dẫn hướng trong 4 s (hồi 15 s).
## 5. Không có Game Over; hụt lượt tái lập <= 2 s và giữ nguyên số cá đã câu.

enum State {
	OBSERVE_AND_AIM,
	CAST_EMPTY,
	WAITING_BITE,
	BITE_WINDOW,
	CAUGHT_FEEDBACK,
	MISS_FEEDBACK,
	WON,
}

## Vùng mặt nước mương trong hệ tọa độ logic 640x360 (scale 3x = 1920x1080)
const WATER_RECT := Rect2(170.0, 202.0, 430.0, 128.0)
const WORLD_SCALE := 3.0
const AIM_MOVE_SPEED := 260.0
const MAGNET_RADIUS := 28.0
const ROD_BASE_POS := Vector2(126.0, 136.0)
const ROD_TIP_REST := Vector2(170.0, 88.0)
const BASKET_POS := Vector2(150.0, 182.0)

## 5 điểm có cá (3 gần: 0..2, 2 xa: 3..4) — GDD Bảng 40
const FISHING_SPOTS: Array[Vector2] = [
	Vector2(236.0, 224.0),  # 0: Gần trên
	Vector2(298.0, 286.0),  # 1: Gần dưới
	Vector2(362.0, 234.0),  # 2: Gần phải
	Vector2(474.0, 252.0),  # 3: Xa giữa
	Vector2(552.0, 294.0),  # 4: Xa sâu
]

const FISH_SPECIES := [
	{"name": "Cá rô đồng", "body": Color(0.11, 0.24, 0.28, 0.72), "fin": Color(0.15, 0.30, 0.34, 0.78), "length": 15.0, "swim": 34.0},
	{"name": "Cá sặc bướm", "body": Color(0.10, 0.22, 0.30, 0.74), "fin": Color(0.14, 0.28, 0.36, 0.80), "length": 17.0, "swim": 56.0},
	{"name": "Cá lóc đồng", "body": Color(0.08, 0.18, 0.24, 0.78), "fin": Color(0.12, 0.24, 0.30, 0.85), "length": 21.0, "swim": 96.0},
]

const FONT := preload("res://assets/fonts/vt323_regular.ttf")
const FISH_ICON := preload("res://assets/items/fish.png")

@export var default_target_count: int = 5

var target_count: int = 5
var caught_count: int = 0
var state: State = State.OBSERVE_AND_AIM
var score: int = 0
var used_adaptive_margin: bool = false

var aim_pos: Vector2 = FISHING_SPOTS[0]
var bobber_pos: Vector2 = FISHING_SPOTS[0]
var cast_from_pos: Vector2 = ROD_TIP_REST
var cast_anim_t: float = 1.0

var fish_spot_index: int = 0
var fish_pos: Vector2 = FISHING_SPOTS[0]
var fish_target_pos: Vector2 = FISHING_SPOTS[0]
var fish_facing: float = 1.0
var fish_relocate_timer: float = 0.0
var fish_is_fast: bool = false

var empty_wait_timer: float = 0.0
var wait_bite_timer: float = 0.0
var wait_bite_duration: float = 1.4
var next_nibble_time: float = 0.6
var nibble_dip_timer: float = 0.0

var bite_elapsed: float = 0.0
var current_bite_window: float = 1.0
var current_base_window: float = 1.0
var state_timer: float = 0.0

var _elapsed_visual: float = 0.0
var _ripples: Array[Dictionary] = []
var _splashes: Array[Dictionary] = []
var _caught_arc_active: bool = false
var _caught_arc_start: Vector2 = Vector2.ZERO
var _caught_arc_t: float = 0.0
var _using_mouse_aim: bool = false
var _manual_rng := RandomNumberGenerator.new()

@onready var world_viewport: Node2D = $WorldViewport
@onready var clouds_sprite: Sprite2D = get_node("WorldViewport/CanalScenery/02_May_va_suong_xa") as Sprite2D
@onready var minh_sprite: AnimatedSprite2D = $WorldViewport/MinhSprite
@onready var na_sprite: AnimatedSprite2D = $WorldViewport/NaSprite
@onready var fishing_canvas: Node2D = $WorldViewport/FishingCanvas

@onready var fish_count_label: Label = %FishCountLabel
@onready var stage_label: Label = %StageLabel
@onready var flawless_label: Label = %FlawlessLabel
@onready var na_button: Button = %NaButton
@onready var guide_button: Button = %GuideButton
@onready var restart_button: Button = %RestartButton
@onready var pause_button: Button = %PauseButton
@onready var restart_bar: ProgressBar = %RestartBar
@onready var feedback_panel: PanelContainer = %FeedbackPanel
@onready var feedback_label: Label = %FeedbackLabel
@onready var visual_aid_box: PanelContainer = %VisualAidBox
@onready var visual_aid_bar: ProgressBar = %VisualAidBar
@onready var visual_aid_label: Label = %VisualAidLabel

@onready var guide_overlay: PanelContainer = %GuideOverlay
@onready var guide_start_button: Button = %GuideStartButton
@onready var pause_overlay: PanelContainer = %PauseOverlay
@onready var resume_button: Button = %ResumeButton
@onready var pause_guide_button: Button = %PauseGuideButton
@onready var pause_restart_button: Button = %PauseRestartButton
@onready var pause_exit_button: Button = %PauseExitButton
@onready var win_overlay: PanelContainer = %WinOverlay
@onready var win_summary_label: Label = %WinSummaryLabel
@onready var win_finish_button: Button = %WinFinishButton
@onready var win_replay_button: Button = %WinReplayButton
@onready var restart_fade: ColorRect = %RestartFade

@onready var ambience_player: AudioStreamPlayer = $Audio/AmbiencePlayer
@onready var sfx_cast: AudioStreamPlayer = $Audio/SfxCast
@onready var sfx_nibble: AudioStreamPlayer = $Audio/SfxNibble
@onready var sfx_bite: AudioStreamPlayer = $Audio/SfxBite
@onready var sfx_catch: AudioStreamPlayer = $Audio/SfxCatch
@onready var sfx_miss: AudioStreamPlayer = $Audio/SfxMiss
@onready var sfx_na: AudioStreamPlayer = $Audio/SfxNa


func _on_setup(p: Dictionary) -> void:
	minigame_id = "fishing"
	minigame_title = "Câu cá bên mương"
	can_call_na = true
	na_duration = 4.0
	na_cooldown = 15.0
	hint_lines = PackedStringArray([
		"Bé Na: Đừng vội Minh ơi! Đợi phao thụt xuống và hiện dấu '!' hẳn giật cần nha!",
		"Ông Nội: 'Chậm mà chắc, nước động mới buông câu' — cứ đợi vòng sáng trên phao hãy bấm E hoặc click chuột nghen cháu.",
		"Gợi ý trực quan: Đã bật vòng định vị cá và thanh canh nhịp kéo cần!"
	])

	_manual_rng.randomize()
	target_count = clampi(int(p.get("target", default_target_count)), 1, 10)
	_configure_audio_buses()
	_connect_ui_once()
	_reset_match_state()

	# Mở bảng hướng dẫn 1 lần khi vào màn (trừ khi test bỏ qua bằng skip_intro)
	var show_intro := not bool(p.get("skip_intro", false)) and not GameState.has_flag("minigame.fishing.seen_guide")
	if show_intro:
		GameState.set_flag("minigame.fishing.seen_guide", true)
		_set_guide_visible(true)
	else:
		_set_guide_visible(false)

	pause_overlay.hide()
	win_overlay.hide()
	restart_fade.color.a = 0.0
	_update_hud()


func _configure_audio_buses() -> void:
	var sfx_bus := &"SFX" if AudioServer.get_bus_index(&"SFX") != -1 else &"Master"
	for player in [sfx_cast, sfx_nibble, sfx_bite, sfx_catch, sfx_miss, sfx_na]:
		if player:
			player.bus = sfx_bus
	if ambience_player:
		var amb_bus := &"Ambience" if AudioServer.get_bus_index(&"Ambience") != -1 else &"Master"
		ambience_player.bus = amb_bus
		if ambience_player.stream and "loop" in ambience_player.stream:
			ambience_player.stream.loop = true
		if not ambience_player.playing and not DisplayServer.get_name().begins_with("headless"):
			ambience_player.play()


func _connect_ui_once() -> void:
	if na_button.pressed.is_connected(_on_na_button_pressed):
		return
	na_button.pressed.connect(_on_na_button_pressed)
	guide_button.pressed.connect(request_hint)
	restart_button.pressed.connect(restart)
	pause_button.pressed.connect(_toggle_pause)
	guide_start_button.pressed.connect(func(): _set_guide_visible(false))
	resume_button.pressed.connect(func(): _set_pause_visible(false))
	pause_guide_button.pressed.connect(func():
		_set_pause_visible(false)
		_set_guide_visible(true)
	)
	pause_restart_button.pressed.connect(func():
		_set_pause_visible(false)
		restart()
	)
	pause_exit_button.pressed.connect(_abort_to_map)
	win_finish_button.pressed.connect(_emit_win_result)
	win_replay_button.pressed.connect(func():
		win_overlay.hide()
		restart()
	)


func _reset_match_state() -> void:
	caught_count = 0
	score = 0
	used_adaptive_margin = false
	_ripples.clear()
	_splashes.clear()
	_caught_arc_active = false
	_set_feedback("Bé Na: Minh nhìn chỗ có gợn sóng rồi thả cần xuống nha!")
	_start_next_turn()


func _start_next_turn() -> void:
	state = State.OBSERVE_AND_AIM
	empty_wait_timer = 0.0
	wait_bite_timer = 0.0
	bite_elapsed = 0.0
	nibble_dip_timer = 0.0
	cast_anim_t = 1.0
	_spawn_fish_for_current_stage()
	_update_hud()


# --- Giai đoạn & Tham số GDD (Bảng 36, 40, 56, 61) ---------------------------

func get_current_stage() -> int:
	if params.has("force_stage"):
		return clampi(int(params.get("force_stage", 1)), 1, 3)
	if caught_count < 2 and target_count >= 3:
		return 1
	if caught_count < target_count - 1:
		return 2
	return 3


func get_base_window_for_stage(stage: int) -> float:
	match stage:
		1:
			return 1.0
		2:
			return 0.8
		_:
			return 0.7


func get_current_catch_window() -> float:
	var base_w := get_base_window_for_stage(get_current_stage())
	var eff := get_effective_tolerance(base_w)
	# GDD Mục 5.7.3: Chế độ Thử thách không được làm ρ_c xuống dưới ρ_min (2.0 → w ≥ 0.70 s)
	if base_w <= 0.71:
		eff = maxf(eff, 0.70)
	return eff


func get_spot_hit_radius(stage: int) -> float:
	# Điểm xa / giai đoạn cao đòi hỏi căn vị trí chuẩn hơn một chút (Bảng 13 & 40)
	return 46.0 if stage <= 2 else 36.0


func is_flawless() -> bool:
	# Bảng 40: Tinh tế ≤ 3 lần cá thoát; Mục 5.7.3: Điều kiện Tinh tế luôn dùng τ_0
	return fail_count <= 3 and not used_adaptive_margin and not bool(params.get("gentle_mode", false))


func get_active_fish_spot_index() -> int:
	return fish_spot_index


func get_active_fish_position() -> Vector2:
	return fish_pos


func _spawn_fish_for_current_stage() -> void:
	var stage := get_current_stage()
	var candidates: Array[int] = []
	if stage == 1:
		candidates = [0, 1, 2]
		fish_is_fast = false
		fish_relocate_timer = 7.5
	elif stage == 2:
		candidates = [0, 1, 2, 3, 4]
		fish_is_fast = false
		fish_relocate_timer = 5.5
	else:
		candidates = [3, 4]  # Cá nhanh ở xa (Bảng 56)
		fish_is_fast = true
		fish_relocate_timer = 3.8

	fish_spot_index = candidates[_manual_rng.randi_range(0, candidates.size() - 1)]
	fish_target_pos = FISHING_SPOTS[fish_spot_index]
	fish_pos = fish_target_pos + Vector2(_manual_rng.randf_range(-16.0, 16.0), _manual_rng.randf_range(-6.0, 6.0))
	fish_facing = -1.0 if fish_pos.x > fish_target_pos.x else 1.0
	_spawn_ripple(fish_target_pos, 1.0)


func _relocate_fish() -> void:
	var stage := get_current_stage()
	var candidates: Array[int] = [0, 1, 2] if stage == 1 else ([0, 1, 2, 3, 4] if stage == 2 else [3, 4])
	if candidates.size() > 1:
		var next_idx: int = candidates[_manual_rng.randi_range(0, candidates.size() - 1)]
		if next_idx == fish_spot_index:
			next_idx = candidates[(candidates.find(next_idx) + 1) % candidates.size()]
		fish_spot_index = next_idx
		fish_target_pos = FISHING_SPOTS[fish_spot_index]
		fish_facing = 1.0 if fish_target_pos.x >= fish_pos.x else -1.0
	fish_relocate_timer = 7.5 if stage == 1 else (5.5 if stage == 2 else 3.8)


# --- Vòng lặp chính & Điều khiển song song (Chuột/Phím + Tay cầm) ------------

func _should_accumulate_stuck_time() -> bool:
	return not pause_overlay.visible and state != State.WON


func _on_minigame_process(delta: float) -> void:
	_elapsed_visual += delta
	_fit_world_viewport()
	_animate_scenery(delta)
	_update_particles(delta)

	if pause_overlay.visible or is_paused_for_guide:
		fishing_canvas.queue_redraw()
		return

	# Cập nhật thanh giữ phím R làm lại
	restart_bar.visible = restart_hold_progress > 0.02
	restart_bar.value = (restart_hold_progress / RESTART_HOLD_TIME) * 100.0

	# Khi "Nhờ Na" đang bật, tự dẫn tiêu điểm tới cá nếu người chơi đang ngắm
	if na_active_remaining > 0.0 and state == State.OBSERVE_AND_AIM:
		aim_pos = aim_pos.lerp(fish_target_pos, clampf(delta * 5.5, 0.0, 1.0))

	# Di chuyển tâm ngắm bằng Bàn phím (A/D/W/S, mũi tên) hoặc Analog trái Tay cầm
	if state == State.OBSERVE_AND_AIM:
		var move_vec := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
		if move_vec.length() > 0.08:
			_using_mouse_aim = false
			aim_pos += move_vec * AIM_MOVE_SPEED * delta
			aim_pos = _clamp_to_water(aim_pos)
		elif not _using_mouse_aim and na_active_remaining <= 0.0:
			# Hít nhẹ vào điểm câu gần nhất để dùng bàn phím/tay cầm dễ canh chuẩn
			var nearest := _nearest_spot_pos(aim_pos)
			if aim_pos.distance_to(nearest) <= MAGNET_RADIUS:
				aim_pos = aim_pos.lerp(nearest, clampf(delta * 9.0, 0.0, 1.0))

	_update_fish_motion(delta)
	_update_state_machine(delta)
	_update_hud()
	fishing_canvas.queue_redraw()


func _update_fish_motion(delta: float) -> void:
	if state in [State.CAUGHT_FEEDBACK, State.WON]:
		return

	var spec: Dictionary = FISH_SPECIES[get_current_stage() - 1]
	var swim_speed := float(spec["swim"])

	if state == State.OBSERVE_AND_AIM or state == State.CAST_EMPTY:
		fish_relocate_timer -= delta
		if fish_relocate_timer <= 0.0:
			_relocate_fish()
		# Cá bơi lượn quanh điểm hiện tại
		var orbit := Vector2(sin(_elapsed_visual * (2.6 if fish_is_fast else 1.5)) * 14.0, cos(_elapsed_visual * 2.1) * 4.0)
		var goal := fish_target_pos + orbit
		if state == State.CAST_EMPTY and fish_pos.distance_to(bobber_pos) <= get_spot_hit_radius(get_current_stage()) * 1.15:
			goal = bobber_pos
		var diff := goal - fish_pos
		if diff.length() > 1.5:
			fish_facing = 1.0 if diff.x >= 0.0 else -1.0
			fish_pos += diff.normalized() * minf(diff.length(), swim_speed * delta)
		if int(floor(_elapsed_visual * 2.2)) != int(floor((_elapsed_visual - delta) * 2.2)):
			_spawn_ripple(fish_pos, 0.75)

	elif state == State.WAITING_BITE:
		var approach := bobber_pos + Vector2(-fish_facing * 8.0, 2.0)
		var diff := approach - fish_pos
		if diff.length() > 1.0:
			fish_pos += diff.normalized() * minf(diff.length(), swim_speed * 1.2 * delta)


func _update_state_machine(delta: float) -> void:
	cast_anim_t = minf(1.0, cast_anim_t + delta * 4.5)
	nibble_dip_timer = maxf(0.0, nibble_dip_timer - delta)

	match state:
		State.CAST_EMPTY:
			empty_wait_timer += delta
			# Nếu cá bơi vào tầm phao trong lúc chờ → cắn câu luôn
			if fish_pos.distance_to(bobber_pos) <= get_spot_hit_radius(get_current_stage()):
				_enter_waiting_bite()
			elif empty_wait_timer >= 1.05:
				_set_feedback("Bé Na: Chỗ này hổng có cá rồi, kéo lên thả chỗ gợn sóng thử coi!")
				_start_next_turn()

		State.WAITING_BITE:
			wait_bite_timer += delta
			if wait_bite_timer >= next_nibble_time and wait_bite_timer < wait_bite_duration:
				nibble_dip_timer = 0.16
				next_nibble_time += _manual_rng.randf_range(0.55, 0.85)
				_spawn_ripple(bobber_pos, 0.65)
				_play_sfx(sfx_nibble)
			if wait_bite_timer >= wait_bite_duration:
				_enter_bite_window()

		State.BITE_WINDOW:
			bite_elapsed += delta
			if bite_elapsed > current_bite_window:
				_trigger_miss("Quá trễ! Cá nhả mồi lặn mất tiêu rồi...", false)

		State.CAUGHT_FEEDBACK:
			state_timer += delta
			_caught_arc_t = clampf(state_timer / 0.65, 0.0, 1.0)
			if state_timer >= 0.85:
				_caught_arc_active = false
				if caught_count >= target_count:
					_enter_won_state()
				else:
					_start_next_turn()

		State.MISS_FEEDBACK:
			state_timer += delta
			if state_timer >= 0.80:
				_start_next_turn()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		if win_overlay.visible:
			return
		if is_paused_for_guide:
			_set_guide_visible(false)
		else:
			_toggle_pause()
		return

	if is_paused_for_guide:
		if event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"show_hint") or event.is_action_pressed(&"cancel"):
			get_viewport().set_input_as_handled()
			_set_guide_visible(false)
		return

	if pause_overlay.visible:
		if event.is_action_pressed(&"cancel"):
			get_viewport().set_input_as_handled()
			_set_pause_visible(false)
		return

	if state == State.WON:
		if event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept"):
			get_viewport().set_input_as_handled()
			_emit_win_result()
		return

	# Gọi MinigameBase cho Show Hint (H) và Nhờ Na (Space / X)
	super._unhandled_input(event)
	if get_viewport().is_input_handled():
		return

	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if state == State.OBSERVE_AND_AIM:
			var s: float = world_viewport.scale.x if world_viewport.scale.x > 0.0 else WORLD_SCALE
			var logical_pos: Vector2 = (motion.position - world_viewport.position) / s
			if WATER_RECT.grow(18.0).has_point(logical_pos):
				_using_mouse_aim = true
				aim_pos = _clamp_to_water(logical_pos)
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var s: float = world_viewport.scale.x if world_viewport.scale.x > 0.0 else WORLD_SCALE
			var logical_pos: Vector2 = (mb.position - world_viewport.position) / s
			if state == State.OBSERVE_AND_AIM:
				aim_pos = _clamp_to_water(logical_pos)
			get_viewport().set_input_as_handled()
			trigger_primary_action()
		return

	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		trigger_primary_action()


# --- Hành động thả cần & giật cần (hỗ trợ cả kiểm thử tự động) ------------

func trigger_primary_action() -> String:
	match state:
		State.OBSERVE_AND_AIM:
			attempt_cast_at(aim_pos)
			return "cast"
		State.CAST_EMPTY:
			_set_feedback("Thu cần lên chọn chỗ khác có bóng cá nha!")
			_start_next_turn()
			return "retract"
		State.WAITING_BITE, State.BITE_WINDOW:
			return pull_rod()
		_:
			return "busy"


func attempt_cast_at(target_pos: Vector2) -> bool:
	if state != State.OBSERVE_AND_AIM:
		return false
	aim_pos = _clamp_to_water(target_pos)
	bobber_pos = aim_pos
	cast_from_pos = ROD_TIP_REST
	cast_anim_t = 0.0
	_play_sfx(sfx_cast)
	_spawn_ripple(bobber_pos, 1.1)

	var hit_radius := get_spot_hit_radius(get_current_stage())
	var hit_fish := bobber_pos.distance_to(fish_pos) <= hit_radius or bobber_pos.distance_to(fish_target_pos) <= hit_radius
	if hit_fish:
		_enter_waiting_bite()
		return true

	state = State.CAST_EMPTY
	empty_wait_timer = 0.0
	_set_feedback("Minh: (Thả phao rồi... đợi chút xem có cá lại không.)")
	return false


func _enter_waiting_bite() -> void:
	state = State.WAITING_BITE
	wait_bite_timer = 0.0
	wait_bite_duration = _manual_rng.randf_range(0.95, 1.95)
	next_nibble_time = minf(wait_bite_duration * 0.48, 0.70)
	_set_feedback("Bé Na: Suỵt... cá đang tới rỉa mồi kìa, đợi phao giật mạnh hãy kéo!")


func _enter_bite_window() -> void:
	state = State.BITE_WINDOW
	bite_elapsed = 0.0
	current_base_window = get_base_window_for_stage(get_current_stage())
	current_bite_window = get_current_catch_window()
	_spawn_ripple(bobber_pos, 1.6)
	_spawn_splashes(bobber_pos, 10)
	_play_sfx(sfx_bite)
	_set_feedback("Bé Na: CÁ CẮN CÂU RỒI! Bấm E / Click / A kéo ngay!!")


func pull_rod() -> String:
	if state == State.WAITING_BITE:
		_trigger_miss("Sớm quá rồi! Cá giật mình chạy mất tiêu...", true)
		return "early"
	if state == State.BITE_WINDOW:
		if bite_elapsed <= current_bite_window:
			if bite_elapsed > current_base_window:
				used_adaptive_margin = true
			_trigger_catch()
			return "caught"
		_trigger_miss("Trễ nhịp mất rồi! Cá lặn xuống đáy mất...", false)
		return "late"
	return "ignored"


func _trigger_catch() -> void:
	caught_count += 1
	score += 100 if bite_elapsed <= current_base_window * 0.65 else 75
	state = State.CAUGHT_FEEDBACK
	state_timer = 0.0
	_caught_arc_active = true
	_caught_arc_start = bobber_pos
	_caught_arc_t = 0.0
	_spawn_splashes(bobber_pos, 14)
	_play_sfx(sfx_catch)
	report_progress()  # OnProgress (Bảng 59): reset T_stuck về 0

	var spec: Dictionary = FISH_SPECIES[mini(get_current_stage() - 1, FISH_SPECIES.size() - 1)]
	if caught_count >= target_count:
		_set_feedback("Bé Na: Đủ %d con cá rồi nè Minh ơi! Giỏi quá chừng!" % target_count)
	else:
		_set_feedback("Bé Na: Hay quá! Dính được 1 con %s rồi (%d/%d)!" % [spec["name"], caught_count, target_count])
	_update_hud()


func _trigger_miss(message: String, early: bool) -> void:
	state = State.MISS_FEEDBACK
	state_timer = 0.0
	_spawn_splashes(bobber_pos, 6)
	_play_sfx(sfx_miss)
	report_fail()  # Tăng N_fail và kiểm tra ngưỡng gợi ý F (3, 6, 9)

	# Nếu vừa kích hoạt gợi ý cấp 1/2/3 ở lượt này, ưu tiên giữ câu gợi ý đó
	if highest_hint_tier == 0 or (fail_count != 3 and fail_count != 6 and fail_count != 9):
		var tip := "Đợi dấu '!' hiện lên hẳn giật nha." if early else "Kéo nhanh tay chút khi thấy dấu '!' nghen!"
		_set_feedback("%s %s" % [message, tip])
	_update_hud()


func _enter_won_state() -> void:
	state = State.WON
	var flawless := is_flawless()
	var bonus_line := "Thành tích 'Tinh tế': Đạt (+1 Hạt Gió!)" if flawless else "Số lần cá thoát: %d (≤ 3 lần để đạt Tinh tế)" % fail_count
	win_summary_label.text = "Đã câu đủ %d con cá đồng cùng Bé Na!\nĐiểm: %d · %s" % [caught_count, score, bonus_line]
	win_replay_button.visible = _standalone_mode
	win_finish_button.text = "Thoát [E / A]" if _standalone_mode else "Hoàn thành [E / A]"
	win_overlay.show()
	win_finish_button.grab_focus()


func _emit_win_result() -> void:
	finish({
		"success": true,
		"score": score,
		"item_id": "fish",
		"amount": caught_count,
		"wind_seeds": 1,
		"flawless": is_flawless(),
		"fail_count": fail_count,
	})
	if _standalone_mode:
		get_tree().quit()


func _abort_to_map() -> void:
	_set_pause_visible(false)
	if _standalone_mode:
		restart()
	else:
		finish({
			"success": false,
			"aborted": true,
			"score": score,
			"fail_count": fail_count,
		})


# --- Callback từ MinigameBase (Nhờ Na, Gợi ý F, Hướng dẫn, Làm lại) ----------

func _on_na_help() -> void:
	_play_sfx(sfx_na)
	_spawn_ripple(fish_target_pos, 1.5)
	_set_feedback("Bé Na: A! Mình thấy bóng cá đang quẫy ngay chỗ mũi tên vàng kìa Minh!")
	_update_hud()


func _on_na_help_ended() -> void:
	_update_hud()


func _on_hint_triggered(tier: int, _speaker: String, text: String) -> void:
	_set_feedback(text)
	if tier >= 3:
		_update_hud()


func _on_request_hint() -> void:
	if win_overlay.visible or pause_overlay.visible:
		return
	_set_guide_visible(not guide_overlay.visible)


func _on_restart() -> void:
	# Tái lập <= 2 giây (Luật R2, GP-TC-02): fade nhanh 0.15 s + 0.15 s = 0.30 s
	var tw := create_tween()
	tw.tween_property(restart_fade, "color:a", 1.0, 0.15)
	await tw.finished

	fail_count = 0
	stuck_seconds = 0.0
	_f_reduction = 0.0
	highest_hint_tier = 0
	visual_aid_enabled = false
	na_active_remaining = 0.0
	na_cooldown_remaining = 0.0
	win_overlay.hide()
	_reset_match_state()

	var tw_in := create_tween()
	tw_in.tween_property(restart_fade, "color:a", 0.0, 0.15)
	await tw_in.finished


# --- Cập nhật HUD & Overlay ---------------------------------------------------

func _set_guide_visible(show_guide: bool) -> void:
	is_paused_for_guide = show_guide
	guide_overlay.visible = show_guide
	if show_guide:
		guide_start_button.grab_focus()


func _set_pause_visible(show_pause: bool) -> void:
	pause_overlay.visible = show_pause
	if show_pause:
		resume_button.grab_focus()


func _toggle_pause() -> void:
	_set_pause_visible(not pause_overlay.visible)


func _on_na_button_pressed() -> void:
	if not is_paused_for_guide and not pause_overlay.visible and not win_overlay.visible:
		call_na()


func _set_feedback(msg: String) -> void:
	feedback_label.text = msg


func _update_hud() -> void:
	fish_count_label.text = "Cá đã câu: %d / %d" % [caught_count, target_count]

	var stage := get_current_stage()
	var w_sec := get_current_catch_window()
	var stage_names := {
		1: "Giai đoạn 1 · Cá gần (%.2fs)" % w_sec,
		2: "Giai đoạn 2 · Cá vừa (%.2fs)" % w_sec,
		3: "Giai đoạn 3 · Cá nhanh & xa (%.2fs)" % w_sec,
	}
	stage_label.text = stage_names[stage]
	flawless_label.text = "Hụt: %d/3 (Tinh tế)" % fail_count if is_flawless() else "Hụt: %d (Cố lên!)" % fail_count
	flawless_label.modulate = Color(0.98, 0.88, 0.48) if is_flawless() else Color(0.78, 0.78, 0.85)

	if na_active_remaining > 0.0:
		na_button.text = "Na đang chỉ (%.0fs)" % ceilf(na_active_remaining)
		na_button.disabled = true
	elif na_cooldown_remaining > 0.0:
		na_button.text = "Nhờ Na (%.0fs)" % ceilf(na_cooldown_remaining)
		na_button.disabled = true
	else:
		na_button.text = "[Space / X] Nhờ Na"
		na_button.disabled = false

	# Hiển thị thanh nhịp trực quan khi cấp gợi ý 3 (F >= 9) bật
	var show_aid := visual_aid_enabled and state == State.BITE_WINDOW
	visual_aid_box.visible = show_aid
	if show_aid:
		var remain := clampf(1.0 - (bite_elapsed / maxf(0.01, current_bite_window)), 0.0, 1.0)
		visual_aid_bar.value = remain * 100.0
		visual_aid_label.text = "KÉO NGAY! [E / Click / A] (%.2fs)" % maxf(0.0, current_bite_window - bite_elapsed)


# --- Vẽ khung cảnh pixel-art, cần câu, sóng nước & bóng cá --------------------

func _fit_world_viewport() -> void:
	var view_size := get_viewport_rect().size
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		return
	var s := maxf(view_size.x / 640.0, view_size.y / 360.0)
	world_viewport.scale = Vector2(s, s)
	world_viewport.position = (view_size - Vector2(640.0, 360.0) * s) * 0.5


func _animate_scenery(delta: float) -> void:
	if clouds_sprite:
		clouds_sprite.position.x -= delta * 4.0
		if clouds_sprite.position.x < -300.0:
			clouds_sprite.position.x = 0.0

	if minh_sprite and minh_sprite.sprite_frames:
		var m_anim := &"Idle"
		if not minh_sprite.is_playing() or minh_sprite.animation != m_anim:
			minh_sprite.play(m_anim)
		minh_sprite.flip_h = false

	if na_sprite and na_sprite.sprite_frames:
		var n_anim := &"Idle"
		if not na_sprite.is_playing() or na_sprite.animation != n_anim:
			na_sprite.play(n_anim)
		na_sprite.flip_h = false


func _update_particles(delta: float) -> void:
	for i in range(_ripples.size() - 1, -1, -1):
		var r: Dictionary = _ripples[i]
		r["age"] = float(r["age"]) + delta
		if float(r["age"]) >= float(r["life"]):
			_ripples.remove_at(i)

	for i in range(_splashes.size() - 1, -1, -1):
		var sp: Dictionary = _splashes[i]
		sp["age"] = float(sp["age"]) + delta
		var vel: Vector2 = sp["vel"]
		vel.y += 180.0 * delta
		sp["vel"] = vel
		sp["pos"] = Vector2(sp["pos"]) + vel * delta
		if float(sp["age"]) >= float(sp["life"]):
			_splashes.remove_at(i)


func _spawn_ripple(pos: Vector2, scale_mul: float = 1.0) -> void:
	_ripples.append({"pos": pos, "age": 0.0, "life": 0.95, "scale": scale_mul})


func _spawn_splashes(pos: Vector2, count: int) -> void:
	for i in count:
		var ang := _manual_rng.randf_range(-PI * 0.92, -PI * 0.08)
		var spd := _manual_rng.randf_range(36.0, 82.0)
		_splashes.append({
			"pos": pos + Vector2(_manual_rng.randf_range(-4.0, 4.0), 0.0),
			"vel": Vector2(cos(ang), sin(ang)) * spd,
			"age": 0.0,
			"life": _manual_rng.randf_range(0.30, 0.50),
		})


func draw_fishing_world(canvas: Node2D) -> void:
	_draw_water_details(canvas)
	_draw_basket(canvas)
	_draw_spots_and_fish(canvas)
	_draw_ripples_and_splashes(canvas)
	_draw_rod_and_bobber(canvas)
	_draw_aim_and_alerts(canvas)


func _draw_water_details(canvas: Node2D) -> void:
	# Vẽ mấy bụi cỏ lau & lá súng trang trí ven mương cho sinh động
	var pads := [Vector2(194, 206), Vector2(414, 212), Vector2(598, 224)]
	for p in pads:
		canvas.draw_circle(p, 7.0, Color(0.20, 0.49, 0.27, 0.85))
		canvas.draw_circle(p + Vector2(-1, -1), 5.0, Color(0.32, 0.65, 0.34, 0.85))
		canvas.draw_line(p, p + Vector2(5, 1), Color(0.14, 0.36, 0.22, 0.9), 1.0)

	# Sóng nước lấp lánh nhẹ dưới sâu (y = 274..355)
	for i in 10:
		var y := 278.0 + i * 7.5
		var x := fposmod(60.0 + i * 73.0 - _elapsed_visual * (8.0 + (i % 3) * 2.0), 460.0) + 170.0
		var w := 12.0 + float(i % 4) * 5.0
		canvas.draw_line(Vector2(x, y), Vector2(x + w, y), Color(0.42, 0.76, 0.92, 0.32), 1.0)


func _draw_basket(canvas: Node2D) -> void:
	# Giỏ cá đan bằng tre bên chân Minh
	var bx := BASKET_POS.x
	var by := BASKET_POS.y
	canvas.draw_rect(Rect2(bx - 8, by - 10, 16, 12), Color(0.11, 0.09, 0.16))
	canvas.draw_rect(Rect2(bx - 7, by - 9, 14, 10), Color(0.68, 0.48, 0.26))
	canvas.draw_rect(Rect2(bx - 6, by - 11, 12, 3), Color(0.84, 0.64, 0.38))
	for i in mini(caught_count, 5):
		var fx := bx - 4.0 + i * 2.2
		canvas.draw_rect(Rect2(fx, by - 14 - (i % 2) * 2, 3, 4), Color(0.45, 0.78, 0.82))

	if _caught_arc_active:
		var t := _caught_arc_t
		var arc_pos := _caught_arc_start.lerp(BASKET_POS + Vector2(0, -14), t)
		arc_pos.y -= sin(t * PI) * 62.0
		_draw_fish_silhouette(canvas, arc_pos, 14.0, -1.0, Color(0.36, 0.72, 0.78), Color(0.84, 0.46, 0.30))


func _draw_spots_and_fish(canvas: Node2D) -> void:
	# 5 điểm câu mờ dịu trên mặt nước
	for i in FISHING_SPOTS.size():
		var sp := FISHING_SPOTS[i]
		var is_far := i >= 3
		var col := Color(0.85, 0.95, 1.0, 0.14 if not is_far else 0.18)
		_draw_pixel_oval(canvas, sp, 18.0, 6.5, col)

	# Bóng cá đang bơi dưới nước
	if state in [State.OBSERVE_AND_AIM, State.CAST_EMPTY, State.WAITING_BITE, State.BITE_WINDOW]:
		var spec: Dictionary = FISH_SPECIES[mini(get_current_stage() - 1, FISH_SPECIES.size() - 1)]
		_draw_fish_silhouette(canvas, fish_pos, float(spec["length"]), fish_facing, spec["body"], spec["fin"])

	# Nếu "Nhờ Na" hoặc Gợi ý cấp 3 đang bật → vòng sáng định vị chỗ cá
	if (na_active_remaining > 0.0 or visual_aid_enabled) and state in [State.OBSERVE_AND_AIM, State.CAST_EMPTY]:
		var pulse := 1.0 + sin(_elapsed_visual * 8.0) * 0.15
		var ring_col := Color(0.98, 0.82, 0.30, 0.92) if na_active_remaining > 0.0 else Color(0.35, 0.94, 0.75, 0.82)
		_draw_pixel_oval(canvas, fish_target_pos, 22.0 * pulse, 9.0 * pulse, ring_col, 1.5)
		# Mũi tên vàng nhảy lên xuống chỉ điểm cá
		var ay := fish_target_pos.y - 20.0 + sin(_elapsed_visual * 7.0) * 3.0
		var ax := fish_target_pos.x
		canvas.draw_line(Vector2(ax, ay - 9), Vector2(ax, ay), ring_col, 2.0)
		canvas.draw_line(Vector2(ax - 4, ay - 4), Vector2(ax, ay), ring_col, 2.0)
		canvas.draw_line(Vector2(ax + 4, ay - 4), Vector2(ax, ay), ring_col, 2.0)
		if na_active_remaining > 0.0:
			# Đường dẫn mảnh từ tay Na hướng tới bóng cá
			canvas.draw_dashed_line(Vector2(86, 134), Vector2(ax, ay - 12), Color(0.98, 0.85, 0.35, 0.55), 1.0, 4.0)


func _draw_fish_silhouette(canvas: Node2D, pos: Vector2, length: float, facing: float, body_col: Color, fin_col: Color) -> void:
	var wag := sin(_elapsed_visual * (12.0 if fish_is_fast else 6.0)) * 2.5
	var head := pos + Vector2(facing * length * 0.45, 0)
	var tail := pos - Vector2(facing * length * 0.55, wag * 0.4)
	canvas.draw_line(head, tail, body_col, 5.0)
	canvas.draw_circle(pos + Vector2(facing * length * 0.12, 0), 3.2, body_col)
	# Đuôi cá
	var fin_top := tail + Vector2(-facing * 4.5, -3.5 + wag * 0.5)
	var fin_bot := tail + Vector2(-facing * 4.5, 3.5 + wag * 0.5)
	canvas.draw_colored_polygon(PackedVector2Array([tail, fin_top, fin_bot]), fin_col)


func _draw_ripples_and_splashes(canvas: Node2D) -> void:
	for r in _ripples:
		var t := float(r["age"]) / float(r["life"])
		var rad := (6.0 + t * 18.0) * float(r["scale"])
		var alpha := (1.0 - t) * 0.65
		_draw_pixel_oval(canvas, Vector2(r["pos"]), rad, rad * 0.38, Color(0.86, 0.96, 1.0, alpha), 1.0)

	for sp in _splashes:
		var alpha := 1.0 - float(sp["age"]) / float(sp["life"])
		canvas.draw_rect(Rect2(Vector2(sp["pos"]), Vector2(2, 2)), Color(0.92, 0.98, 1.0, alpha))


func _draw_rod_and_bobber(canvas: Node2D) -> void:
	var rod_flex := 0.0
	if state == State.BITE_WINDOW:
		rod_flex = 8.0 + sin(_elapsed_visual * 24.0) * 2.0
	elif state == State.CAUGHT_FEEDBACK:
		rod_flex = -12.0
	var tip := ROD_TIP_REST + Vector2(0, rod_flex)

	# Cần câu tre
	canvas.draw_line(ROD_BASE_POS, tip, Color(0.45, 0.48, 0.22), 2.5)
	canvas.draw_line(ROD_BASE_POS + Vector2(0, -1), tip + Vector2(0, -1), Color(0.76, 0.78, 0.40), 1.0)

	if state in [State.CAST_EMPTY, State.WAITING_BITE, State.BITE_WINDOW]:
		var b_pos := cast_from_pos.lerp(bobber_pos, cast_anim_t)
		if cast_anim_t < 1.0:
			b_pos.y -= sin(cast_anim_t * PI) * 32.0
		var bob_y := sin(_elapsed_visual * 4.0) * 1.2
		if nibble_dip_timer > 0.0:
			bob_y += 2.8
		elif state == State.BITE_WINDOW:
			bob_y += 5.5
		b_pos.y += bob_y

		# Dây câu hơi võng tự nhiên
		var mid := (tip + b_pos) * 0.5 + Vector2(0, 6.0 if state != State.BITE_WINDOW else 0.0)
		canvas.draw_line(tip, mid, Color(0.92, 0.96, 1.0, 0.85), 1.0)
		canvas.draw_line(mid, b_pos, Color(0.92, 0.96, 1.0, 0.85), 1.0)

		# Phao câu (trên đỏ, dưới trắng)
		canvas.draw_rect(Rect2(b_pos.x - 2, b_pos.y - 5, 4, 4), Color(0.90, 0.26, 0.24))
		canvas.draw_rect(Rect2(b_pos.x - 2, b_pos.y - 1, 4, 3), Color(0.97, 0.96, 0.90))
	else:
		# Dây câu rủ nhẹ khi chưa thả
		canvas.draw_line(tip, tip + Vector2(2, 16), Color(0.90, 0.95, 1.0, 0.65), 1.0)


func _draw_aim_and_alerts(canvas: Node2D) -> void:
	if state == State.OBSERVE_AND_AIM:
		var hit_r := get_spot_hit_radius(get_current_stage())
		var in_range := aim_pos.distance_to(fish_pos) <= hit_r or aim_pos.distance_to(fish_target_pos) <= hit_r
		var col := Color(0.98, 0.85, 0.34, 0.95) if in_range else Color(0.95, 0.98, 1.0, 0.85)
		_draw_pixel_oval(canvas, aim_pos, 12.0, 5.0, col, 1.5)
		canvas.draw_line(aim_pos + Vector2(-4, 0), aim_pos + Vector2(4, 0), col, 1.0)
		canvas.draw_line(aim_pos + Vector2(0, -3), aim_pos + Vector2(0, 3), col, 1.0)
		# Đường ngắm mờ từ đầu cần câu
		canvas.draw_dashed_line(ROD_TIP_REST, aim_pos, Color(1, 1, 1, 0.25), 1.0, 5.0)

	elif state == State.BITE_WINDOW:
		# Dấu "!" nổi bật + vòng thời gian thu hẹp quanh phao
		var ratio := clampf(1.0 - (bite_elapsed / maxf(0.01, current_bite_window)), 0.0, 1.0)
		var alert_pos := bobber_pos + Vector2(0, -24)
		var ring_col := Color(0.32, 0.96, 0.48, 0.95) if ratio > 0.35 else Color(0.98, 0.64, 0.22, 0.98)
		canvas.draw_arc(bobber_pos, 16.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 24, ring_col, 2.5)
		# Khung dấu "!" pixel-art
		canvas.draw_rect(Rect2(alert_pos.x - 6, alert_pos.y - 10, 12, 16), Color(0.08, 0.06, 0.12, 0.92))
		canvas.draw_rect(Rect2(alert_pos.x - 5, alert_pos.y - 9, 10, 14), Color(0.98, 0.80, 0.28))
		canvas.draw_rect(Rect2(alert_pos.x - 1.5, alert_pos.y - 7, 3, 7), Color(0.10, 0.08, 0.14))
		canvas.draw_rect(Rect2(alert_pos.x - 1.5, alert_pos.y + 1.5, 3, 2.5), Color(0.10, 0.08, 0.14))


func _draw_pixel_oval(canvas: Node2D, center: Vector2, rx: float, ry: float, col: Color, width: float = 1.0) -> void:
	var pts := PackedVector2Array()
	var steps := 24
	for i in steps + 1:
		var a := (float(i) / float(steps)) * TAU
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	canvas.draw_polyline(pts, col, width)


func _clamp_to_water(p: Vector2) -> Vector2:
	return Vector2(
		clampf(p.x, WATER_RECT.position.x, WATER_RECT.end.x),
		clampf(p.y, WATER_RECT.position.y, WATER_RECT.end.y)
	)


func _nearest_spot_pos(p: Vector2) -> Vector2:
	var best := FISHING_SPOTS[0]
	var best_d := INF
	for sp in FISHING_SPOTS:
		var d := p.distance_squared_to(sp)
		if d < best_d:
			best_d = d
			best = sp
	return best


func _play_sfx(player: AudioStreamPlayer) -> void:
	if player and player.stream and not DisplayServer.get_name().begins_with("headless"):
		player.play()
