extends Node
## Điều khiển nhiệm vụ mở đầu Chương 0 trong phòng Minh ở thành phố:
## 1. Màn hình đen + hội thoại của Bố ("Thằng kia, xe tới rồi, chuẩn bị đồ đạc nhanh lên!").
## 2. Màn hình sáng dần: Minh đứng trong phòng ở thành phố.
## 3. Tới gần balo / tủ áo quần / cửa sẽ sáng viền lên cho phép tương tác.
## 4. Tương tác balo → mở cảnh Point & Click + Drag & Drop lấy điện thoại.
## 5. Tương tác tủ áo quần → lấy bộ áo quần.
## 6. Ra cửa: thiếu đồ → tự sự của Minh; đủ cả 2 món → hoàn thành phân đoạn mở đầu.

const DIALOGUE_PATH := "res://data/dialogues/ch0_city_room.dialogue"
const HIGHLIGHT_SHADER := preload("res://world/effects/interact_highlight.gdshader")
const BACKPACK_SCRIPT := preload("res://gameplay/minigame/backpack_search/backpack_search.gd")
const WARDROBE_SCRIPT := preload("res://gameplay/minigame/wardrobe_search/wardrobe_search.gd")
const BUS_CUTSCENE_SCENE := preload("res://narrative/cutscene/bus_ride/bus_ride.tscn")
const FONT := preload("res://assets/fonts/vt323_regular.ttf")

const FLAG_INTRO_DONE := "ch0.intro_done"
const FLAG_GOT_PHONE := "ch0.got_phone"
const FLAG_GOT_CLOTHES := "ch0.got_clothes"
const FLAG_READY_LEAVE := "ch0.ready_to_leave"
const QUEST_ID := "ch0_pack"

const PROXIMITY_RADIUS := 60.0

var _dialogue_res: DialogueResource
var _player: Player = null
var _active_target: Node = null
var _overlay_open: bool = false
var _ending_shown: bool = false

var _bag_mat: ShaderMaterial
var _wardrobe_mat: ShaderMaterial
var _door_mat: ShaderMaterial
var _bag_h: float = 0.0
var _wardrobe_h: float = 0.0
var _door_h: float = 0.0

var _overlay_layer: CanvasLayer
var _fade_rect: ColorRect
var _end_box: VBoxContainer
var _hud_layer: CanvasLayer
var _hud_panel: PanelContainer
var _hud_phone: Label
var _hud_clothes: Label
var _hud_door: Label

@onready var _map: Node2D = get_parent()
@onready var _bag_sprite: Sprite2D = get_parent().get_node_or_null("Background/bag")
@onready var _wardrobe_sprite: Sprite2D = get_parent().get_node_or_null("Background/wardorbe")
@onready var _door_sprite: Sprite2D = get_parent().get_node_or_null("Background/door")
@onready var _bag_spot: Interactable = get_parent().get_node_or_null("Objects/BagSpot")
@onready var _wardrobe_spot: Interactable = get_parent().get_node_or_null("Objects/WardrobeSpot")
@onready var _door_spot: Interactable = get_parent().get_node_or_null("Exits/RoomDoor")


func _ready() -> void:
	_dialogue_res = _load_dialogue()
	_setup_highlight_materials()
	_build_overlay()
	_build_hud()

	# Che màn hình đen ngay từ frame đầu tiên để không bị nháy sáng trước hội thoại mở đầu
	if not GameState.has_flag(FLAG_INTRO_DONE):
		_fade_rect.color = Color(0, 0, 0, 1)
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	if _bag_spot:
		_bag_spot.interacted.connect(_on_bag_interacted)
	if _wardrobe_spot:
		_wardrobe_spot.interacted.connect(_on_wardrobe_interacted)
	if _door_spot:
		_door_spot.interacted.connect(_on_door_interacted)

	GameState.changed.connect(_refresh_hud)

	# Đợi 1 frame để Main đặt Player xong vào phòng
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player:
		_player.interactable_changed.connect(func(t): _active_target = t)

	if not GameState.has_flag(FLAG_INTRO_DONE):
		_play_opening()
	else:
		_fade_rect.color.a = 0.0
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud_panel.show()
		_refresh_hud()


func _process(delta: float) -> void:
	if _player == null or _ending_shown:
		return

	var got_phone := GameState.has_flag(FLAG_GOT_PHONE)
	var got_clothes := GameState.has_flag(FLAG_GOT_CLOTHES)
	var can_interact := _player.can_move and not _overlay_open

	var want_bag := 0.0
	if can_interact and _bag_spot and not got_phone:
		if _active_target == _bag_spot:
			want_bag = 1.0
		elif _is_near(_bag_spot):
			want_bag = 0.65

	var want_wardrobe := 0.0
	if can_interact and _wardrobe_spot and not got_clothes:
		if _active_target == _wardrobe_spot:
			want_wardrobe = 1.0
		elif _is_near(_wardrobe_spot):
			want_wardrobe = 0.65

	var want_door := 0.0
	if can_interact and _door_spot:
		if _active_target == _door_spot:
			want_door = 1.0
		elif got_phone and got_clothes:
			want_door = 0.55 if not _is_near(_door_spot) else 0.85

	var rate := clampf(delta * 8.0, 0.0, 1.0)
	_bag_h = lerpf(_bag_h, want_bag, rate)
	_wardrobe_h = lerpf(_wardrobe_h, want_wardrobe, rate)
	_door_h = lerpf(_door_h, want_door, rate)

	if _bag_mat:
		_bag_mat.set_shader_parameter(&"highlight", _bag_h)
	if _wardrobe_mat:
		_wardrobe_mat.set_shader_parameter(&"highlight", _wardrobe_h)
	if _door_mat:
		_door_mat.set_shader_parameter(&"highlight", _door_h)


