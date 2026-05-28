extends CharacterBody2D

@export var move_speed: float = 220.0

func _physics_process(_delta: float) -> void:
	var input_direction := Vector2.ZERO

	input_direction.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_direction.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

	if input_direction.length() > 0:
		input_direction = input_direction.normalized()

	velocity = input_direction * move_speed
	move_and_slide()
