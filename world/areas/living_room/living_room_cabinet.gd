extends Node
## Điều khiển tương tác Tủ Tivi trong phòng khách (living_room):
## - Sau khi Minh hỏi Ông Nội ("ch1.asked_ong_tools") và chưa tìm đủ 3 món sửa ống nước:
##   tủ tivi sáng viền khi tới gần; bấm E mở cảnh Point & Click + Drag & Drop tìm đồ.
## - Trước khi hỏi Ông Nội hoặc sau khi đã lấy đủ: hiện lời thoại ngắn của Minh.

const DIALOGUE_PATH := "res://data/dialogues/ch1_pipe_intro.dialogue"
const HIGHLIGHT_SHADER := preload("res://world/effects/interact_highlight.gdshader")
const CABINET_SEARCH_SCRIPT := preload("res://gameplay/minigame/tv_cabinet_search/tv_cabinet_search.gd")

const FLAG_ASKED_TOOLS := "ch1.asked_ong_tools"
const PROXIMITY_RADIUS := 95.0

var _player: Player = null
var _cabinet_mat: ShaderMaterial = null
var _highlight_val: float = 0.0
var _overlay_open: bool = false
var _time: float = 0.0

@onready var _cabinet_sprite: Sprite2D = get_parent().get_node_or_null("Background/04_TV_Cabinet")
@onready var _cabinet_spot: Interactable = get_parent().get_node_or_null("Objects/TvCabinetSpot")


func _ready() -> void:
	if _cabinet_sprite:
		_cabinet_mat = ShaderMaterial.new()
		_cabinet_mat.shader = HIGHLIGHT_SHADER
		_cabinet_mat.set_shader_parameter(&"highlight", 0.0)
		_cabinet_mat.set_shader_parameter(&"outline_color", Color(1.0, 0.93, 0.56, 1.0))
		_cabinet_sprite.material = _cabinet_mat

	if _cabinet_spot:
		_cabinet_spot.interacted.connect(_on_cabinet_interacted)

	await get_tree().process_frame
	if is_inside_tree():
		_player = get_tree().get_first_node_in_group(&"player") as Player
		var ong_node: Node2D = get_parent().get_node_or_null("NPCs/OngNoi") as Node2D
		if ong_node and ong_node.visible:
			var ong_spr: AnimatedSprite2D = ong_node.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
			if ong_spr:
				ong_spr.flip_h = true


func _process(delta: float) -> void:
	_time += delta
	if _cabinet_mat == null or _cabinet_spot == null:
		return

	var need_search: bool = _should_search_cabinet()
	var want: float = 0.0
	if _player and _player.can_move and not _overlay_open:
		var dist: float = absf(_player.global_position.x - _cabinet_spot.global_position.x)
		if need_search:
			if dist <= PROXIMITY_RADIUS:
				want = 1.0
			else:
				want = 0.35 + 0.15 * sin(_time * 4.0)
		elif dist <= PROXIMITY_RADIUS:
			want = 0.45

	_highlight_val = lerpf(_highlight_val, want, clampf(delta * 8.0, 0.0, 1.0))
	_cabinet_mat.set_shader_parameter(&"highlight", _highlight_val)


func _should_search_cabinet() -> bool:
	return GameState.has_flag(FLAG_ASKED_TOOLS) and GameState.count_pipe_parts_missing() > 0


func _on_cabinet_interacted(player_node: Node) -> void:
	if _overlay_open:
		return

	if not GameState.has_flag(FLAG_ASKED_TOOLS):
		_play_dialogue("cabinet_not_yet")
		return

	if GameState.count_pipe_parts_missing() == 0:
		_play_dialogue("cabinet_done")
		return

	_overlay_open = true
	var search: TvCabinetSearch = CABINET_SEARCH_SCRIPT.new()
	add_child(search)
	search.open(player_node as Player)
	search.closed.connect(func(_all_found: bool) -> void:
		_overlay_open = false
	)


func _play_dialogue(cue: String) -> void:
	var dlg := _load_dialogue()
	if dlg == null:
		return
	DialogueManager.show_dialogue_balloon(dlg, cue)


func _load_dialogue() -> DialogueResource:
	if FileAccess.file_exists(DIALOGUE_PATH):
		var raw := FileAccess.get_file_as_string(DIALOGUE_PATH)
		if not raw.is_empty():
			return DialogueManager.create_resource_from_text(raw)
	if ResourceLoader.exists(DIALOGUE_PATH):
		return load(DIALOGUE_PATH) as DialogueResource
	return null