func _unhandled_input(event: InputEvent) -> void:
	if not _ending_shown:
		return
	if event.is_action_pressed(&"restart"):
		get_viewport().set_input_as_handled()
		_replay_segment()
	elif event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		_go_to_village()


func _is_near(spot: Node2D) -> bool:
	return absf(_player.global_position.x - spot.global_position.x) <= PROXIMITY_RADIUS


# --- Mở đầu: Màn hình đen → Hội thoại Bố → Sáng lên --------------------------

func _play_opening() -> void:
	_fade_rect.color = Color(0, 0, 0, 1)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_hud_panel.hide()

	if _player:
		_player.lock(&"ch0_intro")
		_player.visible = false
		_player.anim.flip_h = false

	await get_tree().create_timer(0.45).timeout
	if not is_inside_tree():
		return

	# Hội thoại của Bố với Minh trên nền màn hình đen
	await _play_dialogue("intro_black")
	if not is_inside_tree():
		return

	await get_tree().create_timer(0.3).timeout
	if not is_inside_tree():
		return

	if _player:
		_player.visible = true

	# Màn hình sáng dần lên để lộ phòng Minh ở thành phố
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 0.0, 1.25)
	await tw.finished
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not is_inside_tree():
		return

	await get_tree().create_timer(0.25).timeout
	if not is_inside_tree():
		return

	await _play_dialogue("intro_room")
	if not is_inside_tree():
		return

	GameState.set_flag(FLAG_INTRO_DONE, true)
	GameState.start_quest(QUEST_ID)
	_hud_panel.show()
	_refresh_hud()
	if _player:
		_player.unlock(&"ch0_intro")


# --- Tương tác: Balo, Tủ áo quần, Cửa ----------------------------------------

func _on_bag_interacted(player: Node) -> void:
	if _overlay_open:
		return
	if GameState.has_flag(FLAG_GOT_PHONE):
		await _play_dialogue("bag_done")
		return

	_overlay_open = true
	_hud_panel.hide()
	var search: BackpackSearch = BACKPACK_SCRIPT.new()
	add_child(search)
	search.open(player as Player)
	search.closed.connect(func(_got_phone: bool):
		_overlay_open = false
		if is_instance_valid(_hud_panel) and not _ending_shown:
			_hud_panel.show()
			_refresh_hud()
	)


func _on_wardrobe_interacted(player: Node) -> void:
	if _overlay_open:
		return
	if GameState.has_flag(FLAG_GOT_CLOTHES):
		await _play_dialogue("wardrobe_done")
		return

	_overlay_open = true
	_hud_panel.hide()
	var search: WardrobeSearch = WARDROBE_SCRIPT.new()
	add_child(search)
	search.open(player as Player)
	search.closed.connect(func(_got_clothes: bool):
		_overlay_open = false
		if is_instance_valid(_hud_panel) and not _ending_shown:
			_hud_panel.show()
			_refresh_hud()
	)


func _on_door_interacted(_player_node: Node) -> void:
	var has_all := GameState.has_flag(FLAG_GOT_PHONE) and GameState.has_flag(FLAG_GOT_CLOTHES)
	if not has_all:
		await _play_dialogue("door_locked")
		return

	if _player:
		_player.lock(&"ch0_exit")
	_hud_panel.hide()
	GameState.set_flag(FLAG_READY_LEAVE, true)
	GameState.complete_quest(QUEST_ID)

	await _play_dialogue("door_leave")
	if not is_inside_tree():
		return

	# Màn hình tối dần rồi chạy cutscene Minh ngồi trên xe buýt về Làng Cỏ
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 1.0, 0.9)
	await tw.finished
	if not is_inside_tree():
		return

	var bus: BusRideCutscene = BUS_CUTSCENE_SCENE.instantiate()
	add_child(bus)
	bus.finished.connect(func():
		_go_to_village()
	)


func _replay_segment() -> void:
	_ending_shown = false
	GameState.flags.erase(FLAG_INTRO_DONE)
	GameState.flags.erase(FLAG_GOT_PHONE)
	GameState.flags.erase(FLAG_GOT_CLOTHES)
	GameState.flags.erase(FLAG_READY_LEAVE)
	GameState.quests.erase(QUEST_ID)
	GameState.remove_item("phone", GameState.item_count("phone"))
	GameState.remove_item("clothes", GameState.item_count("clothes"))
	if _player:
		_player.unlock(&"ch0_exit")
	SceneManager.change_map("phong_minh_o_thanh_pho")


