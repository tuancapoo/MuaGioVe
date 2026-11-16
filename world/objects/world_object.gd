extends Node2D
## Vật trong map có thể Xem / Nhặt / dùng đồ lên (qua thanh chọn trên đầu Minh).
## Thanh chọn: [Xem] [Nhặt] rồi tới từng món trong túi đồ (chọn món = dùng món đó lên vật này).
## Điền trong Inspector, KHÔNG cần code:
##   - Examine Text     : câu Minh nói khi Xem (mỗi dòng 1 câu; "Tên: câu" để người khác nói)
##   - Take Item        : id vật phẩm nhặt được (data/items/<id>.tres) → có nút Nhặt
##   - Accept Items     : { "id_vật_phẩm": "cờ_bật_khi_dùng" } → dùng đúng đồ thì bật cờ
## Gốc toạ độ đặt ở CHÂN vật (mặt đất).

## Id duy nhất trong game, dùng cho cờ "picked.<id>" (đã nhặt) — bắt buộc nếu có Take Item.
@export var object_id: String = ""
## Điều kiện hiện (biểu thức GameState). Rỗng = luôn hiện.
@export var visible_when: String = ""

@export_group("Xem")
@export_multiline var examine_text: String = ""
## Dùng file hội thoại thay cho Examine Text (tuỳ chọn)
@export var examine_dialogue: DialogueResource
@export var examine_cue: String = "start"

@export_group("Nhặt")
@export var take_item: StringName = &""
@export var take_amount: int = 1
@export_multiline var take_text: String = ""

@export_group("Dùng đồ")
## item_id -> cờ bật khi dùng đúng đồ (vd {"pipe_clamp": "ch1.pipe_fixed"})
@export var accept_items: Dictionary = {}
## Dùng xong thì mất đồ khỏi túi
@export var consume_item: bool = true
@export_multiline var use_ok_text: String = "Minh: Được rồi."
## {item} = tên món đồ
@export_multiline var use_wrong_text: String = "Minh: (Không dùng {item} ở đây được.)"

@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	var acts: Array[StringName] = []
	if not examine_text.strip_edges().is_empty() or examine_dialogue:
		acts.append(&"examine")
	if take_item != &"":
		acts.append(&"take")
	interactable.actions = acts
	interactable.action_filter = _can_do
	interactable.action_chosen.connect(_on_action)
	GameState.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var present := GameState.check(visible_when)
	# Nhặt rồi thì vật biến mất (đã vào túi đồ)
	if take_item != &"" and _picked():
		present = false
	visible = present
	interactable.enabled = present


func _can_do(action: StringName) -> bool:
	if action == &"take":
		return not _picked()
	return true


func _picked() -> bool:
	return GameState.has_flag("picked." + object_id)


func _on_action(action: StringName, _player: Node, item_id: StringName) -> void:
	match action:
		&"examine":
			if examine_dialogue:
				DialogueManager.show_dialogue_balloon(examine_dialogue, examine_cue)
			else:
				say(examine_text)
		&"take":
			GameState.set_flag("picked." + object_id)
			GameState.add_item(take_item, take_amount)
			if not take_text.strip_edges().is_empty():
				say(take_text)
		&"use_item":
			if accept_items.has(String(item_id)) or accept_items.has(item_id):
				var flag: String = str(accept_items.get(String(item_id), accept_items.get(item_id, "")))
				if consume_item:
					GameState.remove_item(item_id)
				if not flag.is_empty():
					GameState.set_flag(flag)
				say(use_ok_text)
			else:
				say(use_wrong_text.replace("{item}", ItemData.name_of(item_id).to_lower()))


## Hiện vài câu thoại nhanh. Dòng không có "Tên: " thì coi là Minh nói.
static func say(text: String) -> void:
	var lines := PackedStringArray()
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line.is_empty():
			continue
		if not RegEx.create_from_string("^[^:]{1,24}: ").search(line):
			line = "Minh: " + line
		lines.append(line)
	if lines.is_empty():
		return
	var res = DialogueManager.create_resource_from_text("~ start\n" + "\n".join(lines) + "\n=> END\n")
	DialogueManager.show_dialogue_balloon(res, "start")
