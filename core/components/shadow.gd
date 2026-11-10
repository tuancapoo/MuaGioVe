class_name CharacterShadow
extends Node2D
## Small four-row stepped shadow for pixel-art characters.

@export var size := Vector2(40.0, 12.0)
@export var color := Color(0.06, 0.07, 0.12, 0.42)


func _ready() -> void:
	z_index = -1
	queue_redraw()


func _draw() -> void:
	var row_height: float = size.y / 4.0
	var top: float = -size.y * 0.5
	var widths: PackedFloat32Array = PackedFloat32Array([
		size.x * 0.72,
		size.x,
		size.x * 0.84,
		size.x * 0.56,
	])
	for row in widths.size():
		var width: float = widths[row]
		var x: float = -width * 0.5
		var y: float = top + row * row_height
		draw_rect(Rect2(x, y, width, row_height), color)
