extends Area2D
class_name ResourceDrop

@export var resource_type: String = "seeds"
@export var amount: int = 1

var persistent_drop_id: String = ""
var persistent_map_id: String = ""
var pickup_in_progress: bool = false

@export var seed_texture: Texture2D
@export var scrap_texture: Texture2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var pickup_collision: CollisionShape2D = (
	get_node_or_null("CollisionShape2D") as CollisionShape2D
)


func _ready() -> void:
	add_to_group("resource_drop")

	# Make pickup detection explicit instead of relying on editor defaults.
	monitoring = true
	monitorable = true
	collision_mask = 1

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	_apply_resource_visual()
	call_deferred("_register_with_world_drop_manager")
	call_deferred("_collect_already_overlapping_player")


func setup_drop(
	new_resource_type: String,
	new_amount: int = 1
) -> void:
	resource_type = new_resource_type
	amount = new_amount
	_apply_resource_visual()


func setup_persistent_drop(
	drop_id: String,
	map_id: String,
	new_resource_type: String,
	new_amount: int
) -> void:
	persistent_drop_id = drop_id
	persistent_map_id = map_id
	resource_type = new_resource_type
	amount = maxi(new_amount, 1)
	_apply_resource_visual()


func _register_with_world_drop_manager() -> void:
	if pickup_in_progress or is_queued_for_deletion():
		return

	var world_drop_manager: Node = get_tree().get_first_node_in_group(
		"world_drop_manager"
	)

	if world_drop_manager == null:
		return

	if not world_drop_manager.has_method("register_drop"):
		return

	# In the persistent-world architecture an enemy may drop loot on the Farm
	# while the player is physically inside the House. Determine ownership from
	# this node's map ancestry before falling back to the player's location.
	if persistent_map_id.is_empty():
		var map_manager: Node = get_tree().get_first_node_in_group("map_manager")

		if map_manager != null and map_manager.has_method(
			"get_location_id_for_node"
		):
			persistent_map_id = str(
				map_manager.call("get_location_id_for_node", self)
			)

		if (
			persistent_map_id.is_empty()
			and map_manager != null
			and map_manager.has_method("get_current_location_id")
		):
			persistent_map_id = str(
				map_manager.call("get_current_location_id")
			)

	persistent_drop_id = str(
		world_drop_manager.call(
			"register_drop",
			self,
			persistent_drop_id,
			persistent_map_id
		)
	)


func _sync_persistent_state() -> void:
	if persistent_drop_id.is_empty() or persistent_map_id.is_empty():
		return

	var world_drop_manager: Node = get_tree().get_first_node_in_group(
		"world_drop_manager"
	)

	if world_drop_manager != null and world_drop_manager.has_method("update_drop"):
		world_drop_manager.call(
			"update_drop",
			persistent_map_id,
			persistent_drop_id,
			self
		)


func _remove_persistent_state() -> void:
	if persistent_drop_id.is_empty() or persistent_map_id.is_empty():
		return

	var world_drop_manager: Node = get_tree().get_first_node_in_group(
		"world_drop_manager"
	)

	if world_drop_manager != null and world_drop_manager.has_method("remove_drop"):
		world_drop_manager.call(
			"remove_drop",
			persistent_map_id,
			persistent_drop_id
		)


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
	if pickup_in_progress or is_queued_for_deletion():
		return

	# When a drop is spawned directly under/near the player, body_entered may not
	# always fire the way it does when the player walks into an existing pickup.
	# This makes pickup behavior reliable for close-range enemy kills.
	for body in get_overlapping_bodies():
		if body is Node2D and body.is_in_group("player"):
			_on_body_entered(body)
			return


func _on_body_entered(body: Node2D) -> void:
	if pickup_in_progress or is_queued_for_deletion():
		return

	if not body.is_in_group("player"):
		return

	if not body.has_method("add_resource"):
		return

	pickup_in_progress = true

	var original_amount: int = amount
	var add_result: Variant = body.call(
		"add_resource",
		resource_type,
		amount
	)

	var remaining_amount: int = 0

	if typeof(add_result) == TYPE_INT:
		remaining_amount = maxi(int(add_result), 0)

	var collected_amount: int = maxi(
		original_amount - remaining_amount,
		0
	)

	if collected_amount <= 0:
		print(
			"[Pickup] Inventory full. ",
			original_amount,
			" ",
			resource_type,
			" remains on the ground."
		)
		pickup_in_progress = false
		return

	print(
		"Picked up ",
		collected_amount,
		" ",
		resource_type
	)

	_play_audio_sfx("pickup_collected")

	if remaining_amount > 0:
		amount = remaining_amount
		_sync_persistent_state()
		print(
			"[Pickup] ",
			remaining_amount,
			" ",
			resource_type,
			" remains on the ground."
		)
		pickup_in_progress = false
		return

	# Stop all pickup work immediately. queue_free() is deferred, so without
	# this guard another signal/deferred overlap check could process the same
	# drop before the node is actually removed from the tree.
	monitoring = false
	monitorable = false
	if pickup_collision != null:
		pickup_collision.set_deferred("disabled", true)

	_remove_persistent_state()
	queue_free()


func _play_audio_sfx(sfx_name: String) -> void:
	var audio_manager: Node = get_tree().get_first_node_in_group(
		"audio_manager"
	)

	if audio_manager == null:
		return

	if audio_manager.has_method("play_sfx"):
		audio_manager.call("play_sfx", sfx_name)
