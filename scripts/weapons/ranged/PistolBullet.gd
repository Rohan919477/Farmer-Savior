extends Area2D
class_name PistolBullet

@export var speed: float = 500.0
@export var damage: int = 15
@export var lifetime: float = 1.5

var direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	await get_tree().create_timer(lifetime, false).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func setup(new_direction: Vector2) -> void:
	if new_direction.length() <= 0.0:
		return

	direction = new_direction.normalized()
	rotation = direction.angle()

func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	var target_parent: Node = area.get_parent()

	if target_parent != null and target_parent.has_method("take_damage"):
		target_parent.take_damage(damage)
		queue_free()
