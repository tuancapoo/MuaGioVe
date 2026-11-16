extends Node2D
## Icon nổi phía trên đối tượng tương tác gần nhất.
## - NPC / vật: dấu hỏi "?".
## - Cửa / lối chuyển map (có hàm get_prompt_icon()): bong bóng icon cửa / mũi tên.
## Đặt làm con của Player (top_level = true để không di chuyển theo Player).

const QUESTION := preload("res://assets/ui/question.png")
## Phóng to bong bóng pixel art của cửa (ảnh gốc 22x25)
const DOOR_ICON_SCALE := 2.0

var _target: Node2D = null
@onready var _icon: Sprite2D = $QuestionIcon
@onready var _question_scale: Vector2 = _icon.scale


func _ready() -> void:
	top_level = true
	visible = false
	var player := get_parent()
	if player.has_signal("interactable_changed"):
		player.interactable_changed.connect(_on_interactable_changed)


func _on_interactable_changed(target: Node) -> void:
	_target = target as Node2D
	if _target == null:
		visible = false
		return
	if _target.has_method("get_prompt_icon"):
		_icon.texture = _target.get_prompt_icon()
		_icon.scale = Vector2.ONE * DOOR_ICON_SCALE
		# Đuôi bong bóng chỉ đúng vào điểm prompt_offset
		_icon.position = Vector2(0, -_icon.texture.get_height() * DOOR_ICON_SCALE * 0.5)
	else:
		_icon.texture = QUESTION
		_icon.scale = _question_scale
		_icon.position = Vector2.ZERO
	visible = true
	_follow()


func _process(_delta: float) -> void:
	if visible:
		_follow()


func _follow() -> void:
	if not is_instance_valid(_target):
		visible = false
		return
	var offset: Vector2 = _target.get("prompt_offset") if _target.get("prompt_offset") != null else Vector2(0, -70)
	global_position = _target.global_position + offset
