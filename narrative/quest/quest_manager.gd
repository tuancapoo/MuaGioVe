
extends Node

var quest_data: Dictionary = {}
var objective_progress: Dictionary = {}
var _checking: bool = false

func _ready() -> void:
    _load_quests()
    GameState.changed.connect(_check_objectives)

func _load_quests() -> void:
    var dir := DirAccess.open("res://data/quests")
    if dir == null:
        push_warning("Khong tim thay data/quests")
        return

    dir.list_dir_begin()
    var file := dir.get_next()

    while file != "":
        if file.ends_with(".tres"):
            var data = load("res://data/quests/" + file)
            if data is QuestData:
                quest_data[data.id] = data
        file = dir.get_next()

    dir.list_dir_end()

func start_quest(id: String) -> void:
    if not quest_data.has(id):
        push_warning("Quest not found: " + id)
        return

    GameState.start_quest(id)
    _check_objectives()

func get_current_objective(id: String) -> QuestObjective:
    if not quest_data.has(id):
        return null
    if not GameState.is_quest_active(id):
        return null

    var data: QuestData = quest_data[id]

    for obj in data.objectives:
        if not objective_progress.get(id + "." + obj.id, false):
            return obj

    return null

func update_objective(id: String, objective_id: String) -> void:
    if not GameState.is_quest_active(id):
        return

    objective_progress[id + "." + objective_id] = true
    EventBus.quest_changed.emit(id, "active")
    _check_objectives()

func _objective_done(obj: QuestObjective) -> bool:
    match obj.done_when:
        "parts_collected":
            return (
                GameState.has_item("pipe_connector")
                and GameState.has_item("rubber_ring")
                and GameState.has_item("pipe_clamp")
            )
        "ch1.pipe_fixed":
            return GameState.has_flag("ch1.pipe_fixed")
        "ch1.garden_watered":
            return GameState.has_flag("ch1.garden_watered")
        _:
            return false

func _check_objectives() -> void:
    if _checking:
        return

    _checking = true

    for id in quest_data:
        if not GameState.is_quest_active(id):
            continue

        var obj := get_current_objective(id)

        while obj != null and _objective_done(obj):
            objective_progress[id + "." + obj.id] = true
            EventBus.quest_changed.emit(id, "active")
            obj = get_current_objective(id)

    _checking = false

func can_complete(id: String) -> bool:
    return (
        GameState.is_quest_active(id)
        and get_current_objective(id) == null
    )

func complete_quest(id: String) -> void:
    if not can_complete(id):
        return

    var data: QuestData = quest_data[id]

    for item_id in data.reward_items:
        GameState.add_item(
            item_id,
            int(data.reward_items[item_id])
        )

    for flag in data.reward_flags:
        GameState.set_flag(flag)

    GameState.add_wind_seeds(data.reward_wind_seeds)
    GameState.complete_quest(id)

    EventBus.toast_requested.emit(
        "Hoan thanh: " + data.title
    )

func get_active() -> Array:
    var result: Array = []
    for id in GameState.quests:
        if GameState.is_quest_active(id):
            result.append(id)
    return result

func get_done() -> Array:
    var result: Array = []
    for id in GameState.quests:
        if GameState.is_quest_done(id):
            result.append(id)
    return result
