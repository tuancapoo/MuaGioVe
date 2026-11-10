extends "res://core/components/interactable.gd"
## Cửa / cổng / cầu thang: đứng gần bấm E để sang map khác.
## Đặt trong "Exits/" của map, thêm CollisionShape2D phủ vùng cửa.
## prompt_text (kế thừa từ Interactable): "Vào nhà", "Ra sân", "Xuống bờ mương"…

## map_id đích, vd "living_room"
@export var target_map: String = ""
## Tên Marker2D trong "Spawns/" của map đích, vd "from_yard"
@export var target_spawn: String = ""
## Biểu thức GameState; sai thì không cho đi (rỗng = luôn đi được)
@export var condition: String = ""
## Câu thông báo khi chưa đi được (hiện bằng toast)
@export var locked_text: String = ""


func interact(_player: Node) -> void:
	if not enabled or SceneManager.is_busy():
		return
	if not GameState.check(condition):
		if not locked_text.is_empty():
			EventBus.toast_requested.emit(locked_text)
		return
	interacted.emit(_player)
	SceneManager.change_map(target_map, target_spawn)
