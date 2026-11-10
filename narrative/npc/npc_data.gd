class_name NpcData
extends Resource
## Dữ liệu của MỘT nhân vật (NPC hoặc Minh). Mỗi nhân vật một file .tres trong res://data/npcs/.
## Scene NPC, hộp thoại, Sổ… đều đọc từ đây, nên đổi tên/màu chỉ cần sửa 1 chỗ.

const NPC_DIR := "res://data/npcs/"

@export var id: StringName = &""
## Tên hiển thị — PHẢI trùng tên nhân vật trong file .dialogue ("Ông Nội: ...").
@export var display_name: String = ""
## Màu viền khung thoại + màu tên khi nhân vật này nói.
@export var dialogue_color: Color = Color(0.51, 0.49, 0.72)
@export var sprite_frames: SpriteFrames
@export var dialogue: DialogueResource
@export var dialogue_cue: String = "start"
## Độ cao điểm mà đuôi khung thoại chỉ vào (tính từ chân, px).
@export var speech_height: float = 122.0

static var _by_name: Dictionary = {}


## Tìm NpcData theo tên hiển thị (dùng cho nhân vật không có mặt trong scene, vd lời dẫn, gọi điện).
static func find_by_name(character: String) -> NpcData:
	if _by_name.is_empty():
		_load_all()
	return _by_name.get(character)


static func _load_all() -> void:
	var dir := DirAccess.open(NPC_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		# Bản export đổi .tres thành .tres.remap
		file = file.trim_suffix(".remap")
		if not file.ends_with(".tres"):
			continue
		var data := load(NPC_DIR + file) as NpcData
		if data and not data.display_name.is_empty():
			_by_name[data.display_name] = data
