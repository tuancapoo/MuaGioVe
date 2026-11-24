extends Interactable
## Cửa phòng Chương 0: dùng icon mũi tên ra cửa thay cho dấu "?".

const DOOR_OUT_ICON := preload("res://assets/ui/icons/door_out.png")


func get_prompt_icon() -> Texture2D:
	return DOOR_OUT_ICON
