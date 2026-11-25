extends Node2D
## Minigame Trộm dưa — đặt 1 node này trong map Ruộng dưa.
##
## - Người canh trên mỗi chòi soi đèn pin quét qua lại trên đường Minh đi.
## - Minh đứng trong vệt đèn mà KHÔNG núp → bị phát hiện → Game Over → chơi lại từ đầu.
## - Núp = giữ Ctrl (ngồi) khi đứng sau một chỗ núp: bụi cây, bụi rơm (con của "Objects")
##   hoặc vật trong `extra_hide_spots` (vd quả dưa to). Lúc núp, chỗ núp được vẽ đè lên Minh.
## - Chơi lại: Minh về chỗ xuất phát, dưa đã hái trong lượt này trả lại ruộng.

signal caught
signal reset_done

## Màn hình Game Over (vẽ trong art_source/ui/game_over.aseprite)
const GAME_OVER_PATH := "res://assets/ui/game_over.png"
const FONT := preload("res://assets/fonts/vt323_regular.ttf")

@export_group("Đèn pin")
## Vị trí tay cầm đèn của từng người canh (toạ độ map)
@export var lamps: Array[Vector2] = [Vector2(316, 184), Vector2(958, 184), Vector2(1602, 184)]
## Mỗi đèn quét sang hai bên bao xa (px)
@export var sweep_range: float = 250.0
## Tốc độ quét của từng đèn (vòng / giây ×2π) — khác nhau để không đồng bộ
@export var sweep_speeds: Array[float] = [0.55, 0.7, 0.48]
@export var sweep_phases: Array[float] = [0.0, 2.1, 4.0]
## Độ rộng vệt sáng trên mặt đất (px)
@export var spot_width: float = 96.0
## Hàng mặt đất nơi vệt sáng rọi xuống
@export var ground_y: float = 322.0
@export var light_color: Color = Color(1.0, 0.92, 0.6, 0.22)
@export var alert_color: Color = Color(1.0, 0.35, 0.3, 0.32)

@export_group("Phát hiện")
## Đứng trong vệt sáng liên tục bao lâu thì bị bắt (giây)
@export var catch_time: float = 0.35
## Chỗ núp thêm ngoài các con của "Objects" (vd quả dưa to)
@export var extra_hide_spots: Array[NodePath] = []
## Lề trong chỗ núp (px): Minh phải đứng lọt vào trong mới tính là núp
@export var hide_margin: float = 6.0
## Lúc núp, chỗ núp được đưa lên lớp này: trên Minh / An (z 0), dưới quả dưa nhỏ (z 4)
@export var hiding_z: int = 1

var _t := 0.0
var _exposure := 0.0
var _game_over := false
var _in_dialogue := false
var _cutscene_paused := false
var _spots: Array[float] = []          # x vệt sáng hiện tại của từng đèn
var _hiding_spot: Node2D = null
var _spot_z := {}                      # chỗ núp → z_index gốc
var _start := {}                       # trạng thái lúc bắt đầu lượt
var _ui: CanvasLayer


func _ready() -> void:
	z_index = 20
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	_spots.resize(lamps.size())
	DialogueManager.dialogue_started.connect(func(_r): _in_dialogue = true)
	DialogueManager.dialogue_ended.connect(func(_r): _in_dialogue = false)
	_build_ui()
	# Chờ Main đặt Minh vào map rồi mới ghi trạng thái xuất phát
	await get_tree().process_frame
	_save_start()


func set_cutscene_paused(paused: bool) -> void:
	_cutscene_paused = paused
	if paused:
		_exposure = 0.0


func refresh_start_snapshot() -> void:
	_save_start()


func _player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player


# --- Mỗi khung hình ---------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _game_over:
		_t += delta
	for i in lamps.size():
		var spd: float = sweep_speeds[i] if i < sweep_speeds.size() else 0.6
		var ph: float = sweep_phases[i] if i < sweep_phases.size() else 0.0
		_spots[i] = lamps[i].x + sin(_t * spd + ph) * sweep_range
	queue_redraw()

	var player := _player()
	if player == null or _game_over:
		return
	_update_hiding(player)
	if _in_dialogue or _cutscene_paused:
		_exposure = 0.0
		return
	var lit := _lit(player.global_position.x) and _hiding_spot == null
	_exposure = _exposure + delta if lit else maxf(0.0, _exposure - delta * 2.0)
	if _exposure >= catch_time:
		_on_caught(player)


## Minh có đang đứng trong vệt sáng nào không
func _lit(x: float) -> bool:
	for sx in _spots:
		if absf(x - sx) < spot_width * 0.5 - 4.0:
			return true
	return false


# --- Núp --------------------------------------------------------------------------------

func _hide_spots() -> Array[Node2D]:
	var out: Array[Node2D] = []
	var map := get_parent()
	var objects := map.get_node_or_null("Objects")
	if objects:
		for c in objects.get_children():
			if c is Node2D and c.visible:
				out.append(c)
	for p in extra_hide_spots:
		var n := get_node_or_null(p) as Node2D
		if n and n.is_visible_in_tree():
			out.append(n)
	return out


