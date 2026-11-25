class_name NPC
extends Node2D
## NPC dùng chung. Gốc toạ độ (origin) đặt ở CHÂN nhân vật để dễ đặt lên mặt đất.
##
## - Thông tin nhân vật (tên, màu thoại, sprite, file hội thoại) nằm trong `data` (NpcData,
##   res://data/npcs/<id>.tres) — scene chỉ cần gán `data`.
## - Lời thoại: cue "start" trong file .dialogue tự chọn đoạn phù hợp theo GameState.
## - Có mặt hay không: `appear_condition` (biểu thức với GameState).
## - Số lần đã nói chuyện tự lưu vào cờ "npc.<id>.talks".
## - Bấm E: thanh chọn [Nói chuyện] + các món trong túi đồ (chọn món = ĐƯA món đó cho NPC).
##   Đưa đồ: nếu file .dialogue của NPC có cue "give_<id món>" (vd ~ give_pipe_clamp) thì chạy cue đó,
##   không thì Minh tự nhủ NPC không cần món này.

signal talked_to(npc: NPC)

@export var data: NpcData
## Biểu thức với GameState, rỗng = luôn có mặt.
## Vd: "chapter == 1", "time != 'evening'", "is_quest_done('fix_pipe')".
@export var appear_condition: String = ""
## Quay mặt về phía Player khi được nói chuyện.
@export var face_player: bool = true
## true: bấm E mở thanh chọn (Nói chuyện + đưa đồ). false: bấm E là nói chuyện ngay.
@export var use_action_bar: bool = true

## Dùng cho hộp thoại (nhóm "dialogue_speaker").
var npc_id: StringName:
	get: return data.id if data else &""
var speaker_name: String:
	get: return data.display_name if data else ""
var dialogue_color: Color:
	get: return data.dialogue_color if data else Color(0.51, 0.49, 0.72)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	add_to_group(&"dialogue_speaker")
	if data and data.sprite_frames:
		sprite.sprite_frames = data.sprite_frames
	interactable.interacted.connect(_on_interacted)
	interactable.action_chosen.connect(_on_action)
	if use_action_bar:
		interactable.actions = [&"talk"]
	GameState.changed.connect(_refresh_presence)
	_refresh_presence()
	_play_idle()


func _play_idle() -> void:
	var frames := sprite.sprite_frames
	if frames == null:
		return
	# Ưu tiên tag "Idle" trong Aseprite; file chưa có tag thì AsepriteWizard đặt tên "default".
	if frames.has_animation(&"Idle"):
		sprite.play(&"Idle")
	elif frames.get_animation_names().size() > 0:
		sprite.play(frames.get_animation_names()[0])


func _refresh_presence() -> void:
	var present := GameState.check(appear_condition)
	visible = present
	interactable.enabled = present


func _on_interacted(player: Node) -> void:
	if face_player and player is Node2D:
		sprite.flip_h = (player as Node2D).global_position.x < global_position.x
	if data:
		GameState.add_flag("npc.%s.talks" % data.id)
	talked_to.emit(self)
	if data and data.dialogue:
		DialogueManager.show_dialogue_balloon(data.dialogue, data.dialogue_cue)


func _on_action(action: StringName, player: Node, item_id: StringName) -> void:
	match action:
		&"talk":
			_on_interacted(player)
		&"use_item":
			_give(item_id, player)


## Đưa đồ cho NPC: chạy cue "give_<id>" nếu có trong file thoại của NPC.


func _give(item_id: StringName, player: Node) -> void:
	if face_player and player is Node2D:
		sprite.flip_h = (player as Node2D).global_position.x < global_position.x

	var item_key := String(item_id)
	var cue := "give_" + item_key

	if data and data.dialogue and data.dialogue.get_cues().has(cue):
		if not GameState.has_item(item_key):
			return

		# Chỉ trừ vật phẩm khi NPC có hội thoại nhận món đó.
		var removed := GameState.remove_item(item_key, 1)
		if not removed:
			return

		DialogueManager.show_dialogue_balloon(data.dialogue, cue)
		return

	var who := speaker_name if not speaker_name.is_empty() else "người ta"
	var line := "Minh: (Chắc %s không cần %s đâu.)" % [
		who,
		ItemData.name_of(item_id).to_lower()
	]

	var res = DialogueManager.create_resource_from_text(
		"~ start\n" + line + "\n=> END\n"
	)
	DialogueManager.show_dialogue_balloon(res, "start")

func get_speech_anchor() -> Vector2:
	return global_position + Vector2(0, -(data.speech_height if data else 122.0))
