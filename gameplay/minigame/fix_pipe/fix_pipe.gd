extends MinigameBase
## Sửa ống nước — minigame pixel 640x360 giống hệ thống Fishing.
## Click tháo ống hỏng; kéo ống mới -> vòng cao su -> kẹp.
## Hoàn tất: đánh dấu đã sửa ống; nói chuyện với Ông Nội để bắt đầu tưới rau.

const FONT: Font = preload("res://assets/fonts/vt323_regular.ttf")
const BG: Texture2D = preload("res://assets/minigames/fix_pipe/pipe_background_clean.png")
const B_SIZE := Vector2(640.0, 360.0)
const PIPE_AREA := Rect2(312, 143, 85, 54)
const DROP := Rect2(307, 143, 95, 54)
const TRAYS := [
	Rect2(55, 278, 140, 52),
	Rect2(250, 278, 140, 52),
	Rect2(445, 278, 140, 52)
]
const TASKS := [
	"1/4  Nhấp vào đoạn ống nứt để tháo bỏ",
	"2/4  Kéo ỐNG MỚI vào vị trí ống hỏng",
	"3/4  Kéo VÒNG CAO SU vào mối nối",
	"4/4  Kéo CÁI KẸP để siết chặt đường ống",
	"Hoàn tất! Đường ống đã hết rò rỉ!"
]
const NAMES := ["ỐNG MỚI", "VÒNG CAO SU", "CÁI KẸP"]

var phase: int = 0
var drag_index: int = -1
var mouse_at: Vector2 = Vector2.ZERO
var elapsed: float = 0.0
var win_shown: bool = false
var guide_open: bool = true
var paused: bool = false

@onready var guide_overlay: Control = $GuideOverlay
@onready var start_button: Button = $GuideOverlay/Panel/VBox/StartButton
@onready var win_overlay: Control = $WinOverlay
@onready var win_button: Button = $WinOverlay/Panel/VBox/WinButton
@onready var pause_overlay: Control = $PauseOverlay
@onready var continue_button: Button = $PauseOverlay/Panel/VBox/ContinueButton
@onready var exit_button: Button = $PauseOverlay/Panel/VBox/ExitButton
@onready var quick_exit_button: Button = $QuickExitButton


func _ready() -> void:
	minigame_id = "fix_pipe"
	minigame_title = "Sửa ống nước"
	can_call_na = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	super._ready()
	start_button.pressed.connect(_close_guide)
	win_button.pressed.connect(_finish_success)
	continue_button.pressed.connect(_close_pause)
	exit_button.pressed.connect(_exit_without_reward)
	quick_exit_button.pressed.connect(_exit_without_reward)
	guide_overlay.hide()
	guide_open = false
	win_overlay.hide()
	pause_overlay.hide()
	queue_redraw()


func _on_setup(_p: Dictionary) -> void:
	phase = 0
	drag_index = -1
	elapsed = 0.0
	win_shown = false
	paused = false
	if is_node_ready():
		quick_exit_button.show()
		win_overlay.hide()
		pause_overlay.hide()
		_show_guide(not GameState.has_flag("minigame.fix_pipe.seen_guide"))
	queue_redraw()


func _on_minigame_process(delta: float) -> void:
	if guide_open or paused:
		return
	elapsed += delta
	queue_redraw()


func _on_request_hint() -> void:
	_show_guide(true)


func _show_guide(show_it: bool) -> void:
	guide_open = show_it
	guide_overlay.visible = show_it
	if show_it:
		GameState.set_flag("minigame.fix_pipe.seen_guide", true)
		start_button.grab_focus()
	queue_redraw()


func _close_guide() -> void:
	_show_guide(false)
	start_button.release_focus()


func _close_pause() -> void:
	paused = false
	pause_overlay.hide()
	continue_button.release_focus()


func _exit_without_reward() -> void:
	if is_finished or win_shown or phase >= 4:
		return
	finish({"success": false, "aborted": true, "wind_seeds": 0, "flawless": false})


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if win_shown:
			return
		if guide_open:
			_close_guide()
		else:
			paused = not paused
			pause_overlay.visible = paused
			if paused:
				continue_button.grab_focus()
		get_viewport().set_input_as_handled()
		return
	if win_shown and event.is_action_pressed("ui_accept"):
		_finish_success()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


func _screen_scale() -> float:
	return minf(size.x / B_SIZE.x, size.y / B_SIZE.y)


func _to_board() -> Vector2:
	var s := _screen_scale()
	return (get_local_mouse_position() - (size - B_SIZE * s) * 0.5) / maxf(s, 0.001)


func _gui_input(event: InputEvent) -> void:
	if guide_open or paused or win_shown or is_finished:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var p := _to_board()
		if event.pressed:
			if phase == 0 and PIPE_AREA.has_point(p):
				phase = 1
				report_progress()
				queue_redraw()
				accept_event()
			elif phase >= 1 and phase <= 3 and TRAYS[phase - 1].has_point(p):
				drag_index = phase - 1
				mouse_at = p
				queue_redraw()
				accept_event()
		elif drag_index >= 0:
			var selected := drag_index
			drag_index = -1
			if selected == phase - 1 and DROP.has_point(p):
				phase += 1
				report_progress()
				if phase == 4:
					_show_win()
			else:
					report_fail()
			queue_redraw()
			accept_event()
	elif event is InputEventMouseMotion and drag_index >= 0:
		mouse_at = _to_board()
		queue_redraw()
		accept_event()


