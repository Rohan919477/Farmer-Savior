extends Area2D

@export var speed: float = 500.0
@export var damage: int = 15
@export var lifetime: float = 1.5

var direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	print("SeedProjectile spawned at: ", global_position)

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func setup(new_direction: Vector2) -> void:
	if new_direction.length() > 0:
		direction = new_direction.normalized()

func _on_body_entered(body: Node) -> void:
	print("Projectile body entered: ", body.name)

	if body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	print("Projectile area entered: ", area.name)

	var parent = area.get_parent()
	if parent != null and parent.has_method("take_damage"):
		parent.take_damage(damage)
		queue_free()
