
extends "res://world/objects/world_object.gd"

@export var reward_item: StringName = &""
@export var search_duration: float = 1.0

var searching: bool = false


func _ready() -> void:
	# Xem luôn có mô tả riêng.
	if examine_text.strip_edges().is_empty():
		examine_text = "Minh: Một bụi cây xanh um, lá mọc khá dày."

	# Giữ toàn bộ hệ thống tương tác của WorldObject.
	super._ready()

	# Thêm Tìm kiếm bên cạnh Xem.
	if not interactable.actions.has(&"search"):
		interactable.actions.append(&"search")

	interactable.prompt_text = "Xem / Tìm bụi cây"
	interactable.show_items = false


func _on_action(
	action: StringName,
	player: Node,
	item_id: StringName
) -> void:
	match action:
		&"examine":
			# Xem không thay đổi trạng thái tìm kiếm.
			super._on_action(action, player, item_id)

		&"search":
			if searching:
				return

			var flag: String = "searched." + object_id

			if GameState.has_flag(flag):
				say("Minh: Mình đã tìm ở đây rồi.")
				return

			await _search_bush(flag)

		_:
			super._on_action(action, player, item_id)


func _search_bush(flag: String) -> void:
	searching = true

	var sprite: Sprite2D = get_node_or_null("Sprite2D")

	if sprite != null:
		var original_x: float = sprite.position.x
		var tween := create_tween()

		for i in range(10):
			var offset: float = 2.0 if i % 2 == 0 else -2.0

			tween.tween_property(
				sprite,
				"position:x",
				original_x + offset,
				search_duration / 10.0
			)

		await tween.finished
		sprite.position.x = original_x
	else:
		await get_tree().create_timer(
			search_duration
		).timeout

	# Đánh dấu đã tìm để không thể nhận đồ lần hai.
	GameState.set_flag(flag)

	if reward_item != &"":
		GameState.add_item(reward_item, 1)
		say("Minh: A! Mình tìm thấy một vòng cao su!")
	else:
		say("Minh: Chỉ có lá và cành khô thôi.")

	searching = false
