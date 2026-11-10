class_name DialogueBalloon
extends CanvasLayer
## Hộp thoại của Mùa Gió Về (dùng với Dialogue Manager).
##
## Bố cục: khung (Dialogue Box.aseprite) nổi phía trên người đang nói, có đuôi chỉ vào
## nhân vật; dòng trên là TÊN, bên dưới là LỜI THOẠI; mũi tên ▼ nhấp nháy khi chờ bấm.
## Màu viền + màu tên đổi theo nhân vật (lấy từ node nói chuyện, xem `_find_speaker`).
##
## Điều khiển: E (interact) hoặc click → hiện hết chữ / sang câu tiếp.
## Chọn câu trả lời: ↑/↓ rồi E, hoặc click.

## Nhóm chứa các node có thể "nói": cần có `speaker_name: String`,
## `dialogue_color: Color` và hàm `get_speech_anchor() -> Vector2` (toạ độ world trên đầu).
const SPEAKER_GROUP := &"dialogue_speaker"
## Mỗi pixel của khung aseprite = 3 pixel màn hình (khớp zoom camera).
const PIXEL := 3.0
## Vùng cắt trong ảnh "Dialogue Box.aseprite" (600x120).
const FRAME_REGION := Rect2(58, 25, 455, 79)
const TAIL_REGION := Rect2(272, 104, 26, 11)
const ARROW_REGION := Rect2(483, 86, 10, 6)
## Vị trí mũi tên ▼ tính từ góc dưới-phải của khung (đơn vị pixel aseprite).
const ARROW_FROM_RIGHT := 30.0
const ARROW_FROM_BOTTOM := 18.0
const SCREEN_MARGIN := 24.0

@export var dialogue_resource: DialogueResource
@export var start_from_cue: String = ""
@export var next_action: StringName = &"interact"
## Màu viền mặc định (khi không tìm thấy người nói, vd. lời dẫn truyện).
@export var default_color: Color = Color(0.51, 0.49, 0.72)
## Màu cho nhân vật không có mặt trong scene (vd. "Bố" gọi điện).
@export var speaker_colors: Dictionary = {}

var temporary_game_states: Array = []
var is_waiting_for_input := false
var will_hide_balloon := false
var locals: Dictionary = {}

var dialogue_line: DialogueLine:
	set(value):
		if value:
			dialogue_line = value
			apply_dialogue_line()
		else:
			queue_free()
	get:
		return dialogue_line

var _speaker: Node2D = null
var _mutation_cooldown := Timer.new()
var _arrow_time := 0.0

@onready var panel: Control = %Panel
@onready var frame: NinePatchRect = %Frame
@onready var tail: TextureRect = %Tail
@onready var arrow: TextureRect = %Arrow
@onready var arrow_cover: ColorRect = %ArrowCover
@onready var content: MarginContainer = %Content
@onready var name_label: Label = %NameLabel
@onready var dialogue_label: DialogueLabel = %DialogueLabel
@onready var responses_menu: DialogueResponsesMenu = %ResponsesMenu


func _ready() -> void:
	panel.hide()
	tail.hide()
	DialogueManager.mutated.connect(_on_mutated)
	if responses_menu.next_action.is_empty():
		responses_menu.next_action = next_action
	_mutation_cooldown.one_shot = true
	_mutation_cooldown.timeout.connect(_on_mutation_cooldown_timeout)
	add_child(_mutation_cooldown)
	# Khung & đuôi dùng chung một material để đổi màu cùng lúc.
	tail.material = frame.material


func _unhandled_input(_event: InputEvent) -> void:
	# Khi đang thoại, chặn mọi input khác (Player không đi được, không mở menu...).
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_instance_valid(dialogue_line):
		return
	var waiting := is_waiting_for_input and not dialogue_label.is_typing and dialogue_line.responses.is_empty()
	arrow.visible = waiting
	if waiting:
		_arrow_time += delta
		arrow.position.y = _arrow_base_y() + (PIXEL if fmod(_arrow_time, 0.8) > 0.4 else 0.0)
	_layout()


## Bắt đầu hội thoại.
func start(with_dialogue_resource: DialogueResource = null, cue: String = "", extra_game_states: Array = []) -> void:
	temporary_game_states = [self] + extra_game_states
	is_waiting_for_input = false
	if is_instance_valid(with_dialogue_resource):
		dialogue_resource = with_dialogue_resource
	if not cue.is_empty():
		start_from_cue = cue
	dialogue_line = await dialogue_resource.get_next_dialogue_line(start_from_cue, temporary_game_states)
	show()


