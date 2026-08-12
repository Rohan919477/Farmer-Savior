extends Node
class_name WorldDropManager

const SEED_DROP_SCENE: PackedScene = preload("res://scenes/items/SeedDrop.tscn")
const SCRAP_DROP_SCENE: PackedScene = preload("res://scenes/items/ScrapDrop.tscn")

var drops_by_map: Dictionary = {}
var next_drop_serial: int = 1

@onready var map_manager: Node = get_parent().get_node_or_null("MapManager")


func _ready() -> void:
	add_to_group("world_drop_manager")

	if map_manager != null and map_manager.has_signal("location_loaded"):
		if not map_manager.location_loaded.is_connected(_on_location_loaded):
			map_manager.location_loaded.connect(_on_location_loaded)

	call_deferred("_rebuild_current_location")


func register_drop(
	drop_node: Node2D,
	preferred_drop_id: String = "",
	preferred_map_id: String = ""
) -> String:
	if drop_node == null:
		return preferred_drop_id

	var map_id: String = preferred_map_id
	if map_id.is_empty():
		map_id = _get_current_location_id()

	if map_id.is_empty():
		return preferred_drop_id

	var drop_id: String = preferred_drop_id
	if drop_id.is_empty():
		drop_id = _create_drop_id()
	else:
		_advance_serial_past_drop_id(drop_id)

	var map_drops: Dictionary = drops_by_map.get(map_id, {})
	map_drops[drop_id] = _build_drop_record(drop_node)
	drops_by_map[map_id] = map_drops

	return drop_id


func update_drop(
	map_id: String,
	drop_id: String,
	drop_node: Node2D
) -> void:
	if map_id.is_empty() or drop_id.is_empty() or drop_node == null:
		return

	var map_drops: Dictionary = drops_by_map.get(map_id, {})
	if not map_drops.has(drop_id):
		map_drops[drop_id] = _build_drop_record(drop_node)
	else:
		map_drops[drop_id] = _build_drop_record(drop_node)

	drops_by_map[map_id] = map_drops


func remove_drop(map_id: String, drop_id: String) -> void:
	if map_id.is_empty() or drop_id.is_empty():
		return

	var map_drops: Dictionary = drops_by_map.get(map_id, {})
	if not map_drops.has(drop_id):
		return

	map_drops.erase(drop_id)

	if map_drops.is_empty():
		drops_by_map.erase(map_id)
	else:
		drops_by_map[map_id] = map_drops


func reset_for_new_game() -> void:
	drops_by_map.clear()
	next_drop_serial = 1
	_clear_runtime_drops_from_current_map()
	print("[World Drops] Reset for new game.")


func get_save_data() -> Dictionary:
	var save_data: Dictionary = {
		"_meta": {
			"next_drop_serial": next_drop_serial
		}
	}

	for map_id_variant in drops_by_map.keys():
		var map_id: String = str(map_id_variant)
		var map_drops: Dictionary = drops_by_map.get(map_id, {})
		var saved_drops: Array[Dictionary] = []

		for drop_id_variant in map_drops.keys():
			var drop_id: String = str(drop_id_variant)
			var drop_data: Dictionary = map_drops.get(drop_id, {})

			if drop_data.is_empty():
				continue

			saved_drops.append({
				"drop_id": drop_id,
				"resource_type": str(drop_data.get("resource_type", "seeds")),
				"amount": maxi(int(drop_data.get("amount", 1)), 1),
				"position_x": float(drop_data.get("position_x", 0.0)),
				"position_y": float(drop_data.get("position_y", 0.0))
			})

		save_data[map_id] = {
			"resource_drops": saved_drops
		}

	return save_data


func load_save_data(data: Dictionary) -> void:
	drops_by_map.clear()

	var meta: Dictionary = data.get("_meta", {})
	next_drop_serial = maxi(
		int(meta.get("next_drop_serial", 1)),
		1
	)

	for map_id_variant in data.keys():
		var map_id: String = str(map_id_variant)

		if map_id == "_meta":
			continue

		var map_data_variant: Variant = data.get(map_id, {})
		if typeof(map_data_variant) != TYPE_DICTIONARY:
			continue

		var map_data: Dictionary = map_data_variant
		var saved_drops_variant: Variant = map_data.get("resource_drops", [])
		if typeof(saved_drops_variant) != TYPE_ARRAY:
			continue

		var map_drops: Dictionary = {}

		for saved_drop_variant in saved_drops_variant:
			if typeof(saved_drop_variant) != TYPE_DICTIONARY:
				continue

			var saved_drop: Dictionary = saved_drop_variant
			var drop_id: String = str(saved_drop.get("drop_id", ""))
			var resource_type: String = str(
				saved_drop.get("resource_type", "seeds")
			)
			var amount: int = maxi(int(saved_drop.get("amount", 1)), 1)

			if drop_id.is_empty():
				drop_id = _create_drop_id()
			else:
				_advance_serial_past_drop_id(drop_id)

			if _get_scene_for_resource_type(resource_type) == null:
				continue

			map_drops[drop_id] = {
				"resource_type": resource_type,
				"amount": amount,
				"position_x": float(saved_drop.get("position_x", 0.0)),
				"position_y": float(saved_drop.get("position_y", 0.0))
			}

		if not map_drops.is_empty():
			drops_by_map[map_id] = map_drops

	_rebuild_current_location()

	print(
		"[World Drops] Loaded persistent drops: ",
		_get_total_drop_count()
	)


