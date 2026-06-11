extends Area2D

@export var resource_type: String = "seeds"
@export var amount: int = 1

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if body.has_method("add_resource"):
			body.add_resource(resource_type, amount)
			print("Picked up ", amount, " ", resource_type)
			queue_free()
