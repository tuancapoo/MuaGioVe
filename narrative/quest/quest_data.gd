
class_name QuestData
extends Resource

@export var id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""
@export var giver: String = ""

@export var objectives: Array[QuestObjective] = []

@export var reward_wind_seeds: int = 0
@export var reward_items: Dictionary = {}
@export var reward_flags: Array[String] = []

@export var auto_complete: bool = false