## Khoảng x (trái, phải) mà hình của chỗ núp che (theo Sprite2D của nó)
static func _span(spot: Node2D) -> Vector2:
	var spr: Sprite2D = spot as Sprite2D if spot is Sprite2D else spot.get_node_or_null("Sprite2D") as Sprite2D
	if spr == null or spr.texture == null:
		return Vector2(spot.global_position.x - 20, spot.global_position.x + 20)
	var r := spr.get_rect()
	var a := spr.global_transform * r.position
	var b := spr.global_transform * (r.position + r.size)
	return Vector2(minf(a.x, b.x), maxf(a.x, b.x))


func _update_hiding(player: Player) -> void:
	var found: Node2D = null
	if player.crouching:
		var x := player.global_position.x
		for s in _hide_spots():
			var sp := _span(s)
			if x > sp.x + hide_margin and x < sp.y - hide_margin:
				found = s
				break
	if found == _hiding_spot:
		return
	# Trả chỗ núp cũ về lớp cũ, đưa chỗ núp mới lên trước Minh
	if _hiding_spot and is_instance_valid(_hiding_spot):
		_hiding_spot.z_index = _spot_z.get(_hiding_spot, _hiding_spot.z_index)
	_hiding_spot = found
	if found:
		_spot_z[found] = found.z_index
		found.z_index = hiding_z
	player.modulate = Color(0.75, 0.75, 0.85) if found else Color.WHITE


# --- Vẽ đèn pin -------------------------------------------------------------------------

func _draw() -> void:
	var col := alert_color if _game_over else light_color
	for i in lamps.size():
		var lamp: Vector2 = lamps[i]
		var sx: float = _spots[i]
		var half := spot_width * 0.5
		# Vệt sáng hình nón từ tay người canh xuống đất
		draw_colored_polygon(PackedVector2Array([
			lamp + Vector2(-1, 0), lamp + Vector2(1, 0),
			Vector2(sx + half, ground_y), Vector2(sx - half, ground_y)]), col * Color(1, 1, 1, 0.55))
		# Quầng sáng trên mặt đất
		_draw_ellipse(Vector2(sx, ground_y), Vector2(half, 11), col)
		_draw_ellipse(Vector2(sx, ground_y), Vector2(half * 0.6, 7), col)
		# Đầu đèn
		draw_rect(Rect2(lamp - Vector2(1, 1), Vector2(3, 3)), Color(1, 0.95, 0.7))


func _draw_ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 24:
		var a := TAU * k / 24.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)


# --- Bị bắt / chơi lại ------------------------------------------------------------------

func _on_caught(player: Player) -> void:
	_game_over = true
	caught.emit()
	player.can_move = false
	var bar := get_tree().get_first_node_in_group(&"mash_bar")
	if bar and bar.running:
		bar._end(false)
	var wheel := get_tree().get_first_node_in_group(&"action_wheel")
	if wheel and wheel.visible:
		wheel.close()
	queue_redraw()
	await get_tree().create_timer(0.6).timeout
	_ui.show()
	var tw := create_tween()
	tw.tween_property(_ui.get_node("Root"), "modulate:a", 1.0, 0.5)
	await tw.finished
	_ui.set_meta("ready", true)


func _unhandled_input(event: InputEvent) -> void:
	if _game_over and _ui.get_meta("ready", false) and (event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept")):
		get_viewport().set_input_as_handled()
		_restart()


func _save_start() -> void:
	var player := _player()
	_start = {
		"x": player.global_position.x if player else 80.0,
		"inventory": GameState.inventory.duplicate(),
		"flags": GameState.flags.duplicate(),
	}


func _restart() -> void:
	_ui.set_meta("ready", false)
	# Trả túi đồ + cờ (dưa đã hái…) về như lúc bắt đầu lượt
	GameState.inventory = _start.inventory.duplicate()
	GameState.flags = _start.flags.duplicate()
	GameState.changed.emit()
	var player := _player()
	if player:
		player.global_position.x = _start.x
		player.velocity = Vector2.ZERO
		player.modulate = Color.WHITE
		player.can_move = true
		player.camera.reset_smoothing()
	for c in get_tree().get_nodes_in_group(&"companion"):
		var f := c.get_node_or_null("Follower")
		if f and f.has_method("snap_behind"):
			f.snap_behind()
	_exposure = 0.0
	_t = 0.0
	_hiding_spot = null
	_game_over = false
	var tw := create_tween()
	tw.tween_property(_ui.get_node("Root"), "modulate:a", 0.0, 0.4)
	await tw.finished
	_ui.hide()
	reset_done.emit()


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 95
	_ui.name = "GameOver"
	add_child(_ui)
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.modulate.a = 0.0
	_ui.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color8(47, 40, 47)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var tex := TextureRect.new()
	if ResourceLoader.exists(GAME_OVER_PATH):
		tex.texture = load(GAME_OVER_PATH)
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(tex)
	var hint := Label.new()
	hint.text = "Bị phát hiện rồi!  Bấm E để chơi lại"
	hint.add_theme_font_override(&"font", FONT)
	hint.add_theme_font_size_override(&"font_size", 48)
	hint.add_theme_color_override(&"font_color", Color(0.98, 0.95, 0.85))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -140
	hint.offset_bottom = -70
	root.add_child(hint)
	_ui.hide()
