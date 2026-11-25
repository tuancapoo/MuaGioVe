extends MinigameBase
## Tưới rau: giữ chuột trái và rê vòi nước qua ba luống.
## Chỉ khi cả ba luống đủ nước mới hoàn thành quest fix_pipe.

const FONT: Font = preload("res://assets/fonts/vt323_regular.ttf")
const BOARD := Vector2(640.0, 360.0)
const BEDS := [
	Rect2(50, 158, 160, 105),
	Rect2(240, 158, 160, 105),
	Rect2(430, 158, 160, 105)
]
const WATER_SECONDS_PER_BED := 2.7

var levels: Array[float] = [0.0, 0.0, 0.0]
var time_elapsed: float = 0.0
var guide_open: bool = false
var paused: bool = false
var win_shown: bool = false

@onready var guide_overlay: Control = $GuideOverlay
@onready var start_button: Button = $GuideOverlay/Panel/VBox/StartButton
@onready var win_overlay: Control = $WinOverlay
@onready var win_button: Button = $WinOverlay/Panel/VBox/WinButton
@onready var pause_overlay: Control = $PauseOverlay
@onready var continue_button: Button = $PauseOverlay/Panel/VBox/ContinueButton
@onready var exit_button: Button = $PauseOverlay/Panel/VBox/ExitButton
@onready var quick_exit_button: Button = $QuickExitButton


func _ready() -> void:
	minigame_id = "water_garden"
	minigame_title = "Tưới rau"
	can_call_na = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	super._ready()
	start_button.pressed.connect(_close_guide)
	win_button.pressed.connect(_finish_success)
	continue_button.pressed.connect(_close_pause)
	exit_button.pressed.connect(_exit_without_reward)
	quick_exit_button.pressed.connect(_exit_without_reward)
	guide_overlay.hide()
	win_overlay.hide()
	pause_overlay.hide()
	queue_redraw()


func _on_setup(_p: Dictionary) -> void:
	levels = [0.0, 0.0, 0.0]
	time_elapsed = 0.0
	paused = false
	win_shown = false
	if is_node_ready():
		quick_exit_button.show()
		win_overlay.hide()
		pause_overlay.hide()
		_show_guide(not GameState.has_flag("minigame.water_garden.seen_guide"))
	queue_redraw()


func _on_minigame_process(delta: float) -> void:
	if guide_open or paused or win_shown:
		return
	time_elapsed += delta
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var cursor := _to_board()
		for i in range(BEDS.size()):
			if BEDS[i].has_point(cursor) and levels[i] < 1.0:
				levels[i] = minf(1.0, levels[i] + delta / WATER_SECONDS_PER_BED)
				if levels[i] >= 1.0:
					report_progress()
				break
	if _all_watered():
		_show_win()
	queue_redraw()


func _all_watered() -> bool:
	for level in levels:
		if level < 1.0:
			return false
	return true


func _screen_scale() -> float:
	return minf(size.x / BOARD.x, size.y / BOARD.y)


func _to_board() -> Vector2:
	var scale_factor := maxf(_screen_scale(), 0.001)
	return (get_local_mouse_position() - (size - BOARD * scale_factor) * 0.5) / scale_factor


func _show_guide(show_it: bool) -> void:
	guide_open = show_it
	is_paused_for_guide = show_it
	guide_overlay.visible = show_it
	if show_it:
		GameState.set_flag("minigame.water_garden.seen_guide", true)
		start_button.grab_focus()


func _close_guide() -> void:
	_show_guide(false)
	start_button.release_focus()


func _close_pause() -> void:
	paused = false
	pause_overlay.hide()
	continue_button.release_focus()


func _exit_without_reward() -> void:
	if is_finished or win_shown:
		return
	finish({"success": false, "aborted": true, "wind_seeds": 0, "flawless": false})


func _on_request_hint() -> void:
	if not win_shown:
		_show_guide(true)


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


func _show_win() -> void:
	if win_shown or is_finished:
		return
	win_shown = true
	# Đây là nơi DUY NHẤT hoàn thành nhiệm vụ và cộng 3 Hạt Gió.
	GameState.finish_garden_watering()
	quick_exit_button.hide()
	win_overlay.show()
	win_button.grab_focus()
	queue_redraw()


func _finish_success() -> void:
	if is_finished:
		return
	finish({"success": true, "score": 100, "wind_seeds": 0, "flawless": false})


