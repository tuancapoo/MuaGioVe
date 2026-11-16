extends CanvasLayer
## Thông báo nhỏ góc trên phải: "Đã nhận: Cái kẹp"…
## Ai cũng gọi được: EventBus.toast_requested.emit("…")

const FONT := preload("res://assets/fonts/vt323_regular.ttf")
const SHOW_TIME := 2.5

var _box: VBoxContainer
var _root: Control


func _ready() -> void:
	layer = 60
	_box = VBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_box.add_theme_constant_override(&"separation", 10)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.add_child(_box)
	EventBus.toast_requested.connect(show_toast)


func show_toast(text: String) -> void:
	var panel := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.07, 0.06, 0.1, 0.88)
	s.border_color = Color(0.96, 0.78, 0.35)
	s.set_border_width_all(3)
	s.set_corner_radius_all(8)
	s.content_margin_left = 22; s.content_margin_right = 22
	s.content_margin_top = 6; s.content_margin_bottom = 8
	panel.add_theme_stylebox_override(&"panel", s)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override(&"font", FONT)
	l.add_theme_font_size_override(&"font_size", 42)
	l.add_theme_color_override(&"font_color", Color(1, 0.97, 0.88))
	panel.add_child(l)
	panel.modulate.a = 0.0
	_box.add_child(panel)
	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	tw.tween_interval(SHOW_TIME)
	tw.tween_property(panel, "modulate:a", 0.0, 0.4)
	tw.tween_callback(panel.queue_free)


func _process(_d: float) -> void:
	# Giữ sát góc trên phải
	_box.reset_size()
	_box.position = Vector2(_root.size.x - _box.size.x - 40, 40)
