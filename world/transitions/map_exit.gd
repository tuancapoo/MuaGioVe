extends Area2D
## Mép map: Minh đi vào vùng này (theo đúng hướng) là sang map khác.
## Đặt trong "Exits/" của map, thêm CollisionShape2D phủ sát mép.

## map_id đích, vd "yard"
@export var target_map: String = ""
## Tên Marker2D trong "Spawns/" của map đích, vd "from_garden"
@export var target_spawn: String = ""
## Hướng phải đi để kích hoạt: -1 = đi sang trái, 1 = đi sang phải, 0 = hướng nào cũng được
@export_range(-1, 1) var direction: int = 0
## Biểu thức GameState; sai thì không cho đi (rỗng = luôn đi được). Vd "has_flag('ch1.village_unlocked')"
@export var condition: String = ""
## Câu thông báo khi chưa đi được (hiện bằng toast)
@export var locked_text: String = ""

var _player_inside: Node2D = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 << 1 # layer 2 "player"
	monitorable = false
	body_entered.connect(func(b): if b.is_in_group("player"): _player_inside = b)
	body_exited.connect(func(b): if b == _player_inside: _player_inside = null)


func _physics_process(_delta: float) -> void:
	if _player_inside == null or SceneManager.is_busy() or SceneManager.just_arrived():
		return
	if not _player_inside.get("can_move"):
		return
	var vx: float = _player_inside.velocity.x
	if direction != 0 and signf(vx) != float(direction):
		return
	if direction == 0 and is_zero_approx(vx):
		return
	if not GameState.check(condition):
		if not locked_text.is_empty():
			EventBus.toast_requested.emit(locked_text)
		return
	SceneManager.change_map(target_map, target_spawn)