func _on_restart() -> void:
	if win_shown:
		return
	levels = [0.0, 0.0, 0.0]
	time_elapsed = 0.0
	queue_redraw()


func _paint(rect: Rect2, color: Color) -> void:
	draw_rect(rect, color)


func _txt(value: String, pos: Vector2, font_size: int = 20, color: Color = Color("fff1d0")) -> void:
	draw_string(FONT, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_plant(x: float, y: float, growth: float, variant: int) -> void:
	var stem := Color("376f42")
	var leaf := Color("4a994f") if variant % 2 == 0 else Color("6eac53")
	var height := 11.0 + growth * 12.0
	_paint(Rect2(x - 2, y - height, 4, height), stem)
	_paint(Rect2(x - 12, y - height + 4, 11, 6), leaf)
	_paint(Rect2(x + 2, y - height + 1, 12, 7), leaf)
	_paint(Rect2(x - 6, y - height - 4, 12, 7), Color("88bc58"))


func _draw_bed(i: int) -> void:
	var rect: Rect2 = BEDS[i]
	var level: float = levels[i]
	_paint(Rect2(rect.position + Vector2(0, 24), Vector2(rect.size.x, rect.size.y - 24)), Color("69482e"))
	_paint(Rect2(rect.position + Vector2(5, 30), Vector2(rect.size.x - 10, rect.size.y - 35)), Color("8b6036"))
	for line in range(4):
		_paint(Rect2(rect.position + Vector2(10, 41 + line * 13), Vector2(rect.size.x - 20, 3)), Color("5b3b29"))
	for plant in range(4):
		_draw_plant(rect.position.x + 23 + plant * 37, rect.position.y + 70, level, i + plant)
	# Chữ nằm phía trên thanh tiến độ
	_txt(
		"LUỐNG %d  %d%%" % [i + 1, roundi(level * 100.0)],
		rect.position + Vector2(18, -5),
		18
	)

	# Nền thanh tiến độ
	_paint(
		Rect2(rect.position + Vector2(5, 5), Vector2(rect.size.x - 10, 12)),
		Color("182c34")
	)

	# Phần nước đã tưới
	_paint(
		Rect2(rect.position + Vector2(8, 8), Vector2((rect.size.x - 16) * level, 6)),
		Color("4bb9d5")
	)
	if level >= 1.0:
		_txt("ĐỦ NƯỚC!", rect.position + Vector2(40, 96), 22, Color("b9f3ae"))


func _draw() -> void:
	var s := _screen_scale()
	var offset := (size - BOARD * s) * 0.5
	draw_set_transform(offset, 0.0, Vector2(s, s))
	# Khung cảnh vườn rau pixel art, không cần PNG bổ sung.
	_paint(Rect2(0, 0, 640, 360), Color("b5d4bf"))
	for i in range(13):
		_paint(Rect2(i * 52, 68 + (i % 3) * 11, 22, 5), Color("a3c7b1"))
	_paint(Rect2(0, 127, 640, 143), Color("8db47b"))
	for i in range(18):
		_paint(Rect2(i * 37, 130 + (i % 3) * 8, 13, 6), Color("6e9d69"))
	_paint(Rect2(0, 264, 640, 96), Color("6b8a5b"))
	for i in range(3):
		_draw_bed(i)
	# Vòi tưới pixel nằm ở góc trái, hướng về vị trí chuột.
	_paint(Rect2(8, 106, 39, 18), Color("2e5768"))
	_paint(Rect2(35, 111, 18, 8), Color("7b9c9d"))
	_paint(Rect2(50, 107, 15, 16), Color("456f7d"))
	if not guide_open and not paused and not win_shown:
		var p := _to_board()
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			for i in range(BEDS.size()):
				if BEDS[i].has_point(p) and levels[i] < 1.0:
					for j in range(8):
						var fall := fmod(time_elapsed * 90.0 + j * 19.0, 56.0)
						_paint(Rect2(p.x - 10 + j * 3, p.y - 48 + fall, 3, 7), Color("3ab4dc"))
					break
	_paint(Rect2(0, 0, 640, 50), Color("17292ddf"))
	_txt("TƯỚI RAU", Vector2(20, 33), 32, Color("f7d47d"))
	_paint(Rect2(0, 304, 640, 70), Color("17292da8"))
	_txt("Giữ CHUỘT TRÁI và rê qua từng luống để tưới", Vector2(25, 321), 17)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
