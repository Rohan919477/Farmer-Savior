extends Area2D
class_name ResourceDrop

@export var resource_type: String = "seeds"
@export var amount: int = 1

@export var seed_texture: Texture2D
@export var scrap_texture: Texture2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var pickup_collision: CollisionShape2D = (
	get_node_or_null("CollisionShape2D") as CollisionShape2D
)


func _ready() -> void:
	# Make pickup detection explicit instead of relying on editor defaults.
	monitoring = true
	monitorable = true
	collision_mask = 1

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	_apply_resource_visual()
	call_deferred("_collect_already_overlapping_player")


func setup_drop(
	new_resource_type: String,
	new_amount: int = 1
) -> void:
	resource_type = new_resource_type
	amount = new_amount
	_apply_resource_visual()


func _apply_resource_visual() -> void:
	if sprite == null:
		return

	var selected_texture: Texture2D = null

	match resource_type:
		"seeds":
			selected_texture = seed_texture
		"scrap":
			selected_texture = scrap_texture
		_:
			selected_texture = seed_texture

	# Important:
	# The SeedDrop/ScrapDrop scenes already assign their Sprite2D texture.
	# If the exported texture is not assigned, do not overwrite the scene texture
	# with null, otherwise the drop exists but becomes invisible.
	if selected_texture != null:
		sprite.texture = selected_texture


func _collect_already_overlapping_player() -> void:
	# When a drop is spawned directly under/near the player, body_entered may not
	# always fire the way it does when the player walks into an existing pickup.
	# This makes pickup behavior reliable for close-range enemy kills.
	for body in get_overlapping_bodies():
		if body is Node2D and body.is_in_group("player"):
			_on_body_entered(body)
			return


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	if body.has_method("add_resource"):
		body.call("add_resource", resource_type, amount)

	print(
		"Picked up ",
		amount,
		" ",
		resource_type
	)

	queue_free()
