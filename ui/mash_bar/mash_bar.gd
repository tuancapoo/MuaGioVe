extends CanvasLayer
## Thanh "bấm E liên tục" hiện trên đầu Minh (group "mash_bar"; Main tạo sẵn 1 node).
## Dùng khi cần gom đủ lực mới làm được việc gì đó — vd hái quả dưa:
##
##     var bar := get_tree().get_first_node_in_group(&"mash_bar")
##     var ok: bool = await bar.run(player, 10)     # cần ~10 lần bấm E
##     if ok: ...nhặt được...
##
## - Mỗi lần bấm E thanh tăng 1/presses; không bấm thì tụt dần.
## - Đầy thanh → trả về true.
## - Minh di chuyển (A/D, mũi tên) hoặc bấm Esc → huỷ, trả về false.
## Trong lúc kéo, phím E chỉ dùng cho thanh này (không mở thanh chọn / tương tác khác).

signal finished(success: bool)

const FONT := preload("res://assets/fonts/vt323_regular.ttf")
const PRESS_SOUNDS := [
	preload("res://assets/audio/sfx/typing/key_01.wav"),
	preload("res://assets/audio/sfx/typing/key_02.wav"),
	preload("res://assets/audio/sfx/typing/key_03.wav"),
]

## Chữ hướng dẫn trên thanh
@export var hint_text: String = "Bấm E liên tục!"
## Thanh tụt bao nhiêu lần-bấm mỗi giây khi không bấm (vd 1.6 → phải bấm nhanh hơn ~1.6 lần/giây)
@export var decay_presses_per_sec: float = 1.6
## Thanh nằm cao hơn gốc toạ độ của Minh bao nhiêu (px thế giới)
@export var head_offset: Vector2 = Vector2(0, -80)
@export var bar_size: Vector2 = Vector2(260, 26)

var running: bool = false
var _player: Node2D
var _value := 0.0          # 0..1
var _step := 0.1           # tăng mỗi lần bấm
var _start_x := 0.0
var _shake := 0.0

var _root: Control
var _panel: PanelContainer
var _label: Label
var _back: Panel
var _fill: Panel
var _sfx: AudioStreamPlayer


func _ready() -> void:
	layer = 75
	add_to_group(&"mash_bar")
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override(&"panel", _box(Color(0.07, 0.06, 0.1, 0.9), Color(0.98, 0.95, 0.85), 3, 10, 14))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override(&"separation", 4)
	_panel.add_child(vb)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_override(&"font", FONT)
	_label.add_theme_font_size_override(&"font_size", 38)
	_label.add_theme_color_override(&"font_color", Color(0.98, 0.95, 0.85))
	vb.add_child(_label)
	_back = Panel.new()
	_back.custom_minimum_size = bar_size
	_back.add_theme_stylebox_override(&"panel", _box(Color(0.17, 0.14, 0.25), Color(0.98, 0.95, 0.85), 3, 6, 0))
	vb.add_child(_back)
	_fill = Panel.new()
	_fill.add_theme_stylebox_override(&"panel", _box(Color(0.67, 0.81, 0.22), Color(0, 0, 0, 0), 0, 4, 0))
	_fill.position = Vector2(4, 4)
	_back.add_child(_fill)

	_sfx = AudioStreamPlayer.new()
	_sfx.volume_db = -10.0
	add_child(_sfx)
	hide()


## Bắt đầu kéo. presses = số lần bấm E (nhanh) để đầy thanh. Trả về true nếu đủ lực.
func run(player: Node2D, presses: int = 10) -> bool:
	if running:
		return false
	_player = player
	_step = 1.0 / maxi(presses, 1)
	_value = 0.0
	_start_x = player.global_position.x
	_label.text = hint_text
	running = true
	_refresh()
	show()
	var ok: bool = await finished
	return ok


func _input(event: InputEvent) -> void:
	if not running:
		return
	if event.is_action_pressed(&"interact") and not event.is_echo():
		_value = minf(1.0, _value + _step)
		_shake = 1.0
		_sfx.stream = PRESS_SOUNDS.pick_random()
		_sfx.pitch_scale = 0.8 + _value * 0.5
		_sfx.play()
		get_viewport().set_input_as_handled()
		if _value >= 1.0:
			_end(true)
	elif event.is_action_pressed(&"cancel") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_end(false)


func _process(delta: float) -> void:
	if not running:
		return
	if not is_instance_valid(_player):
		_end(false)
		return
	# Di chuyển là huỷ
	var moving := Input.get_axis(&"move_left", &"move_right") != 0.0
	if moving or absf(_player.global_position.x - _start_x) > 3.0:
		_end(false)
		return
	_value = maxf(0.0, _value - decay_presses_per_sec * _step * delta)
	_shake = maxf(0.0, _shake - delta * 8.0)
	_refresh()


func _refresh() -> void:
	var inner := bar_size - Vector2(8, 8)
	_fill.size = Vector2(maxf(0.0, inner.x * _value), inner.y)
	_fill.visible = _value > 0.0
	if not is_instance_valid(_player):
		return
	var center: Vector2 = _player.get_viewport().get_canvas_transform() * (_player.global_position + head_offset)
	_panel.reset_size()
	var jitter := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 3.0 * _shake
	_panel.position = center - Vector2(_panel.size.x * 0.5, _panel.size.y) + jitter


func _end(success: bool) -> void:
	running = false
	if success:
		_label.text = "Được rồi!"
		_value = 1.0
	else:
		_label.text = "Thôi…"
	_refresh()
	finished.emit(success)
	# Giữ thanh thêm một chút cho người chơi thấy kết quả
	await get_tree().create_timer(0.35).timeout
	if not running:
		hide()


static func _box(bg: Color, border: Color, bw: int, radius: int, pad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad; s.content_margin_right = pad
	s.content_margin_top = pad * 0.4; s.content_margin_bottom = pad * 0.5
	s.anti_aliasing = false
	return s
