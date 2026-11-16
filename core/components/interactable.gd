class_name Interactable
extends Area2D
## Vùng có thể tương tác (NPC, vật phẩm, cửa, vòi nước…).
## Gắn node này làm con của đối tượng, thêm CollisionShape2D cho nó.
## Player sẽ tự phát hiện (qua InteractionArea) và gọi interact() khi nhấn E.
##
## Hai kiểu:
## - `actions` RỖNG (cửa, cổng…): bấm E → phát `interacted` ngay.
## - `actions` CÓ (vd ["examine", "take"] cho vật, ["talk"] cho NPC): bấm E → mở THANH CHỌN
##   một hàng trên đầu Minh (ui/action_wheel): các hành động trước, sau đó là từng món trong túi đồ.
##   Chọn xong → phát `action_chosen(action, player, item_id)`:
##     action = "examine" | "talk" | "take"          (item_id rỗng)
##     action = "use_item"                           (item_id = món được chọn để dùng / đưa)

signal interacted(player: Node)
signal action_chosen(action: StringName, player: Node, item_id: StringName)

## Thứ tự trên thanh chọn
const ACTION_ORDER: Array[StringName] = [&"examine", &"talk", &"take"]
const ACTION_NAMES := {&"talk": "Nói chuyện", &"examine": "Xem", &"take": "Nhặt"}

## Chữ hiện trong lời nhắc, ví dụ "Nói chuyện", "Nhặt", "Mở van".
@export var prompt_text: String = "Tương tác"
## Vị trí lời nhắc so với node này (thường là trên đầu nhân vật).
@export var prompt_offset: Vector2 = Vector2(0, -70)
## Hành động có trên thanh chọn. Rỗng = bấm E là làm ngay (không mở thanh chọn).
@export var actions: Array[StringName] = []
## Thêm các món trong túi đồ vào thanh chọn (dùng / đưa đồ cho đối tượng này)
@export var show_items: bool = true
## Tắt khi không muốn cho tương tác nữa (vd. đã nhặt đồ).
@export var enabled: bool = true:
	set(value):
		enabled = value
		set_deferred("monitorable", value)

## Cho phép đối tượng cha quyết định thêm (vd. "take" chỉ khi chưa nhặt). Trả true = được.
var action_filter: Callable


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1 << 3 # layer 4 "interactable"
	collision_mask = 0
	monitoring = false


func interact(player: Node) -> void:
	if not enabled:
		return
	if actions.is_empty():
		interacted.emit(player)
		return
	var bar := get_tree().get_first_node_in_group(&"action_wheel")
	if bar:
		bar.open(self, player)
	else:
		# Chưa có thanh chọn (vd. đang test scene riêng) → làm hành động đầu tiên làm được
		var list := available_actions()
		if not list.is_empty():
			choose(list[0], player)


## Các hành động làm được lúc này, đúng thứ tự trên thanh chọn.
func available_actions() -> Array[StringName]:
	var out: Array[StringName] = []
	for a in ACTION_ORDER:
		if actions.has(a) and (not action_filter.is_valid() or action_filter.call(a)):
			out.append(a)
	return out


## Thanh chọn gọi khi người chơi chọn xong.
func choose(action: StringName, player: Node, item_id: StringName = &"") -> void:
	action_chosen.emit(action, player, item_id)
