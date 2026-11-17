extends SceneTree
## Bộ kiểm thử tự động cho Mini-game 1.2: Câu cá bên mương (GP-TC & BAL-TC trong GDD).
## Chạy bằng lệnh:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://gameplay/minigame/fishing/test_fishing.gd

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_all")


func _assert(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)
		printerr("[FAIL] ", msg)
	else:
		print("[PASS] ", msg)


func _run_all() -> void:
	print("=== Bắt đầu kiểm thử Mini-game Câu cá (1.2) ===")
	await _test_scene_loads()
	await _test_stages_and_windows()
	await _test_f_index_and_adaptive_tolerance()
	await _test_nho_na_cooldown()
	await _test_no_gameover_and_fast_restart()
	await _test_bot_fast_fish_bal_tc_06()
	await _test_world_integration_bo_muong()

	if _failures.is_empty():
		print("=== TẤT CẢ KIỂM THỬ ĐỀU ĐẠT (PASS) ===")
		quit(0)
	else:
		printerr("=== CÓ %d LỖI ===" % _failures.size())
		quit(1)


func _spawn_fishing(params: Dictionary = {}) -> Node:
	var packed := load("res://gameplay/minigame/fishing/fishing.tscn") as PackedScene
	var mg := packed.instantiate()
	root.add_child(mg)
	var p := {"skip_intro": true}
	p.merge(params, true)
	mg.setup(p)
	return mg


func _test_scene_loads() -> void:
	var f_scene := load("res://gameplay/minigame/fishing/fishing.tscn") as PackedScene
	_assert(f_scene != null, "Nạp được fishing.tscn")
	var map_scene := load("res://world/areas/bo_muong_chan_de/bo_muong_chan_de.tscn") as PackedScene
	_assert(map_scene != null, "Nạp được bo_muong_chan_de.tscn")
	var map_inst := map_scene.instantiate()
	var spot := map_inst.get_node_or_null("Objects/FishingSpot")
	_assert(spot != null and spot.get("minigame_id") == "fishing", "bo_muong_chan_de có Objects/FishingSpot (MinigameSpot)")
	map_inst.free()


func _test_stages_and_windows() -> void:
	var mg := _spawn_fishing({"target": 5})
	_assert(mg.FISHING_SPOTS.size() == 5, "Có đúng 5 điểm có cá (3 gần, 2 xa)")
	_assert(mg.get_current_stage() == 1, "Bắt đầu ở Giai đoạn 1")
	_assert(is_equal_approx(mg.get_current_catch_window(), 1.0), "Giai đoạn 1: cửa sổ w = 1,0 s")
	_assert(mg.get_active_fish_spot_index() in [0, 1, 2], "Giai đoạn 1 chỉ sinh cá ở 3 điểm gần")

	mg.caught_count = 2
	_assert(mg.get_current_stage() == 2, "Sau 2 cá chuyển sang Giai đoạn 2")
	_assert(is_equal_approx(mg.get_current_catch_window(), 0.8), "Giai đoạn 2: cửa sổ w = 0,8 s")

	mg.caught_count = 4
	_assert(mg.get_current_stage() == 3, "Cá cuối chuyển sang Giai đoạn 3")
	_assert(is_equal_approx(mg.get_current_catch_window(), 0.7), "Giai đoạn 3: cửa sổ cá nhanh w = 0,7 s")
	_assert(mg.get_current_catch_window() / 0.35 >= 2.0, "Chỉ số khả thi ρ_c ≥ 2,0")

	# Chế độ Thử thách không làm ρ_c xuống dưới ρ_min = 2,0 (Mục 5.7.3)
	mg.params["challenge_mode"] = true
	_assert(mg.get_current_catch_window() >= 0.70, "Chế độ Thử thách giữ w ≥ 0,70 s (ρ_c ≥ 2,0)")
	mg.queue_free()
	await process_frame


