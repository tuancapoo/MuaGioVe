class_name MinigameBase
extends Control
## Lớp cơ sở cho mọi mini-game trong Mùa Gió Về (Hệ thống S2 & S6 trong GDD).
##
## Cung cấp:
## - signal finished(result: Dictionary)
## - setup(params), restart() (giữ R 0,5 s → tái lập ≤ 2 s, luật R2)
## - Chỉ số bực bội F = N_fail + T_stuck / 30 (luật R6, Bảng 57–59):
##     Cấp 1 (F ≥ 3): Na nhắc nhẹ
##     Cấp 2 (F ≥ 6): Ông Nội gợi ý bằng ca dao / lời khuyên
##     Cấp 3 (F ≥ 9): Hiển thị minh họa trực quan (bật visual_aid_enabled)
##     Sau mỗi gợi ý, F giảm 3.
## - Nới dung sai thích ứng τ_eff = τ_0 * (1 + a_adapt + a_mode), tối đa +35% (Mục 5.7.3, Bảng 61)
## - Hỗ trợ "Nhờ Na" (Space / nút X): thời lượng d_Na, hồi 15 s (luật R5, Bảng 62)
## - Xem lại hướng dẫn (H / Back)
## - Chạy độc lập bằng F6 để kiểm thử nhanh.

signal finished(result: Dictionary)
signal progress_made
signal fail_reported(fail_count: int, f_index: float)
signal hint_shown(tier: int, speaker: String, text: String)
signal na_help_triggered(duration: float)
signal na_help_ended
signal restarted

const RESTART_HOLD_TIME := 0.5
const STUCK_DIVISOR := 30.0
const F_REDUCTION_PER_HINT := 3.0

@export var minigame_id: String = "fishing"
@export var minigame_title: String = "Mini-game"
@export var can_call_na: bool = true
## Thời lượng Na hỗ trợ mỗi lần gọi (giây) — Bảng 62: 4 s cho màn 1.2
@export var na_duration: float = 4.0
## Thời gian hồi "Nhờ Na" (giây) — Luật R5 & Bảng 62: 15 s
@export var na_cooldown: float = 15.0
## Ba câu gợi ý ứng với Cấp 1 (Na), Cấp 2 (Ông Nội), Cấp 3 (Minh họa trực quan)
@export var hint_lines: PackedStringArray = [
	"Nhìn kỹ dấu hiệu trên màn hình rồi canh đúng nhịp nghen!",
	"Đi câu giữ dạ cho bền, cá ăn động nước mới lên giật cần.",
	"Đã bật thanh canh thời điểm trực quan để hỗ trợ bạn!"
]
@export_multiline var instruction_text: String = ""

var params: Dictionary = {}
var fail_count: int = 0
var stuck_seconds: float = 0.0
var _f_reduction: float = 0.0
var highest_hint_tier: int = 0
var visual_aid_enabled: bool = false

var na_active_remaining: float = 0.0
var na_cooldown_remaining: float = 0.0
var restart_hold_progress: float = 0.0
var is_restarting: bool = false
var is_finished: bool = false
var is_paused_for_guide: bool = false
var _standalone_mode: bool = false
var _setup_called: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Nếu chạy riêng scene bằng F6 (không qua MinigameManager), tự khởi tạo với tham số mặc định.
	if get_tree().current_scene == self:
		_standalone_mode = true
		finished.connect(_on_standalone_finished)
		call_deferred("_auto_setup_if_needed")


func _auto_setup_if_needed() -> void:
	if not _setup_called:
		setup({})


## Khởi tạo mini-game với tham số từ MinigameManager hoặc mặc định.
func setup(p_params: Dictionary = {}) -> void:
	_setup_called = true
	params = p_params.duplicate()
	fail_count = 0
	stuck_seconds = 0.0
	_f_reduction = 0.0
	highest_hint_tier = 0
	visual_aid_enabled = false
	na_active_remaining = 0.0
	na_cooldown_remaining = 0.0
	restart_hold_progress = 0.0
	is_restarting = false
	is_finished = false
	_on_setup(params)


func _process(delta: float) -> void:
	if is_finished or is_restarting:
		return

	# Cập nhật thời gian giữ phím R (Làm lại màn: giữ 0,5 s)
	if Input.is_action_pressed(&"restart"):
		restart_hold_progress += delta
		if restart_hold_progress >= RESTART_HOLD_TIME:
			restart_hold_progress = 0.0
			restart()
			return
	else:
		restart_hold_progress = maxf(0.0, restart_hold_progress - delta * 2.0)

	# Cập nhật bộ đếm "Nhờ Na" (chu kỳ d_Na + hồi 15 s theo Bảng 62)
	if na_active_remaining > 0.0:
		na_active_remaining = maxf(0.0, na_active_remaining - delta)
		if na_active_remaining <= 0.0:
			_on_na_help_ended()
			na_help_ended.emit()
	elif na_cooldown_remaining > 0.0:
		na_cooldown_remaining = maxf(0.0, na_cooldown_remaining - delta)

	# Cập nhật thời gian bế tắc T_stuck khi đang chơi (không tính lúc đang mở bảng hướng dẫn)
	if not is_paused_for_guide and _should_accumulate_stuck_time():
		stuck_seconds += delta
		_check_adaptive_hints()

	_on_minigame_process(delta)


func _unhandled_input(event: InputEvent) -> void:
	if is_finished or is_restarting:
		return

	if event.is_action_pressed(&"show_hint"):
		get_viewport().set_input_as_handled()
		request_hint()
		return

	if event.is_action_pressed(&"call_na") and can_call_na and not is_paused_for_guide:
		get_viewport().set_input_as_handled()
		call_na()
		return


# --- Chỉ số bực bội F & Gợi ý thích ứng (Luật R6, Bảng 57–61) ----------------

