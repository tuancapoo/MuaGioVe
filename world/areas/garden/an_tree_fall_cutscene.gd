extends Node
## Cutscene sau khi Minh vừa sửa xong ống nước ở map garden:
## 1. Khoảng lặng nhẹ khi vòi nước vừa hết rỉ.
## 2. Tiếng động trên tán cây xoài ("Sột soạt..." → "Rắc!"), tán cây rung lắc, lá xoài rơi lả tả xuống đất.
## 3. Cắt màn hình đen ngắn + tiếng cành gãy.
## 4. Màn hình sáng bật lại: An từ trên tán cây rơi thẳng xuống sát vòi nước (đất bụi tung lên, rung camera),
##    ống nước bị đập vỡ tung trở lại và phun nước bắn tung tóe mạnh hơn trước gấp nhiều lần!

const FONT := preload("res://assets/fonts/vt323_regular.ttf")
const DIALOGUE_PATH := "res://data/dialogues/ch1_pipe_intro.dialogue"
const EMOTE_COOL_PATH := "res://assets/ui/emotes/emote_cool.png"
const EMOTE_EXCLAIM_PATH := "res://assets/ui/emotes/emote_exclaim.png"
const EMOTE_SHOCK_PATH := "res://assets/ui/emotes/emote_shock.png"
const EMOTE_HAPPY_PATH := "res://assets/ui/emotes/emote_happy.png"
const EMOTE_SIGH_PATH := "res://assets/ui/emotes/emote_sigh.png"
const EMOTE_QUESTION_PATH := "res://assets/ui/emotes/emote_question.png"
const SFX_COOL := "res://assets/audio/sfx/fishing/catch.wav"
const SFX_EXCLAIM := "res://assets/audio/sfx/fishing/nibble.wav"
const SFX_HAPPY := "res://assets/audio/sfx/fishing/na_help.wav"
const SFX_RUSTLE := "res://assets/audio/sfx/footsteps/grass_walk.mp3"
const SFX_WALK := "res://assets/audio/sfx/footsteps/dirt_walk.mp3"
const SFX_RUN := "res://assets/audio/sfx/footsteps/dirt_run.mp3"
const SFX_SNAP := "res://assets/audio/sfx/fishing/cast.wav"
const SFX_CRASH := "res://assets/audio/sfx/fishing/miss.wav"
const SFX_SPLASH := "res://assets/audio/sfx/fishing/bite.wav"

const FLAG_AN_FELL := "ch1.an_fell_from_tree"
const FLAG_PIPE_FIXED_AFTER_AN := "ch1.pipe_fixed_after_an"
const FLAG_AFTER_WATER_DONE := "ch1.after_water_cutscene_done"
const FLAG_CHASE_AN := "ch1.chase_an_fishing"

var _running: bool = false
var _fx_layer: Node2D = null
var _black_layer: CanvasLayer = null
var _black_rect: ColorRect = null
var _sfx_player: AudioStreamPlayer = null

var _leaves: Array[Dictionary] = []
var _dust_puffs: Array[Dictionary] = []
var _pop_texts: Array[Dictionary] = []
var _tree_shake_timer: float = 0.0
var _tree_shake_amp: float = 0.0
var _cam_shake_timer: float = 0.0
var _cam_shake_amp: float = 0.0
var _t: float = 0.0

var _tree_sprite: Sprite2D = null
var _mango_sprite: Sprite2D = null
var _tree_base_pos: Vector2 = Vector2.ZERO
var _mango_base_pos: Vector2 = Vector2.ZERO
var _camera: Camera2D = null


func _ready() -> void:
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.volume_db = -5.0
	add_child(_sfx_player)
	MinigameManager.minigame_closed.connect(_on_minigame_closed)