func _test_f_index_and_adaptive_tolerance() -> void:
	var mg := _spawn_fishing({"force_stage": 3})
	var triggered: Array[Array] = []
	mg.hint_shown.connect(func(tier, speaker, _text): triggered.append([tier, speaker]))

	mg.set_frustration_state(3, 0.0)
	_assert(triggered.size() == 1 and triggered[0][0] == 1 and triggered[0][1] == "Na", "GP-TC-09: N_fail=3 → Cấp 1 (Na)")

	triggered.clear()
	mg.set_frustration_state(0, 90.0)
	_assert(triggered.size() == 1 and triggered[0][0] == 1, "Bảng 58: N_fail=0, T_stuck=90s → Cấp 1 (Na)")

	triggered.clear()
	mg.set_frustration_state(6, 0.0)
	_assert(triggered.size() == 1 and triggered[0][0] == 2 and triggered[0][1] == "Ông Nội", "GP-TC-09: N_fail=6 → Cấp 2 (Ông Nội)")

	triggered.clear()
	mg.set_frustration_state(5, 60.0)
	_assert(triggered.size() == 1 and triggered[0][0] == 2 and is_equal_approx(mg.get_f_index(), 4.0), "Bảng 58: N_fail=5, T_stuck=60s → F=7 gợi ý Ông Nội, sau đó F=4")

	triggered.clear()
	mg.set_frustration_state(9, 0.0)
	_assert(triggered.size() == 1 and triggered[0][0] == 3 and mg.visual_aid_enabled, "GP-TC-09: N_fail=9 → Cấp 3 (Minh họa trực quan)")

	# Kiểm tra nới dung sai Bảng 61 (τ_0 = 0,70 s)
	_assert(is_equal_approx(mg.get_current_catch_window(), 0.70 * 1.15), "Bảng 61: F=9 nới +15% → 0,805 s")
	mg.params["gentle_mode"] = true
	_assert(is_equal_approx(mg.get_current_catch_window(), 0.70 * 1.35), "Bảng 61: F=9 + Nhẹ nhàng tối đa +35% → 0,945 s")

	mg.set_frustration_state(0, 0.0)
	mg.params.erase("gentle_mode")
	mg.params["gentle_mode"] = true
	_assert(is_equal_approx(mg.get_current_catch_window(), 0.70 * 1.20), "Bảng 61: Nhẹ nhàng (F=0) +20% → 0,84 s")
	mg.queue_free()
	await process_frame


func _test_nho_na_cooldown() -> void:
	var mg := _spawn_fishing()
	_assert(is_equal_approx(mg.get_na_duty_ratio(), 4.0 / 19.0) and mg.get_na_duty_ratio() <= 0.35, "BAL-TC-14: Tỉ lệ hỗ trợ Nhờ Na = 0,21 ≤ 0,35")
	_assert(mg.call_na(), "Gọi Nhờ Na lần đầu thành công")
	_assert(is_equal_approx(mg.na_active_remaining, 4.0), "Nhờ Na kéo dài 4,0 s")
	_assert(is_equal_approx(mg.na_cooldown_remaining, 15.0), "Thời gian hồi Nhờ Na = 15,0 s")
	_assert(not mg.call_na(), "Không thể spam Nhờ Na khi đang trong thời gian hồi")
	mg.queue_free()
	await process_frame


func _test_no_gameover_and_fast_restart() -> void:
	var mg := _spawn_fishing({"target": 5})
	mg.caught_count = 2
	for _i in 22:
		var ok: bool = mg.attempt_cast_at(mg.get_active_fish_position())
		_assert(ok, "Thả cần trúng chỗ cá để kiểm thử hụt") if _i == 0 else null
		# Giật sớm ngay trong WAITING_BITE → hụt
		var res: String = mg.pull_rod()
		_assert(res == "early", "Giật sớm báo 'early'") if _i == 0 else null
		# Cho hết MISS_FEEDBACK (0.85s ≤ 2.0s)
		mg._on_minigame_process(0.90)
	_assert(mg.fail_count == 22, "GP-TC-01: Thất bại ≥ 20 lần liên tiếp được ghi nhận đầy đủ")
	_assert(not mg.is_finished, "GP-TC-01: Không bao giờ Game Over")
	_assert(mg.caught_count == 2, "Số cá đã câu được giữ nguyên khi hụt lượt")

	# GP-TC-02: Thử lại màn (restart) hoàn tất ≤ 2,0 s
	var t0 := Time.get_ticks_msec()
	mg.restart()
	await mg.restarted
	var elapsed_s := (Time.get_ticks_msec() - t0) / 1000.0
	_assert(elapsed_s <= 2.0, "GP-TC-02: Tái lập màn mất %.3fs (≤ 2,0 s)" % elapsed_s)
	_assert(mg.caught_count == 0 and mg.fail_count == 0, "Restart đặt lại sạch trạng thái")
	mg.queue_free()
	await process_frame


