extends Node
## Cutscene kết thúc Chương 1 tại phòng khách (living_room) giữa Minh và Ông Nội:
## 1. Sau khi hái & lăn quả dưa khổng lồ về nhà (ch1.melon_carry_done), Minh và Ông Nội trò chuyện.
## 2. Minh bật emoji buồn khi ông nhắc chuyện thành đạt, rồi emoji xúc động khi ông bảo muốn cháu khỏe mạnh hơn.
## 3. Ông gọi đi ăn cơm → fade đen → "Kết thúc Chương 1" → "Chương 2" → chuyển sang sáng Chương 2.

const DIALOGUE_PATH := "res://data/dialogues/ch1_ending.dialogue"
const FONT := preload("res://assets/fonts/vt323_regular.ttf")

const EMOTE_SAD_PATH := "res://assets/ui/emotes/emote_sad.png"
const EMOTE_TOUCHED_PATH := "res://assets/ui/emotes/emote_touched.png"
const SFX_SOFT := "res://assets/audio/sfx/fishing/na_help.wav"

const FLAG_MELON_DONE := "ch1.melon_carry_done"
const FLAG_CH1_ENDING_DONE := "ch1.ending_done"
const FLAG_CH1_COMPLETE := "ch1.complete"

var _running: bool = false
var _sfx: AudioStreamPlayer = null
var _title_layer: CanvasLayer = null
var _fade_rect: ColorRect = null
var _title_box: VBoxContainer = null
var _title_top: Label = null
var _title_main: Label = null


func _ready() -> void:
	if not GameState.has_flag(FLAG_MELON_DONE) or GameState.has_flag(FLAG_CH1_ENDING_DONE):
		return
	_sfx = AudioStreamPlayer.new()
	_sfx.volume_db = -8.0
	add_child(_sfx)
	call_deferred("_run_ending")


func _run_ending() -> void:
	if _running or not is_inside_tree():
		return
	_running = true

	# Chờ 1 frame để Main đặt Minh ở Spawns/after_melon xong
	await get_tree().process_frame
	if not is_inside_tree():
		return

	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	var ong_node: Node2D = get_parent().get_node_or_null("NPCs/OngNoi") as Node2D
	if player:
		player.lock(&"ch1_ending")
		player.velocity = Vector2.ZERO
		player.anim.flip_h = false # Minh quay phải nhìn Ông Nội
	if ong_node:
		var ong_spr: AnimatedSprite2D = ong_node.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if ong_spr:
			ong_spr.flip_h = true # Ông Nội quay trái nhìn Minh

	# Chờ SceneManager fade sáng xong vào phòng khách
	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree():
		return

	var dlg := _load_dialogue()
	var world_node: Node = player.get_parent() if player else get_parent()

	# 1. Minh khoe cá & dưa hấu → Ông khen nấu bữa thịnh soạn → Minh hỏi ông có giận không
	if dlg:
		DialogueManager.show_dialogue_balloon(dlg, "part1")
		await DialogueManager.dialogue_ended
	if not is_inside_tree():
		return

	# 2. Minh bật emoji buồn
	if player:
		await _show_emote(world_node, player.get_speech_anchor() + Vector2(0.0, -4.0), EMOTE_SAD_PATH, 0.85, "sad")
		if not is_inside_tree():
			return

	# 3. Ông Nội: "Nhưng ông muốn cháu mình sống khỏe mạnh hơn."
	if dlg:
		DialogueManager.show_dialogue_balloon(dlg, "part2")
		await DialogueManager.dialogue_ended
	if not is_inside_tree():
		return

	# 4. Minh bật emoji ngẩn người / xúc động
	if player:
		await _show_emote(world_node, player.get_speech_anchor() + Vector2(0.0, -4.0), EMOTE_TOUCHED_PATH, 1.0, "soft_hold")
		if not is_inside_tree():
			return

	# 5. Ông Nội: "Thôi, ăn cơm thôi."
	if dlg:
		DialogueManager.show_dialogue_balloon(dlg, "part3")
		await DialogueManager.dialogue_ended
	if not is_inside_tree():
		return

	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree():
		return

	# 6. Fade đen → Kết thúc Chương 1 → Chương 2!
	_build_chapter_overlay()
	var tw_dark := create_tween()
	tw_dark.tween_property(_fade_rect, "color:a", 1.0, 1.0)
	await tw_dark.finished
	if not is_inside_tree():
		return

	# Hiện "Kết thúc Chương 1"
	_set_title_card("Kết thúc", "Chương 1", Color(0.78, 0.80, 0.88), Color(0.96, 0.94, 0.88))
	await _show_and_hide_title_card(0.75, 1.5, 0.65)
	if not is_inside_tree():
		return

	# Cập nhật tiến trình sang Chương 2
	GameState.set_flag(FLAG_CH1_ENDING_DONE, true)
	GameState.set_flag(FLAG_CH1_COMPLETE, true)
	GameState.chapter = 2
	GameState.day = 2
	GameState.time = "morning"

	await get_tree().create_timer(0.4).timeout
	if not is_inside_tree():
		return

	# Hiện thẻ tên "Chương 2"
	_set_title_card("Chương 2", "Những ngày ở Làng Cỏ", Color(0.96, 0.84, 0.48), Color(0.98, 0.96, 0.90))
	await _show_and_hide_title_card(0.85, 2.2, 0.75)
	if not is_inside_tree():
		return

	if is_instance_valid(player):
		player.unlock(&"ch1_ending")
	_running = false

	# Chuyển mượt trên nền đen sang sáng Chương 2 ở phòng ngủ Minh
	SceneManager.change_map("phong_ngu_minh", "wake_up")


