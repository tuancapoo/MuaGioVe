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