func _test_bot_fast_fish_bal_tc_06() -> void:
	# Bot phản ứng 0,35 s trên cá nhanh (w = 0,7 s) trong 30 lượt
	var mg := _spawn_fishing({"target": 100, "force_stage": 3})
	var wins := 0
	var trials := 30
	for _i in trials:
		mg.state = 0 # OBSERVE_AND_AIM
		mg._spawn_fish_for_current_stage()
		var ok: bool = mg.attempt_cast_at(mg.fish_target_pos)
		if not ok:
			continue
		# Mô phỏng chờ tới đúng thời điểm cá cắn câu + 0,35 s phản ứng
		mg._on_minigame_process(mg.wait_bite_duration + 0.01)
		if mg.state == 3: # BITE_WINDOW
			mg._on_minigame_process(0.35)
			if mg.pull_rod() == "caught":
				wins += 1
	_assert(wins >= 29, "BAL-TC-06: Bot phản ứng 0,35 s bắt được cá nhanh (w=0,7s): %d/%d (≥ 95%%)" % [wins, trials])

	# Bot thao tác ngoài cửa sổ (quá trễ > 0,7 s) → cá thoát
	mg.state = 0 # OBSERVE_AND_AIM
	mg._spawn_fish_for_current_stage()
	mg.attempt_cast_at(mg.fish_target_pos)
	mg._on_minigame_process(mg.wait_bite_duration + 0.01)
	mg._on_minigame_process(0.75)
	_assert(mg.state == 5, "BAL-TC-06: Thao tác quá cửa sổ làm cá thoát") # MISS_FEEDBACK = 5
	mg.queue_free()
	await process_frame


func _test_world_integration_bo_muong() -> void:
	var game_state: Node = root.get_node("GameState")
	var scene_mgr: Node = root.get_node("SceneManager")
	var mg_mgr: Node = root.get_node("MinigameManager")

	# Kiểm tra luồng MinigameManager + GameState + túi đồ (fish) + Hạt Gió
	game_state.flags.clear()
	game_state.inventory.clear()
	game_state.quests.clear()
	game_state.wind_seeds = 0
	game_state.start_quest("fishing")

	var main_packed := load("res://core/main/main.tscn") as PackedScene
	var main := main_packed.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame

	scene_mgr.change_map("bo_muong_chan_de", "from_field")
	await scene_mgr.map_change_finished
	_assert(game_state.current_map == "bo_muong_chan_de", "Chuyển vào map bo_muong_chan_de thành công")

	var spot: Node = main.map_node.get_node("Objects/FishingSpot")
	_assert(spot != null, "Tìm thấy FishingSpot trên bờ mương")

	mg_mgr.start("fishing", {"target": 5, "skip_intro": true})
	await process_frame
	_assert(mg_mgr.is_running(), "MinigameManager đang chạy fishing")
	_assert(not main.player.can_move, "Player bị khoá khi đang chơi minigame")
	_assert(main.world.process_mode == Node.PROCESS_MODE_DISABLED, "World tạm dừng khi đang chơi minigame")

	var mg: Node = mg_mgr._active_minigame
	# Hoàn thành đủ 5 con cá
	for _c in 5:
		mg.attempt_cast_at(mg.fish_target_pos)
		mg._on_minigame_process(mg.wait_bite_duration + 0.01)
		mg._on_minigame_process(0.30)
		mg.pull_rod()
		mg._on_minigame_process(0.90)

	_assert(mg.state == 6, "Sau 5 con cá chuyển sang trạng thái WON")
	mg._emit_win_result()
	await process_frame
	await process_frame

	_assert(not mg_mgr.is_running(), "MinigameManager đóng minigame sau khi thắng")
	_assert(main.player.can_move, "Mở khoá Player sau khi đóng minigame")
	_assert(game_state.has_flag("minigame.fishing.won"), "Cờ minigame.fishing.won được bật")
	_assert(game_state.is_quest_done("fishing"), "Quest fishing tự động hoàn thành khi thắng")
	_assert(game_state.item_count("fish") == 5, "Nhận đủ 5 Cá đồng vào túi đồ (GameState.inventory)")
	_assert(game_state.wind_seeds == 2, "Nhận 2 Hạt Gió (1 hoàn thành + 1 thành tích Tinh tế)")
	current_scene = null
	main.queue_free()
	await process_frame