func _on_minigame_closed(minigame_id: String, result: Dictionary) -> void:
	if _running or not bool(result.get("success", false)):
		return
	if minigame_id == "fix_pipe" and not GameState.has_flag(FLAG_AN_FELL):
		call_deferred("_run_cutscene")
	elif minigame_id == "water_garden" and GameState.has_flag(FLAG_AN_FELL) and not GameState.has_flag(FLAG_AFTER_WATER_DONE):
		call_deferred("_run_after_watering_cutscene")


func _run_cutscene() -> void:
	if _running or not is_inside_tree():
		return
	_running = true

	var map_node: Node2D = get_parent() as Node2D
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	var faucet: Node2D = map_node.get_node_or_null("Objects/GardenFaucet") as Node2D
	var an_node: Node2D = map_node.get_node_or_null("NPCs/AnGarden") as Node2D
	_tree_sprite = map_node.get_node_or_null("Background/08_Cay_xoai") as Sprite2D
	_mango_sprite = map_node.get_node_or_null("Background/09_Qua_xoai_vang") as Sprite2D
	if _tree_sprite:
		_tree_base_pos = _tree_sprite.position
	if _mango_sprite:
		_mango_base_pos = _mango_sprite.position

	if player:
		player.lock(&"an_tree_fall")
		_camera = player.camera
		# Đặt Minh đứng gọn bên phải vòi nước một chút để không bị đè khi An rơi xuống sát vòi
		if player.global_position.x < 378.0:
			player.global_position.x = 382.0
		player.anim.flip_h = true # Quay sang trái nhìn vòi nước & gốc cây xoài

	# Lớp hiệu ứng lá rơi, chữ âm thanh & bụi rơi trong thế giới
	_fx_layer = Node2D.new()
	_fx_layer.name = "TreeFallFX"
	_fx_layer.z_index = 25
	_fx_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fx_layer.draw.connect(_draw_fx)
	map_node.add_child(_fx_layer)

	# Lớp màn hình đen cho nhịp cắt đột ngột
	_black_layer = CanvasLayer.new()
	_black_layer.name = "TreeFallBlack"
	_black_layer.layer = 86
	add_child(_black_layer)

	_black_rect = ColorRect.new()
	_black_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_black_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_black_layer.add_child(_black_rect)

	# --- Nhịp 1: Minh tự đắc hiện bong bóng emoji kính râm rồi tự thoại "Mình đúng là thiên tài." ---
	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree():
		return

	if player:
		await _show_emote(map_node, player.get_speech_anchor() + Vector2(0.0, -4.0), EMOTE_COOL_PATH, SFX_COOL, 1.18, "bob")
		if not is_inside_tree():
			return

	var dlg := _load_dialogue()
	if dlg:
		DialogueManager.show_dialogue_balloon(dlg, "pipe_fixed_brag")
		await DialogueManager.dialogue_ended
	if not is_inside_tree():
		return

	await get_tree().create_timer(0.28).timeout
	if not is_inside_tree():
		return

	# --- Nhịp 2: Tiếng động trên tán cây xoài + tán cây rung + lá rơi + Minh bật emoji "!" ---
	_trigger_tree_shake(0.55, 2.5)
	_play_sfx(SFX_RUSTLE, 1.15)
	_spawn_leaves(18)
	_add_pop_text("Sột soạt...", Vector2(238.0, 118.0), Color(0.96, 0.96, 0.84), 0.95)

	if player:
		await _show_emote(map_node, player.get_speech_anchor() + Vector2(0.0, -4.0), EMOTE_EXCLAIM_PATH, SFX_EXCLAIM, 1.15, "pop_hold")
		if not is_inside_tree():
			return
	else:
		await get_tree().create_timer(0.85).timeout
		if not is_inside_tree():
			return

	# Rung mạnh đợt 2 + tiếng cành cây sắp gãy + thêm nhiều lá rơi
	_trigger_tree_shake(0.65, 4.0)
	_play_sfx(SFX_SNAP, 0.72)
	_spawn_leaves(24)
	_add_pop_text("RẮC!!", Vector2(286.0, 134.0), Color(1.0, 0.84, 0.42), 0.65)

	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree():
		return

	# --- Nhịp 3: Cắt màn hình đen ngắn kèm tiếng cành gãy ---
	var tw_dark := create_tween()
	tw_dark.tween_property(_black_rect, "color:a", 1.0, 0.16)
	await tw_dark.finished
	if not is_inside_tree():
		return

	_play_sfx(SFX_SNAP, 0.52)
	await get_tree().create_timer(0.42).timeout
	if not is_inside_tree():
		return

	# Chuẩn bị An ở trên cao ngay dưới tán xoài sát vòi nước để rơi thẳng xuống lúc màn hình bật sáng
	var an_land_pos := Vector2(304.0, 316.0)
	var an_spr: AnimatedSprite2D = null
	if an_node:
		GameState.set_flag(FLAG_AN_FELL, true)
		an_node.visible = true
		an_node.position = Vector2(an_land_pos.x, 152.0)
		an_spr = an_node.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if an_spr:
			an_spr.flip_h = false # Hướng sang phải về phía vòi nước & Minh
			if an_spr.sprite_frames and an_spr.sprite_frames.has_animation(&"Sit"):
				an_spr.play(&"Sit")

	# --- Nhịp 4: Màn hình sáng bật lại → An rơi thẳng xuống đất sát vòi nước! ---
	var tw_lit := create_tween()
	tw_lit.tween_property(_black_rect, "color:a", 0.0, 0.22)

	if an_node:
		var tw_fall := create_tween()
		tw_fall.tween_property(an_node, "position:y", an_land_pos.y, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw_fall.finished
	else:
		await get_tree().create_timer(0.24).timeout

	if not is_inside_tree():
		return

	# ĐÚNG LÚC CHẠM ĐẤT: Rung màn hình + bụi tung + ống nước vỡ tung bắn nước tung tóe mạnh hơn trước!
	_play_sfx(SFX_CRASH, 0.78)
	_trigger_cam_shake(0.48, 5.5)
	_spawn_dust(an_land_pos)
	_spawn_leaves(14)
	_add_pop_text("RẦM!!", Vector2(316.0, 224.0), Color(1.0, 0.90, 0.56), 0.75)

	if faucet and faucet.has_method("trigger_burst_explosion"):
		faucet.call("trigger_burst_explosion")
	else:
		GameState.set_flag("ch1.pipe_burst_by_an", true)

	# Nảy nhẹ cú tiếp đất của An
	if an_node:
		var tw_bounce := create_tween()
		tw_bounce.tween_property(an_node, "position:y", an_land_pos.y - 8.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_bounce.tween_property(an_node, "position:y", an_land_pos.y, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw_bounce.finished

	await get_tree().create_timer(0.18).timeout
	if not is_inside_tree():
		return
	_play_sfx(SFX_SPLASH, 1.05)

	await get_tree().create_timer(0.45).timeout
	if not is_inside_tree():
		return

	# --- Nhịp 5: Minh bật emoji hoảng sợ + thoại "Ôi ống nước của tôi!!" ---
	if player:
		await _show_emote(map_node, player.get_speech_anchor() + Vector2(0.0, -4.0), EMOTE_SHOCK_PATH, SFX_CRASH, 1.05, "shake")
		if not is_inside_tree():
			return

	if dlg:
		DialogueManager.show_dialogue_balloon(dlg, "pipe_burst_shock")
		await DialogueManager.dialogue_ended
	if not is_inside_tree():
		return

	# --- Nhịp 6: An đứng dậy, bật emoji vui + hội thoại nhận ra Minh & đòi sửa + tưới cây giúp ---
	if an_spr and an_spr.sprite_frames and an_spr.sprite_frames.has_animation(&"Idle"):
		an_spr.play(&"Idle")

	await get_tree().create_timer(0.18).timeout
	if not is_inside_tree():
		return

	if an_node:
		await _show_emote(map_node, an_node.global_position + Vector2(0.0, -108.0), EMOTE_HAPPY_PATH, SFX_HAPPY, 1.08, "bob")
		if not is_inside_tree():
			return

	if dlg:
		DialogueManager.show_dialogue_balloon(dlg, "an_reunion_and_help")
		await DialogueManager.dialogue_ended
	if not is_inside_tree():
		return

	# --- Nhịp 7: Màn hình đen → An sửa xong ống nước → Sáng lên thấy vòi hết rỉ → Vào thẳng tưới cây! ---
	var tw_fix_dark := create_tween()
	tw_fix_dark.tween_property(_black_rect, "color:a", 1.0, 0.40)
	await tw_fix_dark.finished
	if not is_inside_tree():
		return

	# Tiếng sửa ống lạch cạch trong màn hình đen + khôi phục vòi nước đã sửa kín
	_play_sfx(SFX_SNAP, 1.25)
	await get_tree().create_timer(0.45).timeout
	if not is_inside_tree():
		return
	GameState.set_flag(FLAG_PIPE_FIXED_AFTER_AN, true)
	_play_sfx(SFX_COOL, 1.05)
	await get_tree().create_timer(0.45).timeout
	if not is_inside_tree():
		return

	# Sáng lại để thấy vòi nước đã được sửa kín không còn phun nước nữa
	var tw_fix_lit := create_tween()
	tw_fix_lit.tween_property(_black_rect, "color:a", 0.0, 0.40)
	await tw_fix_lit.finished
	if not is_inside_tree():
		return

	await get_tree().create_timer(0.75).timeout
	if not is_inside_tree():
		return

	# Dọn lớp overlay đen, mở khóa Minh và vào thẳng minigame tưới rau!
	if is_instance_valid(_black_layer):
		_black_layer.queue_free()
	if is_instance_valid(player):
		player.unlock(&"an_tree_fall")
	_running = false

	if not GameState.has_flag("ch1.garden_watered") and not MinigameManager.is_running():
		MinigameManager.start("water_garden")


func _run_after_watering_cutscene() -> void:
	if _running or not is_inside_tree():
		return
	_running = true

	var map_node: Node2D = get_parent() as Node2D
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	var an_node: Node2D = map_node.get_node_or_null("NPCs/AnGarden") as Node2D
	var ong_node: Node2D = map_node.get_node_or_null("NPCs/OngNoi") as Node2D

	if player:
		player.lock(&"after_water_cutscene")
		player.anim.flip_h = true # Quay sang trái nhìn An

	var an_spr: AnimatedSprite2D = null
	if an_node:
		an_node.visible = true
		an_node.position = Vector2(304.0, 316.0)
		an_spr = an_node.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if an_spr:
			an_spr.flip_h = false # Hướng sang phải nhìn Minh
			if an_spr.sprite_frames and an_spr.sprite_frames.has_animation(&"Idle"):
				an_spr.play(&"Idle")

	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree():
		return

	var dlg := _load_dialogue()

	# 1. An hiện emoji vui + thoại rủ Minh đi câu cá
	if an_node:
		await _show_emote(map_node, an_node.global_position + Vector2(0.0, -108.0), EMOTE_HAPPY_PATH, SFX_HAPPY, 1.12, "bob")
		if not is_inside_tree():
			return

	if dlg:
		DialogueManager.show_dialogue_balloon(dlg, "after_water_part1")
		await DialogueManager.dialogue_ended
	if not is_inside_tree():
		return

	# 2. An hiện emoji thở dài + "Thôi đi đi mà!"
	if an_node:
		await _show_emote(map_node, an_node.global_position + Vector2(0.0, -108.0), EMOTE_SIGH_PATH, SFX_SNAP, 0.72, "pop_hold")
		if not is_inside_tree():
			return

	if dlg:
		DialogueManager.show_dialogue_balloon(dlg, "after_water_part2")
		await DialogueManager.dialogue_ended
	if not is_inside_tree():
		return

	# 3. Ông Nội đi bộ từ từ từ ngoài sân (bên phải) vào vườn bằng animation Walk rồi đứng ở đó luôn
	GameState.set_flag("ch1.ong_in_garden", true)
	if ong_node:
		ong_node.visible = true
		ong_node.position = Vector2(724.0, 316.0)
		var ong_spr: AnimatedSprite2D = ong_node.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if ong_spr:
			ong_spr.flip_h = true # Đi từ phải sang trái
			if ong_spr.sprite_frames and ong_spr.sprite_frames.has_animation(&"Walk"):
				ong_spr.play(&"Walk")
		var tw_walk := create_tween()
		tw_walk.tween_property(ong_node, "position:x", 492.0, 3.1).set_trans(Tween.TRANS_LINEAR)
		await tw_walk.finished
		if not is_inside_tree():
			return
		if ong_spr and ong_spr.sprite_frames and ong_spr.sprite_frames.has_animation(&"Idle"):
			ong_spr.play(&"Idle")

	if player:
		player.anim.flip_h = false # Minh quay sang phải nhìn Ông Nội

	await get_tree().create_timer(0.18).timeout
	if not is_inside_tree():
		return

	# 4. An gọi ông xin đi chơi
	if dlg:
		DialogueManager.show_dialogue_balloon(dlg, "after_water_part3")
		await DialogueManager.dialogue_ended
	if not is_inside_tree():
		return

	# 5. Minh bật emoji "?" + thoại "Wtf?!"
	if player:
		await _show_emote(map_node, player.get_speech_anchor() + Vector2(0.0, -4.0), EMOTE_QUESTION_PATH, SFX_EXCLAIM, 0.95, "pop_hold")
		if not is_inside_tree():
			return

	if dlg:
		DialogueManager.show_dialogue_balloon(dlg, "after_water_part4")
		await DialogueManager.dialogue_ended
	if not is_inside_tree():
		return

	# 6. Ông Nội bảo "Hai đứa đi chơi vui vẻ nhé."
	if dlg:
		DialogueManager.show_dialogue_balloon(dlg, "after_water_part5")
		await DialogueManager.dialogue_ended
	if not is_inside_tree():
		return

	# 7. An chạy vụt sang phải ra khỏi vườn để dẫn Minh đi câu cá (không phát tiếng chạy)
	if an_node:
		if an_spr:
			an_spr.flip_h = false
			if an_spr.sprite_frames and an_spr.sprite_frames.has_animation(&"Run"):
				an_spr.play(&"Run")
		var tw_run := create_tween()
		tw_run.tween_property(an_node, "position:x", 756.0, 1.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await tw_run.finished
		if not is_inside_tree():
			return
		an_node.visible = false

	GameState.set_flag(FLAG_AFTER_WATER_DONE, true)
	GameState.set_flag(FLAG_CHASE_AN, true)

	if is_instance_valid(player):
		player.unlock(&"after_water_cutscene")
	_running = false


func _trigger_tree_shake(duration: float, amp: float) -> void:
	_tree_shake_timer = duration
	_tree_shake_amp = amp


func _trigger_cam_shake(duration: float, amp: float) -> void:
	_cam_shake_timer = duration
	_cam_shake_amp = amp


func _spawn_leaves(count: int) -> void:
	var palette := [
		Color(0.46, 0.60, 0.23),
		Color(0.33, 0.48, 0.18),
		Color(0.20, 0.34, 0.16),
		Color(0.56, 0.68, 0.26),
	]
	for i: int in range(count):
		_leaves.append({
			"pos": Vector2(randf_range(125.0, 355.0), randf_range(55.0, 175.0)),
			"vy": randf_range(34.0, 68.0),
			"vx": randf_range(-10.0, 16.0),
			"phase": randf_range(0.0, TAU),
			"sway": randf_range(14.0, 30.0),
			"freq": randf_range(3.2, 5.8),
			"ground_y": randf_range(296.0, 318.0),
			"col": palette[i % palette.size()],
			"settled": 0.0,
		})


func _spawn_dust(origin: Vector2) -> void:
	for i: int in range(16):
		var dir: float = -1.0 if i % 2 == 0 else 1.0
		_dust_puffs.append({
			"pos": origin + Vector2(randf_range(-14.0, 14.0), randf_range(-8.0, 2.0)),
			"vel": Vector2(dir * randf_range(28.0, 82.0), randf_range(-52.0, -14.0)),
			"rad": randf_range(4.0, 9.0),
			"life": 0.0,
			"max_life": randf_range(0.35, 0.65),
		})


func _add_pop_text(txt: String, pos: Vector2, col: Color, dur: float) -> void:
	_pop_texts.append({
		"txt": txt,
		"pos": pos,
		"col": col,
		"life": 0.0,
		"max_life": dur,
	})


func _process(delta: float) -> void:
	_t += delta

	# Rung tán cây xoài & trái xoài
	if _tree_shake_timer > 0.0:
		_tree_shake_timer = maxf(0.0, _tree_shake_timer - delta)
		var ox: float = roundf(sin(_t * 48.0) * _tree_shake_amp * minf(1.0, _tree_shake_timer * 3.0))
		if is_instance_valid(_tree_sprite):
			_tree_sprite.position = _tree_base_pos + Vector2(ox, 0.0)
		if is_instance_valid(_mango_sprite):
			_mango_sprite.position = _mango_base_pos + Vector2(ox, 0.0)
		if _tree_shake_timer <= 0.0:
			if is_instance_valid(_tree_sprite):
				_tree_sprite.position = _tree_base_pos
			if is_instance_valid(_mango_sprite):
				_mango_sprite.position = _mango_base_pos

	# Rung camera khi An đập xuống ống nước
	if _cam_shake_timer > 0.0 and is_instance_valid(_camera):
		_cam_shake_timer = maxf(0.0, _cam_shake_timer - delta)
		var k: float = _cam_shake_timer / 0.48
		_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * (_cam_shake_amp * k)
		if _cam_shake_timer <= 0.0:
			_camera.offset = Vector2.ZERO

	var any_fx: bool = false

	# Cập nhật lá xoài rơi
	if not _leaves.is_empty():
		var kept_leaves: Array[Dictionary] = []
		for lf: Dictionary in _leaves:
			var pos: Vector2 = lf["pos"]
			var ground_y: float = float(lf["ground_y"])
			if pos.y < ground_y:
				var phase: float = float(lf["phase"]) + delta * float(lf["freq"])
				lf["phase"] = phase
				pos.y = minf(ground_y, pos.y + float(lf["vy"]) * delta)
				pos.x += (float(lf["vx"]) + cos(phase) * float(lf["sway"])) * delta
				lf["pos"] = pos
				kept_leaves.append(lf)
			else:
				var settled: float = float(lf["settled"]) + delta
				lf["settled"] = settled
				if settled < 2.4:
					kept_leaves.append(lf)
		_leaves = kept_leaves
		any_fx = true

	# Cập nhật khói bụi tiếp đất
	if not _dust_puffs.is_empty():
		var kept_dust: Array[Dictionary] = []
		for p: Dictionary in _dust_puffs:
			var life: float = float(p["life"]) + delta
			p["life"] = life
			if life < float(p["max_life"]):
				var pos: Vector2 = p["pos"]
				var vel: Vector2 = p["vel"]
				pos += vel * delta
				vel *= (1.0 - minf(1.0, delta * 3.5))
				p["pos"] = pos
				p["vel"] = vel
				p["rad"] = float(p["rad"]) + delta * 8.0
				kept_dust.append(p)
		_dust_puffs = kept_dust
		any_fx = true

	# Cập nhật chữ hiệu ứng âm thanh nổi trên cây
	if not _pop_texts.is_empty():
		var kept_pops: Array[Dictionary] = []
		for pt: Dictionary in _pop_texts:
			var life: float = float(pt["life"]) + delta
			pt["life"] = life
			if life < float(pt["max_life"]):
				var pos: Vector2 = pt["pos"]
				pos.y -= delta * 12.0
				pt["pos"] = pos
				kept_pops.append(pt)
		_pop_texts = kept_pops
		any_fx = true

	if is_instance_valid(_fx_layer):
		if any_fx:
			_fx_layer.queue_redraw()
		elif not _running:
			_fx_layer.queue_free()
			_fx_layer = null


func _draw_fx() -> void:
	if not is_instance_valid(_fx_layer):
		return

	# 1. Vẽ lá xoài rơi (pixel art 4x2, xoay chao đảo theo nhịp sin)
	for lf: Dictionary in _leaves:
		var pos: Vector2 = (lf["pos"] as Vector2).round()
		var col: Color = lf["col"]
		var settled: float = float(lf["settled"])
		var alpha: float = 1.0 if settled <= 1.2 else clampf(1.0 - (settled - 1.2) / 1.2, 0.0, 1.0)
		var c_out := Color(0.09, 0.18, 0.11, alpha)
		var c_fill := Color(col.r, col.g, col.b, alpha)
		var wide: bool = settled > 0.0 or sin(float(lf["phase"])) >= 0.0
		if wide:
			_fx_layer.draw_rect(Rect2(pos + Vector2(-2.0, -1.0), Vector2(5.0, 3.0)), c_out)
			_fx_layer.draw_rect(Rect2(pos + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), c_fill)
		else:
			_fx_layer.draw_rect(Rect2(pos + Vector2(-1.0, -2.0), Vector2(3.0, 5.0)), c_out)
			_fx_layer.draw_rect(Rect2(pos + Vector2(0.0, -1.0), Vector2(1.0, 3.0)), c_fill)

	# 2. Vẽ bụi đất bay lên lúc An rơi xuống
	for p: Dictionary in _dust_puffs:
		var k: float = float(p["life"]) / float(p["max_life"])
		var r: float = roundf(float(p["rad"]))
		var pos: Vector2 = (p["pos"] as Vector2).round()
		var col := Color(0.78, 0.62, 0.44, 0.62 * (1.0 - k))
		_fx_layer.draw_rect(Rect2(pos - Vector2(r, r * 0.7), Vector2(r * 2.0, r * 1.4)), col)

	# 3. Vẽ chữ hiệu ứng âm thanh ("Sột soạt...", "RẮC!!", "RẦM!!")
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
	emote.name = "CutsceneEmote"
	emote.texture = tex
	emote.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	emote.centered = false
	emote.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height())
	emote.z_index = 40
	emote.scale = Vector2(0.15, 0.15)
	map_node.add_child(emote)
	emote.global_position = world_anchor

	_play_sfx(sfx_path, pitch)

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
		tw_hold.tween_property(emote, "position:y", base_pos.y - 3.0, 0.14).set_trans(Tween.TRANS_SINE)
		tw_hold.tween_property(emote, "position:y", base_pos.y, 0.14).set_trans(Tween.TRANS_SINE)
		tw_hold.tween_interval(0.35)
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
	tw_out.tween_property(emote, "modulate:a", 0.0, 0.16)
	await tw_out.finished
	if is_instance_valid(emote):
		emote.queue_free()


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


func _play_sfx(path: String, pitch: float = 1.0) -> void:
	if _sfx_player == null or not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path) as AudioStream
	if stream:
		_sfx_player.stream = stream
		_sfx_player.pitch_scale = pitch
		_sfx_player.play()
