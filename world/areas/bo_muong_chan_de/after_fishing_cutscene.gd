extends Node
## Cutscene sau khi Minh câu đủ 5 con cá ở bờ mương chân đê (bo_muong_chan_de):
## 1. An hỏi Minh có định về thành phố không → Minh ngập ngừng trả lời.
## 2. An khuyên Minh ở lại chơi cùng mình + hiện emoji cười ấm áp.
## 3. Minh hiện emoji bối rối/xúc động.
## 4. Bụng Minh đói reo lên ("Ọt ọt..." + âm thanh bụng đói).
## 5. An bật cười trêu Minh → Minh hiện emoji chảy mồ hôi.
## 6. An rủ Minh đi tới chỗ có đồ ăn bao la!

const FONT := preload("res://assets/fonts/vt323_regular.ttf")
const DIALOGUE_PATH := "res://data/dialogues/ch1_after_fishing.dialogue"

const EMOTE_SMILE_PATH := "res://assets/ui/emotes/emote_smile.png"
const EMOTE_SHY_PATH := "res://assets/ui/emotes/emote_shy.png"
const EMOTE_SWEAT_PATH := "res://assets/ui/emotes/emote_sweat.png"

const SFX_GROWL_PATH := "res://assets/audio/sfx/stomach_growl.wav"
const SFX_WARM := "res://assets/audio/sfx/fishing/na_help.wav"
const SFX_SOFT := "res://assets/audio/sfx/typing/key_02.wav"

const FLAG_DONE := "ch1.after_fishing_cutscene_done"
const FISH_TARGET := 5

var _running: bool = false
var _sfx_player: AudioStreamPlayer = null
var _fx_layer: Node2D = null
var _pop_texts: Array[Dictionary] = []


func _ready() -> void:
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.volume_db = -3.0
	add_child(_sfx_player)
	GameState.changed.connect(_check_trigger)
	_check_trigger()


func _check_trigger() -> void:
	if _running or GameState.has_flag(FLAG_DONE):
		return
	if GameState.current_map != "bo_muong_chan_de":
		return
	if GameState.item_count("fish") >= FISH_TARGET:
		call_deferred("_run_cutscene")


