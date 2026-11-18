class_name MinigameSpot
extends Interactable
## Điểm kích hoạt mini-game trên bản đồ (ví dụ: Câu cá bên mương ở bo_muong_chan_de).
## Bấm E (hoặc nút A tay cầm) để bắt đầu mini-game.

@export var minigame_id: String = "fishing"
@export var target_count: int = 5
@export var challenge_mode: bool = false
## Điều kiện để điểm này hiện / cho phép chơi (rỗng = luôn cho phép)
@export var active_when: String = ""
## Câu thoại khi chưa đủ điều kiện mở
@export_multiline var locked_text: String = "Minh: (Lát nữa rảnh mình quay lại đây sau.)"


func _ready() -> void:
	super._ready()
	actions = []
	show_items = false
	interacted.connect(_on_interacted)
	GameState.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var ok := GameState.check(active_when)
	visible = ok
	enabled = ok


func _on_interacted(_player: Node) -> void:
	if not GameState.check(active_when):
		if not locked_text.strip_edges().is_empty():
			var res = DialogueManager.create_resource_from_text("~ start\n" + locked_text.strip_edges() + "\n=> END\n")
			DialogueManager.show_dialogue_balloon(res, "start")
		return

	var params := {
		"target": target_count,
		"challenge_mode": challenge_mode,
	}
	MinigameManager.start(minigame_id, params)
