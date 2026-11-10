extends Node2D
## Scene khởi chạy: nạp map hiện tại và đặt Minh vào đó.
## Đổi map trong game: SceneManager.change_map(map_id, spawn).

@export var start_map: PackedScene = preload("res://world/areas/goc_cay_da/goc_cay_da.tscn")
@onready var world: Node2D = $World
@onready var player: Player = $Player

var map_node: GameMap


func _ready() -> void:
	load_map(start_map)


## SceneManager gọi hàm này khi đổi map. spawn = tên Marker2D trong "Spawns/" của map mới.
func load_map(scene: PackedScene, spawn: String = "") -> void:
	if map_node:
		world.remove_child(map_node)
		map_node.queue_free()
	map_node = scene.instantiate() as GameMap
	world.add_child(map_node)
	map_node.place_player(player, spawn)
