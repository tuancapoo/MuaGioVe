extends Node2D
## Icon dấu hỏi nổi phía trên đối tượng tương tác gần nhất.
## Đặt làm con của Player (top_level = true để không di chuyển theo Player).

var _target: Node2D = null


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
