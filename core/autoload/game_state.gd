extends Node
## Trạng thái chung của game trong một phiên chơi (autoload "GameState").
## File .dialogue đọc/ghi trực tiếp các biến & hàm ở đây, ví dụ:
##   if GameState.chapter == 1 and GameState.current_map == "garden"
##   do GameState.start_quest("fix_pipe")
## (Đã bật "state autoload shortcuts" nên trong .dialogue có thể bỏ chữ "GameState.")

signal changed
signal quest_changed(quest_id: String, state: String)
signal time_changed

enum DayPart { MORNING, NOON, EVENING }

const TIME_NAMES := ["morning", "noon", "evening"]

## 0 = Mở đầu, 1..4 = Chương 1..4
var chapter: int = 1
## Ngày trong game. Đi ngủ ở nhà Ông Nội → sang ngày mới (luật R2).
var day: int = 1
var time_of_day: DayPart = DayPart.MORNING
## Id map đang đứng, map tự gán khi được nạp (vd "garden", "house").
var current_map: String = ""
## Cờ tự do: "met_na", "pipe_parts" (số), "seen_intro"...
var flags: Dictionary = {}
## quest_id -> "active" | "done"
var quests: Dictionary = {}
var wind_seeds: int = 0
## Túi đồ: item_id -> số lượng. Thông tin vật phẩm: ItemData.get_item(id)
var inventory: Dictionary = {}


# --- Thời gian ------------------------------------------------------------------

## Dùng trong .dialogue: if time == "evening"
var time: String:
	get: return TIME_NAMES[time_of_day]

func is_time(t: String) -> bool:
	return time == t

func advance_time() -> void:
	if time_of_day == DayPart.EVENING:
		sleep()
	else:
		time_of_day = (time_of_day + 1) as DayPart
		time_changed.emit()
		changed.emit()

func sleep() -> void:
	day += 1
	time_of_day = DayPart.MORNING
	time_changed.emit()
	changed.emit()


# --- Cờ ---------------------------------------------------------------------------

func has_flag(key: String) -> bool:
	return bool(flags.get(key, false))

func get_flag(key: String, default: Variant = null) -> Variant:
	return flags.get(key, default)

func set_flag(key: String, value: Variant = true) -> void:
	flags[key] = value
	changed.emit()

func add_flag(key: String, amount: int = 1) -> void:
	flags[key] = int(flags.get(key, 0)) + amount
	changed.emit()


# --- Trạng thái NPC (cờ "npc.<id>.<key>") ---------------------------------------------

func npc_get(id: String, key: String, default: Variant = null) -> Variant:
	return flags.get("npc.%s.%s" % [id, key], default)

func npc_set(id: String, key: String, value: Variant) -> void:
	set_flag("npc.%s.%s" % [id, key], value)

func npc_talks(id: String) -> int:
	return int(flags.get("npc.%s.talks" % id, 0))


# --- Nhiệm vụ ------------------------------------------------------------------------

func quest_state(id: String) -> String:
	return quests.get(id, "")

func is_quest_active(id: String) -> bool:
	return quest_state(id) == "active"

func is_quest_done(id: String) -> bool:
	return quest_state(id) == "done"

func is_quest_new(id: String) -> bool:
	return quest_state(id) == ""

func start_quest(id: String) -> void:
	if is_quest_new(id):
		quests[id] = "active"
		quest_changed.emit(id, "active")
		EventBus.quest_changed.emit(id, "active")
		changed.emit()

func complete_quest(id: String) -> void:
	quests[id] = "done"
	quest_changed.emit(id, "done")
	EventBus.quest_changed.emit(id, "done")
	changed.emit()

# --- Game Sửa ống nước ----------------------------------------------------------------------------
func count_pipe_parts() -> int:
	var count := 0
	for item_id in ["pipe_clamp", "pipe_connector", "rubber_ring"]:
		if has_item(item_id) or has_flag("pipe_delivered." + item_id):
			count += 1
	return count

func count_pipe_parts_in_bag() -> int:
	var count := 0
	for item_id in ["pipe_clamp", "pipe_connector", "rubber_ring"]:
		if has_item(item_id):
			count += 1
	return count

func count_pipe_parts_missing() -> int:
	var count := 0
	for item_id in ["pipe_clamp", "pipe_connector", "rubber_ring"]:
		if not has_item(item_id) and not has_flag("pipe_delivered." + item_id):
			count += 1
	return count