func _run_cutscene() -> void:
	if _running or not is_inside_tree():
		return
	_running = true

	var map_node: Node2D = get_parent() as Node2D
	# Khoá input câu cá ngay để Minh & An giữ nguyên tư thế đang ngồi câu trên ghế đá suốt đoạn hội thoại
	var spot: Node = map_node.get_node_or_null("Objects/FishingSpot")
	var active_in_map: Node = null
	if spot:
		var candidate: Variant = spot.get("_in_map")
		if candidate != null and is_instance_valid(candidate) and candidate is Node:
			active_in_map = candidate as Node
			if active_in_map.has_method("set_cutscene_talking"):
				active_in_map.call("set_cutscene_talking", true)

	# Chờ một nhịp ngắn cho hiệu ứng câu con cá thứ 5 + emoji vui kịp hiện xong
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return

	await get_tree().process_frame
	if not is_inside_tree():
		return

	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	var an_node: Node2D = get_tree().get_first_node_in_group(&"companion") as Node2D
	var is_seated: bool = player != null and player.pose == Player.POSE_SIT
	var sit_offset: float = player.sit_drop if is_seated else 0.0

	if player:
		player.lock(&"after_fishing_cutscene")

	_fx_layer = Node2D.new()
	_fx_layer.name = "AfterFishingFX"
	_fx_layer.z_index = 45
	_fx_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fx_layer.draw.connect(_draw_fx)
	map_node.add_child(_fx_layer)

	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree():
		return

	var dlg := _load_dialogue()

	# 1. Hội thoại ấm áp khi cả hai vẫn đang ngồi câu cá cạnh nhau trên ghế đá
	if dlg:
		DialogueManager.show_dialogue_balloon(dlg, "part1")
		await DialogueManager.dialogue_ended
	if not is_inside_tree():
		return

	# 2. An hiện emoji cười ấm áp
	if an_node and an_node.visible:
		await _show_emote(map_node, an_node.global_position + Vector2(0.0, -108.0 + sit_offset), EMOTE_SMILE_PATH, SFX_WARM, 1.08, "bob")
		if not is_inside_tree():
			return

	# 3. Minh hiện emoji ngại / xúc động nhẹ
	if player:
		await _show_emote(map_node, player.get_speech_anchor() + Vector2(0.0, sit_offset - 4.0), EMOTE_SHY_PATH, SFX_SOFT, 0.92, "pop_hold")
		if not is_inside_tree():
			return

	await get_tree().create_timer(0.45).timeout
	if not is_inside_tree():
		return

	# 4. Bụng Minh đói reo lên!
	_play_wav_or_res(SFX_GROWL_PATH, 1.0)
	if player:
		var belly_pos: Vector2 = player.global_position + Vector2(-18.0, 6.0 + sit_offset)
		_add_pop_text("Ọt ọt...", belly_pos, Color(1.0, 0.96, 0.80), 1.05)
		# Rung nhẹ người Minh lúc bụng kêu
		var orig_x: float = player.anim.position.x
		var tw_g := create_tween()
		for k: int in range(6):
			var dx: float = -1.5 if k % 2 == 0 else 1.5
			tw_g.tween_property(player.anim, "position:x", orig_x + dx, 0.05)
		tw_g.tween_property(player.anim, "position:x", orig_x, 0.05)
		await tw_g.finished
		if not is_inside_tree():
			return

	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree():
		return

	# 5. An bật cười: "Hahaa, cậu đói bụng rồi à?"
	if dlg:
		DialogueManager.show_dialogue_balloon(dlg, "part2")
		await DialogueManager.dialogue_ended
	if not is_inside_tree():
		return

	# 6. Minh hiện emoji chảy mồ hôi
	if player:
		await _show_emote(map_node, player.get_speech_anchor() + Vector2(0.0, sit_offset - 4.0), EMOTE_SWEAT_PATH, SFX_SOFT, 0.80, "shake")
		if not is_inside_tree():
			return

	# 7. An rủ đi chỗ đồ ăn bao la
	if dlg:
		DialogueManager.show_dialogue_balloon(dlg, "part3")
		await DialogueManager.dialogue_ended
	if not is_inside_tree():
		return

	# Kết thúc thoại → đứng dậy thu cần câu và chuyển thẳng sang map Ruộng dưa bắt đầu quest trộm dưa!
	GameState.set_flag(FLAG_DONE, true)
	GameState.npc_set("an", "following", true)
	if is_instance_valid(active_in_map) and active_in_map.has_method("close"):
		active_in_map.call("close")
	if is_instance_valid(player):
		player.unlock(&"after_fishing_cutscene")
	_running = false
	SceneManager.change_map("ruong_dua")


func _process(delta: float) -> void:
	if not _pop_texts.is_empty():
		var kept: Array[Dictionary] = []
		for pt: Dictionary in _pop_texts:
			var life: float = float(pt["life"]) + delta
			pt["life"] = life
			if life < float(pt["max_life"]):
				var pos: Vector2 = pt["pos"]
				pos.y -= delta * 14.0
				pt["pos"] = pos
				kept.append(pt)
		_pop_texts = kept
		if is_instance_valid(_fx_layer):
			_fx_layer.queue_redraw()
	elif not _running and is_instance_valid(_fx_layer):
		_fx_layer.queue_free()
		_fx_layer = null


func _add_pop_text(txt: String, pos: Vector2, col: Color, dur: float) -> void:
	_pop_texts.append({
		"txt": txt,
		"pos": pos,
		"col": col,
		"life": 0.0,
		"max_life": dur,
	})
	if is_instance_valid(_fx_layer):
		_fx_layer.queue_redraw()


