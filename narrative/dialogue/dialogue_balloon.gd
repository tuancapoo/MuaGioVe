class_name DialogueBalloon
extends CanvasLayer
## Hộp thoại của Mùa Gió Về (dùng với Dialogue Manager).
##
## Bố cục: khung (assets/ui/dialogue_box.png, xuất từ art_source/ui/dialogue_box.aseprite) nổi phía trên người đang nói, có đuôi chỉ vào
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
## Bề rộng khung: co theo độ dài câu, trong khoảng này (px màn hình)
const MIN_WIDTH := 420.0
const MAX_WIDTH := 1100.0
## Tối đa số dòng hiển thị trong 1 lần khung thoại; dài hơn sẽ tự ngắt sang trang tiếp theo.
const MAX_LINES := 2

@export var dialogue_resource: DialogueResource
@export var start_from_cue: String = ""
@export var next_action: StringName = &"interact"
## Màu viền mặc định (khi không tìm thấy người nói, vd. lời dẫn truyện).
@export var default_color: Color = Color(0.51, 0.49, 0.72)
## Màu cho nhân vật không có mặt trong scene (vd. "Bố" gọi điện, "Ông Nội" gọi ngoài sân).
@export var speaker_colors: Dictionary = {
	"Ông Nội": Color(0.96, 0.7, 0.42, 1),
	"Bố": Color(0.84, 0.44, 0.36, 1),
}

@export_group("Tiếng gõ chữ")
## Mỗi chữ hiện ra phát ngẫu nhiên 1 tiếng trong danh sách (khoảng trắng thì im)
@export var type_sounds: Array[AudioStream] = [
	preload("res://assets/audio/sfx/typing/key_01.wav"),
	preload("res://assets/audio/sfx/typing/key_02.wav"),
	preload("res://assets/audio/sfx/typing/key_03.wav"),
	preload("res://assets/audio/sfx/typing/key_04.wav"),
]
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var type_volume_db: float = -14.0
## Cao độ dao động ngẫu nhiên ± giá trị này để nghe tự nhiên
@export_range(0.0, 0.3, 0.01) var type_pitch_jitter: float = 0.08
@export var type_sound_bus: StringName = &"SFX"
@export_group("")

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
var _box_width := MAX_WIDTH
var _pages: PackedStringArray = PackedStringArray()
var _page_index: int = 0
var _type_players: Array[AudioStreamPlayer] = []
var _type_next_player := 0
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
	_setup_type_sound()


func _unhandled_input(_event: InputEvent) -> void:
	# Khi đang thoại, chặn mọi input khác (Player không đi được, không mở menu...).
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_instance_valid(dialogue_line):
		return
	var waiting := is_waiting_for_input and not dialogue_label.is_typing and (_has_more_pages() or dialogue_line.responses.is_empty())
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

	_pages = _paginate_text(dialogue_line.text)
	_page_index = 0
	_show_current_page()


func _has_more_pages() -> bool:
	return _page_index + 1 < _pages.size()


func _show_current_page() -> void:
	is_waiting_for_input = false
	_arrow_time = 0.0

	var page_text: String = _pages[_page_index] if _page_index < _pages.size() else ""
	var is_last_page: bool = not _has_more_pages()

	var page_line := DialogueLine.new()
	page_line.id = dialogue_line.id
	page_line.next_id = dialogue_line.next_id
	page_line.character = dialogue_line.character
	page_line.text = page_text
	page_line.time = dialogue_line.time
	page_line.extra_game_states = dialogue_line.extra_game_states
	if is_last_page:
		page_line.responses = dialogue_line.responses
		page_line.inline_mutations = dialogue_line.inline_mutations
		page_line.speeds = dialogue_line.speeds

	dialogue_label.hide()
	dialogue_label.dialogue_line = page_line
	responses_menu.hide()
	responses_menu.responses = dialogue_line.responses if is_last_page else []
	_box_width = _fit_width(page_text, is_last_page)

	panel.show()
	panel.focus_mode = Control.FOCUS_ALL
	panel.grab_focus()
	will_hide_balloon = false
	dialogue_label.show()
	_layout()

	if not page_text.is_empty():
		dialogue_label.type_out()
		await dialogue_label.finished_typing

	if is_last_page and dialogue_line.responses.size() > 0:
		panel.focus_mode = Control.FOCUS_NONE
		responses_menu.show()
		_layout()
		responses_menu.focus_first_item()
	elif dialogue_line.time != "":
		var t: float = page_text.length() * 0.02 if dialogue_line.time == "auto" else dialogue_line.time.to_float()
		await get_tree().create_timer(t).timeout
		_advance_page_or_next()
	else:
		is_waiting_for_input = true
		panel.focus_mode = Control.FOCUS_ALL
		panel.grab_focus()


