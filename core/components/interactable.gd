class_name Interactable
extends Area2D
## Vùng có thể tương tác (NPC, vật phẩm, cửa, vòi nước…).
## Gắn node này làm con của đối tượng, thêm CollisionShape2D cho nó.
## Player sẽ tự phát hiện (qua InteractionArea) và gọi interact() khi nhấn E.

signal interacted(player: Node)

## Chữ hiện trong lời nhắc, ví dụ "Nói chuyện", "Nhặt", "Mở van".
@export var prompt_text: String = "Tương tác"
## Vị trí lời nhắc so với node này (thường là trên đầu nhân vật).
@export var prompt_offset: Vector2 = Vector2(0, -70)
## Tắt khi không muốn cho tương tác nữa (vd. đã nhặt đồ).
@export var enabled: bool = true:
	set(value):
		enabled = value
		set_deferred("monitorable", value)


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1 << 3 # layer 4 "interactable"
	collision_mask = 0
	monitoring = false


func interact(player: Node) -> void:
	if enabled:
		interacted.emit(player)
