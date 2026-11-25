extends Node
## Cutscene mở đầu nhiệm vụ Trộm dưa ở map Ruộng dưa (ruong_dua):
## - Cả Minh và An cùng cúi người (sneak-Idle) ngay tại chỗ spawn.
## - Hội thoại hướng dẫn giữ CTRL núp sau bụi cây / rơm né đèn pin, kèm 3 emoji (chu mỏ, hoảng sợ, cười).
## - Kết thúc hội thoại → bật nhiệm vụ trộm dưa & bắt đầu chơi ngay.

const DIALOGUE_PATH := "res://data/dialogues/ch1_melon_stealth.dialogue"
const CARRY_CUTSCENE_SCRIPT := preload("res://narrative/cutscene/melon_carry/melon_carry_cutscene.gd")

const EMOTE_KISS_PATH := "res://assets/ui/emotes/emote_kiss.png"
const EMOTE_SHOCK_PATH := "res://assets/ui/emotes/emote_shock.png"
const EMOTE_LAUGH_PATH := "res://assets/ui/emotes/emote_laugh.png"
const EMOTE_EXCLAIM_PATH := "res://assets/ui/emotes/emote_exclaim.png"
const EMOTE_AMAZED_PATH := "res://assets/ui/emotes/emote_amazed.png"

const SFX_KISS := "res://assets/audio/sfx/fishing/na_help.wav"
const SFX_SHOCK := "res://assets/audio/sfx/fishing/miss.wav"
const SFX_LAUGH := "res://assets/audio/sfx/fishing/catch.wav"
const SFX_EXCLAIM := "res://assets/audio/sfx/fishing/nibble.wav"

const FLAG_INTRO_DONE := "ch1.melon_intro_done"
const FLAG_GIANT_SEEN := "ch1.giant_melon_seen"
const FLAG_CARRY_DONE := "ch1.melon_carry_done"
const GIANT_TRIGGER_X := 1420.0
const MELON_IDS := [
	"ruong_dua_melon_1",
	"ruong_dua_melon_2",
	"ruong_dua_melon_3",
	"ruong_dua_melon_4",
]

var _running: bool = false
var _sfx: AudioStreamPlayer = null


func _ready() -> void:
	_sfx = AudioStreamPlayer.new()
	_sfx.volume_db = -5.0
	add_child(_sfx)
	GameState.changed.connect(_check_all_melons_picked)

	if not GameState.has_flag(FLAG_INTRO_DONE):
		call_deferred("_run_intro")


func _process(_delta: float) -> void:
	if _running:
		return
	if not GameState.has_flag(FLAG_INTRO_DONE) or GameState.has_flag(FLAG_GIANT_SEEN):
		return
	if GameState.has_flag("picked.ruong_dua_melon_4"):
		return
	var map_node: Node2D = get_parent() as Node2D
	var stealth: Node = map_node.get_node_or_null("MelonStealth")
	if stealth and bool(stealth.get("_game_over")):
		return
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player and player.can_move and player.global_position.x >= GIANT_TRIGGER_X:
		call_deferred("_run_giant_melon_cutscene")


func _check_all_melons_picked() -> void:
	if _running or GameState.has_flag(FLAG_CARRY_DONE):
		return
	if GameState.current_map != "ruong_dua":
		return
	var all_picked: bool = true
	for mid: String in MELON_IDS:
		if not GameState.has_flag("picked." + mid):
			all_picked = false
			break
	if all_picked:
		call_deferred("_run_carry_ending")


