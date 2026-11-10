extends Node2D
## Scene khởi chạy: nạp map hiện tại và đặt Minh vào đó.
## Sau này SceneManager (autoload) sẽ đảm nhận việc đổi map.

@export var start_map: PackedScene = preload("res://world/areas/living_room/living_room.tscn")
@onready var world: Node2D = $World
@onready var player: Player = $Player

var map_node: GameMap


func _ready() -> void:
	load_map(start_map)


func load_map(scene: PackedScene) -> void:
	if map_node:
		map_node.queue_free()
	map_node = scene.instantiate() as GameMap
	world.add_child(map_node)
	map_node.place_player(player)