func _show_win() -> void:
	if win_shown or is_finished:
		return
	# Dùng 3 bộ phận sửa ống trong túi (nếu còn) và ghi nhận đã sửa xong đường ống.
	for item_id: String in ["pipe_connector", "rubber_ring", "pipe_clamp"]:
		if GameState.has_item(item_id):
			GameState.remove_item(item_id, 1)
		GameState.set_flag("pipe_delivered." + item_id, true)
	# Chỉ ghi nhận đã sửa ống; CHƯA hoàn thành quest hay nhận Hạt Gió.
	GameState.set_flag("ch1.pipe_fixed", true)
	win_shown = true
	quick_exit_button.hide()
	win_overlay.show()
	win_button.grab_focus()
	queue_redraw()


func _finish_success() -> void:
	if is_finished:
		return
	# Trả về vườn; Minh nói chuyện với Ông Nội để bắt đầu tưới rau.
	finish({"success": true, "score": 100, "wind_seeds": 0, "flawless": false})


func _paint(r: Rect2, c: Color) -> void:
	draw_rect(r, c)


func _txt(s: String, at: Vector2, font_size: int = 18, color: Color = Color("fff0c9")) -> void:
	draw_string(FONT, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _pipe_piece(r: Rect2) -> void:
	_paint(r, Color("172632"))
	_paint(r.grow(-3), Color("566979"))
	_paint(Rect2(r.position + Vector2(4, 5), Vector2(r.size.x - 8, 5)), Color("aabac6"))
	_paint(Rect2(r.position + Vector2(4, r.size.y - 9), Vector2(r.size.x - 8, 5)), Color("2b4250"))


func _part(i: int, p: Vector2) -> void:
	match i:
		0: # Ống mới
			_pipe_piece(Rect2(p + Vector2(0, 9), Vector2(55, 24)))
			_paint(Rect2(p + Vector2(0, 5), Vector2(6, 32)), Color("a8bdc3"))
			_paint(Rect2(p + Vector2(49, 5), Vector2(6, 32)), Color("a8bdc3"))
		1: # Vòng cao su
			draw_arc(p + Vector2(28, 21), 14, 0, TAU, 32, Color("17202c"), 8, true)
			draw_arc(p + Vector2(28, 21), 14, 0, TAU, 32, Color("8098a7"), 2, true)
		2: # Kẹp
			draw_rect(Rect2(p + Vector2(7, 8), Vector2(42, 27)), Color("f3c573"), false, 6)
			_paint(Rect2(p + Vector2(23, 3), Vector2(11, 8)), Color("ffe2a2"))


func _draw() -> void:
	var s := _screen_scale()
	var offset := (size - B_SIZE * s) * 0.5
	draw_set_transform(offset, 0.0, Vector2(s, s))
	draw_texture_rect(BG, Rect2(Vector2.ZERO, B_SIZE), false)

	# Phần ống tháo lắp thực sự tách khỏi background.
	if phase == 0:
		_pipe_piece(Rect2(312, 149, 85, 41))
		_paint(Rect2(348, 154, 5, 20), Color("d8edf7"))
		_paint(Rect2(353, 161, 4, 13), Color("1c2835"))
		_paint(Rect2(347, 170, 5, 17), Color("a4dce9"))
		for j in range(3):
			var dy := fmod(elapsed * 29.0 + j * 17.0, 36.0)
			_paint(Rect2(344 + j * 5, 188 + dy, 4, 6), Color("36c7ed"))
	elif phase >= 2:
		_pipe_piece(Rect2(312, 149, 85, 41))
		if phase >= 3:
			_paint(Rect2(315, 145, 8, 47), Color("202632"))
			_paint(Rect2(317, 146, 4, 45), Color("8fa0a3"))
		if phase >= 4:
			_paint(Rect2(379, 145, 11, 47), Color("182633"))
			_paint(Rect2(382, 148, 5, 41), Color("b3c5c7"))
	# Bước 1: nền trống sẽ hiện ở vùng đã tháo.
	if phase == 1:
		draw_rect(DROP, Color("ffd57a"), false, 2)
		_txt("LẮP Ở ĐÂY", Vector2(321, 137), 16, Color("725525"))

	_paint(Rect2(0, 0, 640, 48), Color("17262bd9"))
	_txt("SỬA ỐNG NƯỚC", Vector2(19, 31), 29, Color("f3c96b"))
	_paint(Rect2(0, 245, 640, 115), Color("15272aaf"))
	_txt(TASKS[phase], Vector2(26, 268), 16, Color("f7e7c3"))

	for i in range(3):
		var r: Rect2 = TRAYS[i]
		_paint(r, Color("172c35"))
		draw_rect(r, Color("eed08b") if phase == i + 1 else Color("667877"), false, 2)
		if drag_index != i:
			_part(i, r.position + Vector2(5, 0))
		_txt(NAMES[i], r.position + Vector2(60, 26), 13,
			Color("ffe39c") if phase == i + 1 else Color("b8bdba"))
		if phase > i + 1:
			_paint(Rect2(r.position + Vector2(110, 6), Vector2(15, 15)), Color("55b66a"))
	if drag_index >= 0:
		_part(drag_index, mouse_at - Vector2(28, 20))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
