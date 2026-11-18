extends Node2D
## Chỗ ngồi (ghế, bậc đá, mép mương…): đứng gần bấm E để ngồi, bấm E lần nữa hoặc đi là đứng dậy.
## Minh ngồi bằng animation "sit"; bạn đồng hành (An) ngồi theo bên cạnh.
## Gốc toạ độ đặt ở chỗ Minh sẽ ngồi, ngang mặt đất (chân).

## Hạ hình nhân vật xuống bao nhiêu px khi ngồi (vd ngồi mép kè thả chân xuống: ~14).
## 0 = ngồi trên vật cao ngang dáng vẽ (ghế, bậc thấp).
@export var sit_drop: float = 15.0
## Quay mặt ra màn hình khi ngồi (dáng "sit" vẽ nhìn thẳng)
@export var face_left: bool = false

@export_group("Ghế")
## Hình ghế vẽ dưới chỗ ngồi (mặc định ghế đá res://assets/objects/ghe_da.png). Bỏ trống + tắt show_bench nếu ngồi lên thứ có sẵn trong map.
@export var show_bench: bool = true
@export var bench_texture: Texture2D
## Tâm ghế so với chỗ Minh ngồi — lệch về phía An ngồi (An ngồi sau lưng Minh ~40 px)
@export var bench_offset: Vector2 = Vector2(-20, 0)
## Hàng chân ghế chạm đất trong ảnh ghế (px từ trên xuống)
@export var bench_foot_row: int = 28

const DEFAULT_BENCH := "res://assets/objects/ghe_da.png"

@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	if show_bench:
		var tex := bench_texture
		if tex == null and ResourceLoader.exists(DEFAULT_BENCH):
			tex = load(DEFAULT_BENCH)
		if tex:
			var spr := Sprite2D.new()
			spr.name = "Bench"
			spr.texture = tex
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			spr.centered = false
			spr.z_index = -1   # sau Minh / An
			spr.position = Vector2(bench_offset.x * (-1.0 if face_left else 1.0), bench_offset.y)
			spr.offset = Vector2(-tex.get_width() / 2, -bench_foot_row)
			add_child(spr)


func _process(_delta: float) -> void:
	# Đang ngồi ở ghế này thì ẩn dấu "?"
	var p := get_tree().get_first_node_in_group(&"player") as Player
	interactable.hide_prompt = p != null and p.pose == Player.POSE_SIT and absf(p.global_position.x - global_position.x) < 2.0


func _on_interacted(player: Node) -> void:
	if not (player is Player):
		return
	var p := player as Player
	if p.pose == Player.POSE_SIT:
		p.set_pose(&"")
		return
	p.global_position.x = global_position.x
	p.velocity = Vector2.ZERO
	p.anim.flip_h = face_left
	p.sit_drop = sit_drop
	p.set_pose(Player.POSE_SIT)