func _go_to_village() -> void:
	_ending_shown = false
	# Vẫn giữ chapter = 0 cho tới khi hết cảnh hội thoại dưới gốc cây đa rồi mới sang Chương 1
	GameState.set_flag("ch0.bus_arriving", true)
	if _player:
		_player.unlock(&"ch0_exit")
	SceneManager.change_map("goc_cay_da", "from_bus")


# --- Helpers -----------------------------------------------------------------

func _play_dialogue(cue: String) -> void:
	if _dialogue_res == null:
		return
	DialogueManager.show_dialogue_balloon(_dialogue_res, cue)
	await DialogueManager.dialogue_ended


func _load_dialogue() -> DialogueResource:
	# Ưu tiên load resource đã import; nếu chưa mở Godot editor import thì đọc trực tiếp file .dialogue
	if FileAccess.file_exists(DIALOGUE_PATH):
		var raw := FileAccess.get_file_as_string(DIALOGUE_PATH)
		if not raw.is_empty():
			return DialogueManager.create_resource_from_text(raw)
	if ResourceLoader.exists(DIALOGUE_PATH):
		return load(DIALOGUE_PATH) as DialogueResource
	return null


func _setup_highlight_materials() -> void:
	_bag_mat = _attach_highlight(_bag_sprite, Color(1.0, 0.93, 0.60, 1.0))
	_wardrobe_mat = _attach_highlight(_wardrobe_sprite, Color(1.0, 0.93, 0.60, 1.0))
	_door_mat = _attach_highlight(_door_sprite, Color(0.75, 0.90, 1.0, 1.0))


func _attach_highlight(spr: Sprite2D, col: Color) -> ShaderMaterial:
	if spr == null:
		return null
	var mat := ShaderMaterial.new()
	mat.shader = HIGHLIGHT_SHADER
	mat.set_shader_parameter(&"highlight", 0.0)
	mat.set_shader_parameter(&"outline_color", col)
	spr.material = mat
	return mat


func _build_overlay() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "Ch0FadeOverlay"
	_overlay_layer.layer = 85 # Dưới DialogueBalloon (100) để hội thoại hiện trên nền đen
	add_child(_overlay_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_layer.add_child(_fade_rect)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_layer.add_child(center)

	_end_box = VBoxContainer.new()
	_end_box.add_theme_constant_override(&"separation", 18)
	_end_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_end_box.hide()
	center.add_child(_end_box)

	var title := _make_label("Chương 0 — Lên đường về quê", 64, Color(0.98, 0.93, 0.78))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_box.add_child(title)

	var sub := _make_label("Minh mang theo điện thoại và bộ áo quần, bước ra khỏi căn phòng ở thành phố...", 40, Color(0.78, 0.80, 0.88))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_box.add_child(sub)

	var prompt := _make_label("[E] Tiếp tục đến Vườn rau   ·   [R] Chơi lại phân đoạn mở đầu", 36, Color(0.62, 0.74, 0.96))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_box.add_child(prompt)


func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "Ch0ObjectiveHUD"
	_hud_layer.layer = 50
	add_child(_hud_layer)

	_hud_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.11, 0.84)
	sb.border_color = Color(0.78, 0.76, 0.88, 0.75)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 20
	sb.content_margin_right = 22
	sb.content_margin_top = 12
	sb.content_margin_bottom = 14
	sb.anti_aliasing = false
	_hud_panel.add_theme_stylebox_override(&"panel", sb)
	_hud_panel.position = Vector2(36, 32)
	_hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(_hud_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override(&"separation", 4)
	_hud_panel.add_child(vb)

	vb.add_child(_make_label("Chuẩn bị đồ về quê", 40, Color(0.96, 0.84, 0.46)))
	_hud_phone = _make_label("", 34, Color(0.94, 0.93, 0.96))
	_hud_clothes = _make_label("", 34, Color(0.94, 0.93, 0.96))
	_hud_door = _make_label("", 34, Color(0.70, 0.86, 1.0))
	vb.add_child(_hud_phone)
	vb.add_child(_hud_clothes)
	vb.add_child(_hud_door)
	_hud_panel.hide()


func _refresh_hud() -> void:
	if _hud_phone == null:
		return
	var has_phone := GameState.has_flag(FLAG_GOT_PHONE)
	var has_clothes := GameState.has_flag(FLAG_GOT_CLOTHES)

	_hud_phone.text = ("[v] Điện thoại" if has_phone else "[ ] Tìm điện thoại")
	_hud_phone.add_theme_color_override(&"font_color", Color(0.62, 0.88, 0.56) if has_phone else Color(0.94, 0.93, 0.96))

	_hud_clothes.text = ("[v] Bộ áo quần" if has_clothes else "[ ] Lấy bộ áo quần")
	_hud_clothes.add_theme_color_override(&"font_color", Color(0.62, 0.88, 0.56) if has_clothes else Color(0.94, 0.93, 0.96))

	_hud_door.visible = has_phone and has_clothes
	_hud_door.text = "-> Đủ đồ rồi, ra cửa phòng"


func _make_label(txt: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override(&"font", FONT)
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", col)
	return l
