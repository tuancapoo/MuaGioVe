extends Node
## Autoload "EventBus": các SỰ KIỆN dùng chung toàn game.
##
## - Sự kiện = "vừa xảy ra một việc" (vừa nhặt đồ, vừa đổi map, minigame vừa xong).
##   UI, âm thanh, quest nghe ở đây mà không cần biết ai phát.
## - TRẠNG THÁI (cờ, quest, túi đồ, NPC…) vẫn chỉ nằm trong GameState;
##   muốn biết trạng thái đổi thì nghe GameState.changed.
##
## Thêm signal mới phải báo cả nhóm (xem docs/KIEN_TRUC.md).

## Người chơi vừa tương tác (bấm E) với một đối tượng.
signal interacted(target: Node)
## Vừa nhặt được vật phẩm.
signal item_collected(item_id: StringName)
## Vừa đưa / dùng mất vật phẩm.
signal item_removed(item_id: StringName)
## Nhiệm vụ vừa đổi trạng thái ("active" / "done").
signal quest_changed(quest_id: String, state: String)
## Vừa vào map mới (sau khi đặt xong Player).
signal map_changed(map_id: String)
## Minigame vừa kết thúc. result: { "success": bool, "score": int, ... }
signal minigame_finished(minigame_id: String, result: Dictionary)
## Cần hiện thông báo nhỏ (toast) ở góc màn hình.
signal toast_requested(text: String)
