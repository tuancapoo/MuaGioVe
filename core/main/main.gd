extends Node2D
## Scene khởi chạy: nạp map hiện tại và đặt Minh vào đó.
## Đổi map trong game: SceneManager.change_map(map_id, spawn).

@export var start_map: PackedScene = preload("res://world/areas/goc_cay_da/goc_cay_da.tscn")
## Bạn đồng hành sống xuyên suốt khi đổi map (con của World, không thuộc map nào).
## Chỉ hiện / đi theo khi cờ npc.an.following = true.
@export var companion_scene: PackedScene = preload("res://gameplay/companion/an_companion.tscn")

@onready var world: Node2D = $World
@onready var player: Player = $Player

var map_node: GameMap
var companion: Node2D


func _ready() -> void:
	if companion_scene:
		companion = companion_scene.instantiate()
		world.add_child(companion)
	GameState.npc_set("an", "following", true)
	load_map(start_map)


## SceneManager gọi hàm này khi đổi map. spawn = tên Marker2D trong "Spawns/" của map mới.
func load_map(scene: PackedScene, spawn: String = "") -> void:
	if map_node:
		world.remove_child(map_node)
		map_node.queue_free()
	map_node = scene.instantiate() as GameMap
	world.add_child(map_node)
	map_node.place_player(player, spawn)
	if companion:
		companion.get_node("Follower").snap_behind()


func _unhandled_input(event: InputEvent) -> void:
	# Phím thử (chỉ bản debug): F2 bật / tắt An đi theo.
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_F2:
		GameState.npc_set("an", "following", not GameState.npc_get("an", "following", false))
		get_viewport().set_input_as_handled()
