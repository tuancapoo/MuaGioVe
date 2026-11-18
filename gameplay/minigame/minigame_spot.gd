class_name MinigameSpot
extends Interactable
## Điểm kích hoạt mini-game trên bản đồ (ví dụ: Câu cá bên mương ở bo_muong_chan_de).
## Bấm E (hoặc nút A tay cầm) để bắt đầu mini-game.
## play_in_map = true: chơi ngay trên map nếu có res://gameplay/minigame/<id>/<id>_in_map.gd
## (vd câu cá: fishing_in_map.gd), không mở scene riêng.

@export var minigame_id: String = "fishing"
@export var target_count: int = 5
@export var challenge_mode: bool = false
## Điều kiện để điểm này hiện / cho phép chơi (rỗng = luôn cho phép)
@export var active_when: String = ""
## Câu thoại khi chưa đủ điều kiện mở
@export_multiline var locked_text: String = "Minh: (Lát nữa rảnh mình quay lại đây sau.)"
## Chơi ngay trên map (không mở scene minigame riêng) nếu có bản _in_map
@export var play_in_map: bool = true

## Đặt ghế đá ở chỗ chơi (vd câu cá: Minh ngồi ghế đá thả câu)
@export var show_bench: bool = false
## Tâm ghế so với chỗ Minh ngồi (An ngồi bên trái Minh ~40 px)
@export var bench_offset: Vector2 = Vector2(-20, 0)
const BENCH_PATH := "res://assets/objects/ghe_da.png"
const BENCH_FOOT_ROW := 28

const IN_MAP_PATH := "res://gameplay/minigame/%s/%s_in_map.gd"
var _in_map: Node = null


func _ready() -> void:
	super._ready()
	actions = []
	show_items = false
	interacted.connect(_on_interacted)
	if show_bench and ResourceLoader.exists(BENCH_PATH):
		var tex: Texture2D = load(BENCH_PATH)
		var spr := Sprite2D.new()
		spr.name = "Bench"
		spr.texture = tex
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.centered = false
		spr.z_index = -1
		spr.position = bench_offset
		spr.offset = Vector2(-tex.get_width() / 2, -BENCH_FOOT_ROW)
		add_child(spr)
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

	var in_map_path := IN_MAP_PATH % [minigame_id, minigame_id]
	if play_in_map and ResourceLoader.exists(in_map_path) and _player is Player:
		_start_in_map(in_map_path, _player)
		return

	var params := {
		"target": target_count,
		"challenge_mode": challenge_mode,
	}
	MinigameManager.start(minigame_id, params)


func _start_in_map(path: String, player: Player) -> void:
	if is_instance_valid(_in_map):
		return
	_in_map = (load(path) as GDScript).new()
	add_child(_in_map)
	# Cất cần cắm sẵn ở bờ (Minh cầm cần khi câu), dấu "?" ẩn trong lúc câu
	var prop := get_node_or_null("Prop") as CanvasItem
	if prop:
		prop.visible = false
	hide_prompt = true
	_in_map.closed.connect(func():
		if prop:
			prop.visible = true
		hide_prompt = false)
	_in_map.start(player)