func _run_intro() -> void:
	if _running or not is_inside_tree():
		return
	_running = true

	var map_node: Node2D = get_parent() as Node2D
	var stealth: Node = map_node.get_node_or_null("MelonStealth")
	if stealth and stealth.has_method("set_cutscene_paused"):
		stealth.call("set_cutscene_paused", true)

	# Đảm bảo An đang đi cùng Minh ở ruộng dưa
	GameState.npc_set("an", "following", true)

	# Chờ 1 frame để Main đặt Minh & snap An xong tại PlayerSpawn
	await get_tree().process_frame
	if not is_inside_tree():
		return

	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	var an_node: Node2D = get_tree().get_first_node_in_group(&"companion") as Node2D

	# Cả hai đứng thẳng tại chỗ spawn trong lúc hội thoại mở đầu
	if player:
		player.lock(&"melon_intro")
		player.anim.flip_h = false
		player.set_pose(&"")
	if an_node:
		var follower: Node = an_node.get_node_or_null("Follower")
		if follower and follower.has_method("snap_behind"):
			follower.call("snap_behind")

	# Chờ SceneManager fade sáng xong
	await get_tree().create_timer(0.45).timeout
	if not is_inside_tree():
		return

	var dlg := _load_dialogue()

	# 1. Minh hỏi đây là đâu → An bảo trộm vài quả dưa ăn thôi hehe
	if dlg:
		DialogueManager.show_dialogue_balloon(dlg, "part1")
		await DialogueManager.dialogue_ended
	if not is_inside_tree():
		return

	# 2. An bật emoji chu mỏ
	if an_node and an_node.visible:
		await _show_emote(map_node, an_node.global_position + Vector2(0.0, -108.0), EMOTE_KISS_PATH, SFX_KISS, 1.12, "bob")
		if not is_inside_tree():
			return

	# 3. Minh bật emoji hoảng sợ rồi nói "Wtf?! Lỡ bị người ta tóm thì sao?" + An dặn giữ CTRL núp
	if player:
		await _show_emote(map_node, player.get_speech_anchor() + Vector2(0.0, -4.0), EMOTE_SHOCK_PATH, SFX_SHOCK, 1.05, "shake")
		if not is_inside_tree():
			return

	if dlg:
		DialogueManager.show_dialogue_balloon(dlg, "part2")
		await DialogueManager.dialogue_ended
	if not is_inside_tree():
		return

	# 4. An bật emoji cười to
	if an_node and an_node.visible:
		await _show_emote(map_node, an_node.global_position + Vector2(0.0, -108.0), EMOTE_LAUGH_PATH, SFX_LAUGH, 1.12, "bob")
		if not is_inside_tree():
			return

	# Kết thúc mở đầu → đứng lên, bắt đầu nhiệm vụ trộm dưa!
	if is_instance_valid(player):
		player.set_pose(&"")
		player.unlock(&"melon_intro")

	GameState.set_flag(FLAG_INTRO_DONE, true)
	GameState.start_quest("steal_melon")

	if is_instance_valid(stealth):
		if stealth.has_method("refresh_start_snapshot"):
			stealth.call("refresh_start_snapshot")
		if stealth.has_method("set_cutscene_paused"):
			stealth.call("set_cutscene_paused", false)

	_running = false


func _run_giant_melon_cutscene() -> void:
	if _running or not is_inside_tree():
		return
	_running = true

	var map_node: Node2D = get_parent() as Node2D
	var stealth: Node = map_node.get_node_or_null("MelonStealth")
	if stealth and stealth.has_method("set_cutscene_paused"):
		stealth.call("set_cutscene_paused", true)

	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	var an_node: Node2D = get_tree().get_first_node_in_group(&"companion") as Node2D

	if player:
		player.lock(&"giant_melon")
		player.velocity = Vector2.ZERO
		player.anim.flip_h = false # Quay sang phải nhìn quả dưa siêu to khổng lồ

	var dlg := _load_dialogue()

	# 1. Minh bật emoji "!" rồi thốt lên "Wow!!"
	if player:
		await _show_emote(map_node, player.get_speech_anchor() + Vector2(0.0, -4.0), EMOTE_EXCLAIM_PATH, SFX_EXCLAIM, 1.15, "pop_hold")
		if not is_inside_tree():
			return

	if dlg:
		DialogueManager.show_dialogue_balloon(dlg, "giant_melon_minh")
		await DialogueManager.dialogue_ended
	if not is_inside_tree():
		return

	# 2. An bật emoji mắt tròn trầm trồ rồi bảo Minh hái quả dưa siêu to
	if an_node and an_node.visible:
		await _show_emote(map_node, an_node.global_position + Vector2(0.0, -108.0), EMOTE_AMAZED_PATH, SFX_KISS, 1.08, "bob")
		if not is_inside_tree():
			return

	if dlg:
		DialogueManager.show_dialogue_balloon(dlg, "giant_melon_an")
		await DialogueManager.dialogue_ended
	if not is_inside_tree():
		return

	GameState.set_flag(FLAG_GIANT_SEEN, true)
	if is_instance_valid(stealth) and stealth.has_method("set_cutscene_paused"):
		stealth.call("set_cutscene_paused", false)
	if is_instance_valid(player):
		player.unlock(&"giant_melon")
	_running = false