func _build_chapter_overlay() -> void:
	_title_layer = CanvasLayer.new()
	_title_layer.name = "Chapter2TitleOverlay"
	_title_layer.layer = 92
	add_child(_title_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_title_layer.add_child(_fade_rect)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_layer.add_child(center)

	_title_box = VBoxContainer.new()
	_title_box.add_theme_constant_override(&"separation", 14)
	_title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_title_box.modulate.a = 0.0
	_title_box.hide()
	center.add_child(_title_box)

	_title_top = _make_label("", 50, Color(0.96, 0.84, 0.48))
	_title_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(_title_top)

	_title_main = _make_label("", 80, Color(0.98, 0.96, 0.90))
	_title_main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(_title_main)


func _set_title_card(top_txt: String, main_txt: String, top_col: Color, main_col: Color) -> void:
	_title_top.text = top_txt
	_title_top.add_theme_color_override(&"font_color", top_col)
	_title_main.text = main_txt
	_title_main.add_theme_color_override(&"font_color", main_col)


func _show_and_hide_title_card(fade_in: float, hold: float, fade_out: float) -> void:
	_title_box.modulate.a = 0.0
	_title_box.show()
	var tw_in := create_tween()
	tw_in.tween_property(_title_box, "modulate:a", 1.0, fade_in)
	await tw_in.finished
	if not is_inside_tree():
		return

	await get_tree().create_timer(hold).timeout
	if not is_inside_tree():
		return

	var tw_out := create_tween()
	tw_out.tween_property(_title_box, "modulate:a", 0.0, fade_out)
	await tw_out.finished
	if is_inside_tree():
		_title_box.hide()


func _show_emote(parent_node: Node, world_anchor: Vector2, tex_path: String, pitch: float, style: String = "sad") -> void:
	var tex: Texture2D = _load_png(tex_path)
	if tex == null or parent_node == null:
		return
	var emote := Sprite2D.new()
	emote.texture = tex
	emote.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	emote.centered = false
	emote.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height())
	emote.z_index = 60
	emote.scale = Vector2(0.15, 0.15)
	parent_node.add_child(emote)
	emote.global_position = world_anchor

	if _sfx and ResourceLoader.exists(SFX_SOFT):
		var stream: AudioStream = load(SFX_SOFT) as AudioStream
		if stream:
			_sfx.stream = stream
			_sfx.pitch_scale = pitch
			_sfx.play()

	var tw_pop := create_tween()
	tw_pop.tween_property(emote, "scale", Vector2(1.16, 1.16), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_pop.tween_property(emote, "scale", Vector2(1.0, 1.0), 0.10)
	await tw_pop.finished
	if not is_inside_tree():
		return

	var base_pos: Vector2 = emote.position
	if style == "sad":
		var tw_sad := create_tween()
		tw_sad.tween_property(emote, "position:y", base_pos.y + 3.0, 0.42).set_trans(Tween.TRANS_SINE)
		tw_sad.tween_interval(0.55)
		await tw_sad.finished
	else:
		var tw_soft := create_tween()
		tw_soft.tween_property(emote, "position:y", base_pos.y - 2.5, 0.25).set_trans(Tween.TRANS_SINE)
		tw_soft.tween_property(emote, "position:y", base_pos.y, 0.25).set_trans(Tween.TRANS_SINE)
		tw_soft.tween_interval(0.55)
		await tw_soft.finished

	if not is_inside_tree():
		return

	var tw_out := create_tween()
	tw_out.tween_property(emote, "modulate:a", 0.0, 0.20)
	await tw_out.finished
	if is_instance_valid(emote):
		emote.queue_free()


func _make_label(txt: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override(&"font", FONT)
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", col)
	return l


func _load_dialogue() -> DialogueResource:
	if FileAccess.file_exists(DIALOGUE_PATH):
		var raw := FileAccess.get_file_as_string(DIALOGUE_PATH)
		if not raw.is_empty():
			return DialogueManager.create_resource_from_text(raw)
	if ResourceLoader.exists(DIALOGUE_PATH):
		return load(DIALOGUE_PATH) as DialogueResource
	return null


func _load_png(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		var res: Resource = load(res_path)
		if res is Texture2D:
			return res
	var abs_path := ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img:
			return ImageTexture.create_from_image(img)
	return null
