class_name ItemData
extends Resource
## Dữ liệu một vật phẩm. Mỗi vật phẩm một file: res://data/items/<id>.tres
## Túi đồ chỉ lưu id + số lượng (GameState.inventory); tên, hình, mô tả lấy từ đây.

const ITEM_DIR := "res://data/items/"

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Hình trong túi đồ / vòng chọn (16x16 hoặc 32x32, pixel art)
@export var icon: Texture2D
## Đồ nhiệm vụ: không bỏ được, dùng xong mới mất
@export var key_item: bool = false

static var _cache: Dictionary = {}


## Lấy ItemData theo id (null nếu không có file data/items/<id>.tres).
static func get_item(item_id: StringName) -> ItemData:
	if _cache.has(item_id):
		return _cache[item_id]
	var path := ITEM_DIR + String(item_id) + ".tres"
	var data: ItemData = load(path) if ResourceLoader.exists(path) else null
	_cache[item_id] = data
	return data


## Tên hiển thị (dùng id nếu chưa có file dữ liệu).
static func name_of(item_id: StringName) -> String:
	var d := get_item(item_id)
	return d.display_name if d and not d.display_name.is_empty() else String(item_id)
