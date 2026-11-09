
extends CharacterBody2D

const WALK_SPEED = 150.0
const RUN_SPEED = 300.0
const JUMP_VELOCITY = -400.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D


func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Movement
	var direction := Input.get_axis("ui_left", "ui_right")
	var is_running := Input.is_key_pressed(KEY_SHIFT)

	if direction != 0:
		anim.flip_h = direction < 0

		if is_running:
			velocity.x = direction * RUN_SPEED
			play_anim("Run")
		else:
			velocity.x = direction * WALK_SPEED
			play_anim("Walk")
	else:
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED)

		if is_on_floor():
			play_anim("Idle")

	move_and_slide()


func play_anim(name: String) -> void:
	if anim.animation != name:
		anim.play(name)