func _advance_page_or_next() -> void:
	if _has_more_pages():
		_page_index += 1
		_show_current_page()
	else:
		next(dialogue_line.next_id)


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
	var width := minf(_box_width, view.x - SCREEN_MARGIN * 2)
	content.size.x = width
	content.size.y = 0.0
	var height := content.get_combined_minimum_size().y
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


## Bề rộng vừa câu thoại (1 dòng nếu ngắn), không quá MAX_WIDTH.
func _fit_width(page_text: String = "", include_responses: bool = true) -> float:
	var font := dialogue_label.get_theme_font(&"normal_font")
	var font_size := dialogue_label.get_theme_font_size(&"normal_font_size")
	var bb_re := RegEx.create_from_string("\\[[^\\]]*\\]")
	var src: String = page_text if not page_text.is_empty() else dialogue_line.text
	var text_w: float = 0.0
	for raw_line: String in src.split("\n"):
		var plain: String = bb_re.sub(raw_line, "", true)
		text_w = maxf(text_w, font.get_string_size(plain, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	if name_label.visible:
		text_w = maxf(text_w, name_label.get_theme_font(&"font").get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	if include_responses:
		for r in dialogue_line.responses:
			text_w = maxf(text_w, font.get_string_size(r.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var pad := float(content.get_theme_constant(&"margin_left") + content.get_theme_constant(&"margin_right"))
	return clampf(ceilf(text_w + pad + 12.0), MIN_WIDTH, MAX_WIDTH)


## Ngắt câu thoại thành nhiều trang, mỗi trang tối đa MAX_LINES (2 dòng) theo đúng bề rộng khung.
func _paginate_text(raw_text: String) -> PackedStringArray:
	var trimmed := raw_text.strip_edges()
	if trimmed.is_empty():
		return PackedStringArray([""])

	var font := dialogue_label.get_theme_font(&"normal_font")
	var font_size := dialogue_label.get_theme_font_size(&"normal_font_size")
	var view := get_viewport().get_visible_rect().size
	var pad := float(content.get_theme_constant(&"margin_left") + content.get_theme_constant(&"margin_right"))
	var max_line_w := maxf(160.0, minf(MAX_WIDTH, view.x - SCREEN_MARGIN * 2.0) - pad - 16.0)
	var bb_re := RegEx.create_from_string("\\[[^\\]]*\\]")

	var visual_lines: PackedStringArray = PackedStringArray()
	for para: String in trimmed.split("\n"):
		var p_clean := para.strip_edges()
		if p_clean.is_empty():
			continue
		var words: PackedStringArray = p_clean.split(" ", false)
		var cur: String = ""
		for w: String in words:
			var candidate: String = w if cur.is_empty() else (cur + " " + w)
			var plain_cand: String = bb_re.sub(candidate, "", true)
			if not cur.is_empty() and font.get_string_size(plain_cand, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_line_w:
				visual_lines.append(cur)
				cur = w
			else:
				cur = candidate
		if not cur.is_empty():
			visual_lines.append(cur)

	if visual_lines.is_empty():
		return PackedStringArray([trimmed])

	var pages: PackedStringArray = PackedStringArray()
	var idx: int = 0
	while idx < visual_lines.size():
		var chunk: PackedStringArray = PackedStringArray()
		for k: int in range(MAX_LINES):
			if idx + k < visual_lines.size():
				chunk.append(visual_lines[idx + k])
		pages.append("\n".join(chunk))
		idx += MAX_LINES
	return pages


# --- Tiếng gõ chữ ------------------------------------------------------------------

func _setup_type_sound() -> void:
	var bus := type_sound_bus if AudioServer.get_bus_index(type_sound_bus) != -1 else &"Master"
	for i in 4: # vài player xoay vòng để tiếng trước không bị cắt cụt
		var p := AudioStreamPlayer.new()
		p.volume_db = type_volume_db
		p.bus = bus
		add_child(p)
		_type_players.append(p)
	dialogue_label.spoke.connect(_on_letter_spoke)


func _on_letter_spoke(letter: String, _index: int, _speed: float) -> void:
	if type_sounds.is_empty() or letter.strip_edges().is_empty():
		return
	var p := _type_players[_type_next_player]
	_type_next_player = (_type_next_player + 1) % _type_players.size()
	p.stream = type_sounds.pick_random()
	p.pitch_scale = 1.0 + randf_range(-type_pitch_jitter, type_pitch_jitter)
	p.play()


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

	if not is_waiting_for_input or (not _has_more_pages() and dialogue_line.responses.size() > 0):
		return

	if clicked or (pressed_next and get_viewport().gui_get_focus_owner() == panel):
		get_viewport().set_input_as_handled()
		_advance_page_or_next()


func _on_responses_menu_response_selected(response: DialogueResponse) -> void:
	next(response.next_id)
