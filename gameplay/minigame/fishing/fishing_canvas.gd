extends Node2D
## Node vẽ thế giới câu cá (tọa độ 640x360 pixel art, scale 3x bởi WorldViewport).

func _draw() -> void:
	var parent_mg := get_parent().get_parent()
	if parent_mg and parent_mg.has_method("draw_fishing_world"):
		parent_mg.draw_fishing_world(self)
