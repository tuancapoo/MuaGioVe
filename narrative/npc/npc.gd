class_name NPC
extends Node2D
## NPC dùng chung. Gốc toạ độ (origin) đặt ở CHÂN nhân vật để dễ đặt lên mặt đất.
##
## - Thông tin nhân vật (tên, màu thoại, sprite, file hội thoại) nằm trong `data` (NpcData,
##   res://data/npcs/<id>.tres) — scene chỉ cần gán `data`.
## - Lời thoại: cue "start" trong file .dialogue tự chọn đoạn phù hợp theo GameState.
## - Có mặt hay không: `appear_condition` (biểu thức với GameState).
## - Số lần đã nói chuyện tự lưu vào cờ "npc.<id>.talks".

signal talked_to(npc: NPC)

@export var data: NpcData
## Biểu thức với GameState, rỗng = luôn có mặt.
## Vd: "chapter == 1", "time != 'evening'", "is_quest_done('fix_pipe')".
@export var appear_condition: String = ""
## Quay mặt về phía Player khi được nói chuyện.
@export var face_player: bool = true

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


func get_speech_anchor() -> Vector2:
	return global_position + Vector2(0, -(data.speech_height if data else 122.0))
