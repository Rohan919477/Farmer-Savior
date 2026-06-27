extends Area2D

@export var damage: int = 25

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _on_body_entered(body: Node) -> void:
	print("Hoe hit body: ", body.name)

	if body.has_method("take_damage"):
		body.take_damage(damage)

func _on_area_entered(area: Area2D) -> void:
	print("Hoe hit area: ", area.name)

	var parent = area.get_parent()
	if parent != null and parent.has_method("take_damage"):
		parent.take_damage(damage)