func apply_dialogue_line() -> void:
	_mutation_cooldown.stop()
	is_waiting_for_input = false
	_arrow_time = 0.0

	_speaker = _find_speaker(dialogue_line.character)
	_apply_color(_get_speaker_color(dialogue_line.character))

	name_label.visible = not dialogue_line.character.is_empty()
	name_label.text = tr(dialogue_line.character, "dialogue")

	dialogue_label.hide()
	dialogue_label.dialogue_line = dialogue_line
	responses_menu.hide()
	responses_menu.responses = dialogue_line.responses

	panel.show()
	panel.focus_mode = Control.FOCUS_ALL
	panel.grab_focus()
	will_hide_balloon = false
	dialogue_label.show()
	_layout()

	if not dialogue_line.text.is_empty():
		dialogue_label.type_out()
		await dialogue_label.finished_typing

	if dialogue_line.responses.size() > 0:
		panel.focus_mode = Control.FOCUS_NONE
		responses_menu.show()
		_layout()
		responses_menu.focus_first_item()
	elif dialogue_line.time != "":
		var t: float = dialogue_line.text.length() * 0.02 if dialogue_line.time == "auto" else dialogue_line.time.to_float()
		await get_tree().create_timer(t).timeout
		next(dialogue_line.next_id)
	else:
		is_waiting_for_input = true
		panel.focus_mode = Control.FOCUS_ALL
		panel.grab_focus()


func next(next_id: String) -> void:
	dialogue_line = await dialogue_resource.get_next_dialogue_line(next_id, temporary_game_states)


# --- Người nói & màu -----------------------------------------------------------------

func _find_speaker(character: String) -> Node2D:
	if character.is_empty():
		return null
	for node in get_tree().get_nodes_in_group(SPEAKER_GROUP):
		if node is Node2D and node.visible and node.get("speaker_name") == character:
			return node
	return null


func _get_speaker_color(character: String) -> Color:
	if _speaker and _speaker.get("dialogue_color") is Color:
		return _speaker.dialogue_color
	if speaker_colors.has(character):
		return speaker_colors[character]
	var data := NpcData.find_by_name(character)
	if data:
		return data.dialogue_color
	return default_color


func _apply_color(color: Color) -> void:
	(frame.material as ShaderMaterial).set_shader_parameter("border_color", color)
	name_label.add_theme_color_override("font_color", color.lightened(0.25))


# --- Bố cục ------------------------------------------------------------------------

func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var width := minf(FRAME_REGION.size.x * PIXEL, view.x - SCREEN_MARGIN * 2)
	var min_height := FRAME_REGION.size.y * PIXEL
	content.size.x = width
	var height := maxf(min_height, content.get_combined_minimum_size().y)
	panel.size = Vector2(width, height)
	content.size = panel.size
	frame.size = panel.size / PIXEL

	arrow_cover.position = Vector2(width - ARROW_FROM_RIGHT * PIXEL, height - ARROW_FROM_BOTTOM * PIXEL)
	arrow.position.x = arrow_cover.position.x + PIXEL
	if not arrow.visible:
		arrow.position.y = _arrow_base_y()

	var tail_size := TAIL_REGION.size * PIXEL
	if _speaker:
		# Toạ độ world → toạ độ màn hình (CanvasLayer).
		var anchor: Vector2 = _speaker.get_viewport().get_canvas_transform() * _speaker.get_speech_anchor()
		var panel_bottom := anchor.y - tail_size.y + PIXEL
		panel.position.x = clampf(anchor.x - width * 0.5, SCREEN_MARGIN, view.x - width - SCREEN_MARGIN)
		panel.position.y = clampf(panel_bottom - height, SCREEN_MARGIN, view.y - height - SCREEN_MARGIN)
		tail.visible = panel.visible
		tail.position.x = clampf(anchor.x - tail_size.x * 0.5,
			panel.position.x + 16 * PIXEL, panel.position.x + width - 16 * PIXEL - tail_size.x)
		tail.position.y = panel.position.y + height - PIXEL
	else:
		# Không có người nói trong scene (dẫn truyện) → khung ở giữa dưới màn hình.
		panel.position = Vector2((view.x - width) * 0.5, view.y - height - SCREEN_MARGIN * 2)
		tail.visible = false


func _arrow_base_y() -> float:
	return arrow_cover.position.y + PIXEL


# --- Signals -------------------------------------------------------------------------

func _on_mutation_cooldown_timeout() -> void:
	if will_hide_balloon:
		will_hide_balloon = false
		panel.hide()
		tail.hide()


func _on_mutated(mutation: Dictionary) -> void:
	if not mutation.is_inline:
		is_waiting_for_input = false
		will_hide_balloon = true
		_mutation_cooldown.start(0.1)


func _on_panel_gui_input(event: InputEvent) -> void:
	var clicked: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var pressed_next := event.is_action_pressed(next_action)

	if dialogue_label.is_typing:
		if clicked or pressed_next:
			get_viewport().set_input_as_handled()
			dialogue_label.skip_typing()
		return

	if not is_waiting_for_input or dialogue_line.responses.size() > 0:
		return

	if clicked or (pressed_next and get_viewport().gui_get_focus_owner() == panel):
		get_viewport().set_input_as_handled()
		next(dialogue_line.next_id)


func _on_responses_menu_response_selected(response: DialogueResponse) -> void:
	next(response.next_id)