func _run_carry_ending() -> void:
	if _running or not is_inside_tree():
		return
	_running = true

	var map_node: Node2D = get_parent() as Node2D
	var stealth: Node = map_node.get_node_or_null("MelonStealth")
	if stealth and stealth.has_method("set_cutscene_paused"):
		stealth.call("set_cutscene_paused", true)

	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player:
		player.lock(&"melon_carry")
		player.velocity = Vector2.ZERO

	GameState.set_flag(FLAG_CARRY_DONE, true)
	if GameState.is_quest_active("steal_melon"):
		GameState.complete_quest("steal_melon")

	# Chờ một nhịp ngắn cho thông báo nhặt quả dưa cuối kịp hiện
	await get_tree().create_timer(0.6).timeout
	if not is_inside_tree():
		return

	# Mở cutscene màn hình đen Minh & An giơ 2 tay vác quả dưa siêu to trên đầu đi!
	var carry: MelonCarryCutscene = CARRY_CUTSCENE_SCRIPT.new()
	add_child(carry)
	await carry.finished
	if not is_inside_tree():
		return

	if is_instance_valid(player):
		player.unlock(&"melon_carry")
	_running = false
	GameState.npc_set("an", "following", false)
	GameState.time = "evening"
	SceneManager.change_map("living_room", "after_melon")


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
		tw_sh.tween_interval(0.30)
		await tw_sh.finished
	elif style == "pop_hold":
		var tw_hold := create_tween()
		tw_hold.tween_property(emote, "position:y", base_pos.y - 3.0, 0.14).set_trans(Tween.TRANS_SINE)
		tw_hold.tween_property(emote, "position:y", base_pos.y, 0.14).set_trans(Tween.TRANS_SINE)
		tw_hold.tween_interval(0.32)
		await tw_hold.finished
	else:
		var tw_bob := create_tween()
		tw_bob.tween_property(emote, "position:y", base_pos.y - 3.0, 0.22).set_trans(Tween.TRANS_SINE)
		tw_bob.tween_property(emote, "position:y", base_pos.y, 0.22).set_trans(Tween.TRANS_SINE)
		tw_bob.tween_property(emote, "position:y", base_pos.y - 2.0, 0.22).set_trans(Tween.TRANS_SINE)
		tw_bob.tween_property(emote, "position:y", base_pos.y, 0.22).set_trans(Tween.TRANS_SINE)
		await tw_bob.finished

	if not is_inside_tree():
		return

	var tw_out := create_tween()
	tw_out.tween_property(emote, "modulate:a", 0.0, 0.16)
	await tw_out.finished
	if is_instance_valid(emote):
		emote.queue_free()


func _play_sfx(path: String, pitch: float = 1.0) -> void:
	if _sfx == null or not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path) as AudioStream
	if stream:
		_sfx.stream = stream
		_sfx.pitch_scale = pitch
		_sfx.play()


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