## Giá trị F gốc trước khi trừ sau mỗi lần gợi ý: F_raw = N_fail + T_stuck / 30
func get_f_raw() -> float:
	return float(fail_count) + stuck_seconds / STUCK_DIVISOR


## Chỉ số bực bội F hiện tại (đã trừ 3 sau mỗi lần phát gợi ý)
func get_f_index() -> float:
	return maxf(0.0, get_f_raw() - _f_reduction)


## Hệ số nới dung sai thích ứng a_adapt = 0,05 * floor(F_raw / 3), tối đa 0,15 (Mục 5.7.3)
func get_adapt_bonus() -> float:
	return minf(0.15, 0.05 * floorf(get_f_raw() / 3.0))


## Hệ số chế độ hỗ trợ a_mode: +0,20 ("Nhẹ nhàng"), -0,10 ("Thử thách"), 0,0 (Chuẩn)
func get_mode_bonus() -> float:
	if bool(params.get("gentle_mode", false)) or GameState.has_flag("settings.gentle_mode"):
		return 0.20
	if bool(params.get("challenge_mode", false)):
		return -0.10
	return 0.0


## Dung sai hiệu dụng τ_eff = τ_0 * (1 + a_adapt + a_mode), tổng nới tối đa +35% (Bảng 61)
func get_effective_tolerance(base_tau: float) -> float:
	var factor := clampf(1.0 + get_adapt_bonus() + get_mode_bonus(), 0.90, 1.35)
	return base_tau * factor


## Gọi khi người chơi đạt một bước tiến triển (OnProgress - Bảng 59) → T_stuck về 0
func report_progress() -> void:
	stuck_seconds = 0.0
	progress_made.emit()


## Gọi khi người chơi thất bại một lượt (vd: cá thoát) → tăng N_fail và kiểm tra gợi ý
func report_fail() -> void:
	fail_count += 1
	fail_reported.emit(fail_count, get_f_index())
	_check_adaptive_hints()


## Đặt trực tiếp N_fail và T_stuck (phục vụ kiểm thử tự động GP-TC-09 & BAL-TC-04)
func set_frustration_state(p_fail_count: int, p_stuck_seconds: float = 0.0) -> void:
	fail_count = maxi(0, p_fail_count)
	stuck_seconds = maxf(0.0, p_stuck_seconds)
	_f_reduction = 0.0
	highest_hint_tier = 0
	visual_aid_enabled = false
	_check_adaptive_hints()


func _check_adaptive_hints() -> void:
	var f_raw := get_f_raw()
	# Kiểm tra ngưỡng cấp cao nhất vừa chạm tới (3 -> Cấp 1, 6 -> Cấp 2, 9 -> Cấp 3)
	var target_tier := 0
	if f_raw >= 9.0 and highest_hint_tier < 3:
		target_tier = 3
	elif f_raw >= 6.0 and highest_hint_tier < 2:
		target_tier = 2
	elif f_raw >= 3.0 and highest_hint_tier < 1:
		target_tier = 1

	if target_tier > 0:
		highest_hint_tier = target_tier
		_f_reduction += F_REDUCTION_PER_HINT
		if target_tier == 3:
			visual_aid_enabled = true
		var speaker := "Na"
		if target_tier == 2:
			speaker = "Ông Nội"
		elif target_tier == 3:
			speaker = "Gợi ý trực quan"
		var line := hint_lines[target_tier - 1] if target_tier - 1 < hint_lines.size() else ""
		_on_hint_triggered(target_tier, speaker, line)
		hint_shown.emit(target_tier, speaker, line)


# --- Hỗ trợ "Nhờ Na" (Luật R5, Bảng 62) ---------------------------------------

func can_trigger_na() -> bool:
	return can_call_na and na_active_remaining <= 0.0 and na_cooldown_remaining <= 0.0


## Bấm Space / nút X để nhờ Na hỗ trợ
func call_na() -> bool:
	if not can_trigger_na():
		return false
	na_active_remaining = na_duration
	na_cooldown_remaining = na_cooldown
	_on_na_help()
	na_help_triggered.emit(na_duration)
	return true


## Tỉ lệ thời gian Na hỗ trợ trên chu kỳ: d_Na / (d_Na + 15) ≤ 0,35 (Bảng 62)
func get_na_duty_ratio() -> float:
	return na_duration / (na_duration + na_cooldown)


# --- Làm lại & Hướng dẫn (Luật R2, Bảng 8) ------------------------------------

## Tái lập màn chơi trong ≤ 2 giây, không phạt tài nguyên
func restart() -> void:
	if is_restarting:
		return
	is_restarting = true
	await _on_restart()
	is_restarting = false
	restarted.emit()


## Mở / đóng hướng dẫn của màn (Phím H / Back)
func request_hint() -> void:
	_on_request_hint()


## Hoàn thành hoặc thoát mini-game, trả kết quả về MinigameManager
func finish(result: Dictionary) -> void:
	if is_finished:
		return
	is_finished = true
	finished.emit(result)


# --- Các hàm ảo để lớp con (FishingMinigame...) ghi đè ------------------------

func _on_setup(_p: Dictionary) -> void:
	pass

func _on_minigame_process(_delta: float) -> void:
	pass

func _should_accumulate_stuck_time() -> bool:
	return true

func _on_na_help() -> void:
	pass

func _on_na_help_ended() -> void:
	pass

func _on_hint_triggered(_tier: int, _speaker: String, _text: String) -> void:
	pass

func _on_request_hint() -> void:
	pass

func _on_restart() -> void:
	pass


func _on_standalone_finished(result: Dictionary) -> void:
	print("[MinigameBase] '%s' kết thúc (chạy độc lập F6): %s" % [minigame_id, JSON.stringify(result)])