func _draw_fx() -> void:
	if not is_instance_valid(_fx_layer):
		return
	for pt: Dictionary in _pop_texts:
		var k: float = float(pt["life"]) / float(pt["max_life"])
		var alpha: float = clampf(1.0 - maxf(0.0, k - 0.55) / 0.45, 0.0, 1.0)
		var pos: Vector2 = (pt["pos"] as Vector2).round()
		var txt: String = String(pt["txt"])
		var col: Color = pt["col"]
		_fx_layer.draw_string(FONT, pos + Vector2(1.0, 1.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.08, 0.06, 0.06, alpha))
		_fx_layer.draw_string(FONT, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(col.r, col.g, col.b, alpha))


func _show_emote(map_node: Node2D, world_anchor: Vector2, tex_path: String, sfx_path: String, pitch: float, style: String = "bob") -> void:
	var tex: Texture2D = _load_png(tex_path)
	if tex == null:
		return
	var emote := Sprite2D.new()
	emote.texture = tex
	emote.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	emote.centered = false
	emote.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height())
	emote.z_index = 45
	emote.scale = Vector2(0.15, 0.15)
	map_node.add_child(emote)
	emote.global_position = world_anchor

	_play_wav_or_res(sfx_path, pitch)

	var tw_pop := create_tween()
	tw_pop.tween_property(emote, "scale", Vector2(1.20, 1.20), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_pop.tween_property(emote, "scale", Vector2(1.0, 1.0), 0.09)
	await tw_pop.finished
	if not is_inside_tree():
		return

	var base_pos: Vector2 = emote.position
	if style == "shake":
		var tw_sh := create_tween()
		for k: int in range(6):
			var dx: float = -2.0 if k % 2 == 0 else 2.0
			tw_sh.tween_property(emote, "position:x", base_pos.x + dx, 0.06)
		tw_sh.tween_property(emote, "position:x", base_pos.x, 0.06)
		tw_sh.tween_interval(0.32)
		await tw_sh.finished
	elif style == "pop_hold":
		var tw_hold := create_tween()
		tw_hold.tween_property(emote, "position:y", base_pos.y - 3.0, 0.16).set_trans(Tween.TRANS_SINE)
		tw_hold.tween_property(emote, "position:y", base_pos.y, 0.16).set_trans(Tween.TRANS_SINE)
		tw_hold.tween_interval(0.42)
		await tw_hold.finished
	else:
		var tw_bob := create_tween()
		tw_bob.tween_property(emote, "position:y", base_pos.y - 3.0, 0.24).set_trans(Tween.TRANS_SINE)
		tw_bob.tween_property(emote, "position:y", base_pos.y, 0.24).set_trans(Tween.TRANS_SINE)
		tw_bob.tween_property(emote, "position:y", base_pos.y - 2.0, 0.24).set_trans(Tween.TRANS_SINE)
		tw_bob.tween_property(emote, "position:y", base_pos.y, 0.24).set_trans(Tween.TRANS_SINE)
		await tw_bob.finished

	if not is_inside_tree():
		return

	var tw_out := create_tween()
	tw_out.tween_property(emote, "modulate:a", 0.0, 0.18)
	await tw_out.finished
	if is_instance_valid(emote):
		emote.queue_free()


func _play_wav_or_res(res_path: String, pitch: float = 1.0) -> void:
	if _sfx_player == null:
		return
	var stream: AudioStream = null
	if ResourceLoader.exists(res_path):
		stream = load(res_path) as AudioStream
	if stream == null:
		var abs_path := ProjectSettings.globalize_path(res_path)
		if FileAccess.file_exists(abs_path) and abs_path.ends_with(".wav"):
			stream = AudioStreamWAV.load_from_file(abs_path)
	if stream:
		_sfx_player.stream = stream
		_sfx_player.pitch_scale = pitch
		_sfx_player.play()


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