func all_pipe_parts_delivered() -> bool:
	for item_id in ["pipe_clamp", "pipe_connector", "rubber_ring"]:
		if not has_flag("pipe_delivered." + item_id):
			return false
	return true

var pipe_minigame_pending: bool = false

func request_pipe_minigame() -> void:
	if pipe_minigame_pending:
		return
	if has_flag("ch1.pipe_fixed"):
		return
	if not all_pipe_parts_delivered():
		return
	pipe_minigame_pending = true
	_launch_pending_pipe_minigame.call_deferred()

func _launch_pending_pipe_minigame() -> void:
	# Chờ hội thoại đóng, không đợi signal
	# dialogue_ended của lần tương tác tiếp theo.
	await get_tree().create_timer(0.3).timeout
	if not pipe_minigame_pending:
		return
	pipe_minigame_pending = false
	if has_flag("ch1.pipe_fixed"):
		return
	if MinigameManager.is_running():
		return
	MinigameManager.start("fix_pipe")

func finish_garden_watering() -> void:
	if not has_flag("ch1.pipe_fixed") or has_flag("ch1.garden_watered"):
		return
	set_flag("ch1.garden_watered", true)
	# Dùng cờ thưởng cũ để tránh cộng trùng với các bản minigame trước.
	if not has_flag("minigame.fix_pipe.rewarded"):
		set_flag("minigame.fix_pipe.rewarded", true)
		add_wind_seeds(3)
		EventBus.toast_requested.emit("+3 Hạt Gió - Đã tưới đủ rau!")
	if is_quest_active("fix_pipe"):
		complete_quest("fix_pipe")

func request_watering_minigame() -> void:
	if not has_flag("ch1.pipe_fixed") or has_flag("ch1.garden_watered"):
		return
	_open_watering_after_dialogue.call_deferred()

func _open_watering_after_dialogue() -> void:
	# Chỉ dùng khi người chơi thoát màn tưới giữa chừng và nói chuyện lại.
	await get_tree().create_timer(0.4).timeout
	if not MinigameManager.is_running() and not has_flag("ch1.garden_watered"):
		MinigameManager.start("water_garden")

# --- Túi đồ ----------------------------------------------------------------------------
# Gọi được cả trong .dialogue:  if has_item("pipe_clamp")  /  do remove_item("pipe_clamp")

func add_item(item_id: String, amount: int = 1, notify: bool = true) -> void:
	# Xoá rồi thêm lại để món vừa nhận luôn nằm cuối (= mới nhất) trong Dictionary
	var total := item_count(item_id) + amount
	inventory.erase(item_id)
	inventory[item_id] = total
	EventBus.item_collected.emit(StringName(item_id))
	if notify:
		EventBus.toast_requested.emit("Đã nhận: %s" % ItemData.name_of(item_id))
	changed.emit()

func remove_item(item_id: String, amount: int = 1) -> bool:
	if item_count(item_id) < amount:
		return false
	inventory[item_id] = item_count(item_id) - amount
	if inventory[item_id] <= 0:
		inventory.erase(item_id)
	EventBus.item_removed.emit(StringName(item_id))
	changed.emit()
	return true

func has_item(item_id: String, amount: int = 1) -> bool:
	return item_count(item_id) >= amount

func item_count(item_id: String) -> int:
	return int(inventory.get(item_id, 0))

## Danh sách id đang có, MỚI NHẤT trước (món vừa nhận / nhận thêm đứng đầu)
func item_ids() -> Array:
	var ids := inventory.keys()
	ids.reverse()
	return ids


# --- Phần thưởng ---------------------------------------------------------------------

func add_wind_seeds(amount: int) -> void:
	wind_seeds += amount
	changed.emit()


# --- Điều kiện dạng chữ (dùng cho NPC.appear_condition, cửa, sự kiện...) -------------

## Đánh giá biểu thức với GameState làm ngữ cảnh.
## Vd: "chapter == 1 and time == 'morning'", "is_quest_done('fix_pipe')".
## Chuỗi rỗng = luôn đúng.
func check(condition: String) -> bool:
	if condition.strip_edges().is_empty():
		return true
	var expr := Expression.new()
	if expr.parse(condition) != OK:
		push_error("GameState.check: không parse được '%s': %s" % [condition, expr.get_error_text()])
		return false
	var result: Variant = expr.execute([], self)
	if expr.has_execute_failed():
		push_error("GameState.check: lỗi khi chạy '%s'" % condition)
		return false
	return bool(result)