func _on_location_loaded(location_id: String, loaded_map: Node) -> void:
	_rebuild_drops_for_location(location_id, loaded_map)


func _rebuild_current_location() -> void:
	if map_manager == null:
		return

	var location_id: String = _get_current_location_id()
	var loaded_map: Node = null

	if "current_map" in map_manager:
		loaded_map = map_manager.get("current_map") as Node

	if location_id.is_empty() or loaded_map == null:
		return

	_rebuild_drops_for_location(location_id, loaded_map)


func _rebuild_drops_for_location(
	location_id: String,
	loaded_map: Node
) -> void:
	if loaded_map == null:
		return

	_clear_runtime_drops_from_map(loaded_map)

	var map_drops: Dictionary = drops_by_map.get(location_id, {})
	if map_drops.is_empty():
		return

	var drop_parent: Node = loaded_map.get_node_or_null("EnemyContainer")
	if drop_parent == null:
		drop_parent = loaded_map

	for drop_id_variant in map_drops.keys():
		var drop_id: String = str(drop_id_variant)
		var drop_data: Dictionary = map_drops.get(drop_id, {})
		var resource_type: String = str(
			drop_data.get("resource_type", "seeds")
		)
		var drop_scene: PackedScene = _get_scene_for_resource_type(resource_type)

		if drop_scene == null:
			continue

		var drop_node: Node2D = drop_scene.instantiate() as Node2D
		if drop_node == null:
			continue

		if drop_node.has_method("setup_persistent_drop"):
			drop_node.call(
				"setup_persistent_drop",
				drop_id,
				location_id,
				resource_type,
				maxi(int(drop_data.get("amount", 1)), 1)
			)

		drop_parent.add_child(drop_node)
		drop_node.global_position = Vector2(
			float(drop_data.get("position_x", 0.0)),
			float(drop_data.get("position_y", 0.0))
		)


func _clear_runtime_drops_from_current_map() -> void:
	if map_manager == null:
		return

	if not ("current_map" in map_manager):
		return

	var current_map: Node = map_manager.get("current_map") as Node
	if current_map != null:
		_clear_runtime_drops_from_map(current_map)


func _clear_runtime_drops_from_map(loaded_map: Node) -> void:
	if loaded_map == null:
		return

	for drop_node in get_tree().get_nodes_in_group("resource_drop"):
		if drop_node == null or not is_instance_valid(drop_node):
			continue

		if loaded_map.is_ancestor_of(drop_node):
			drop_node.queue_free()


func _build_drop_record(drop_node: Node2D) -> Dictionary:
	var resource_type: String = "seeds"
	var amount: int = 1

	if "resource_type" in drop_node:
		resource_type = str(drop_node.get("resource_type"))

	if "amount" in drop_node:
		amount = maxi(int(drop_node.get("amount")), 1)

	return {
		"resource_type": resource_type,
		"amount": amount,
		"position_x": drop_node.global_position.x,
		"position_y": drop_node.global_position.y
	}


func _get_scene_for_resource_type(resource_type: String) -> PackedScene:
	match resource_type:
		"seeds":
			return SEED_DROP_SCENE
		"scrap":
			return SCRAP_DROP_SCENE

	return null


func _get_current_location_id() -> String:
	if map_manager == null:
		return ""

	if map_manager.has_method("get_current_location_id"):
		return str(map_manager.call("get_current_location_id"))

	if "current_location_id" in map_manager:
		return str(map_manager.get("current_location_id"))

	return ""


func _create_drop_id() -> String:
	var drop_id: String = "drop_%08d" % next_drop_serial
	next_drop_serial += 1
	return drop_id


func _advance_serial_past_drop_id(drop_id: String) -> void:
	if not drop_id.begins_with("drop_"):
		return

	var serial_text: String = drop_id.trim_prefix("drop_")
	if not serial_text.is_valid_int():
		return

	next_drop_serial = maxi(next_drop_serial, int(serial_text) + 1)


func _get_total_drop_count() -> int:
	var total: int = 0

	for map_id_variant in drops_by_map.keys():
		var map_drops: Dictionary = drops_by_map.get(str(map_id_variant), {})
		total += map_drops.size()

	return total
