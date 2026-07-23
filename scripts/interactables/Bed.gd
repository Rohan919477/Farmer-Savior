extends Node2D
class_name Bed

@export var interaction_name: String = "Bed"

func _ready() -> void:
	add_to_group("bed")

func get_interaction_name() -> String:
	return interaction_name

func get_interaction_display_name() -> String:
	return interaction_name

func interact() -> void:
	_use_bed()

func interact_with_player(_player: Node) -> void:
	_use_bed()

func on_interact(_player: Node = null) -> void:
	_use_bed()

func _use_bed() -> void:
	var main_node: Node = get_tree().get_first_node_in_group("main")

	if main_node == null:
		print("[Bed] Main node not found.")
		return

	if not main_node.has_method("sleep_at_bed"):
		print("[Bed] Main.sleep_at_bed() is missing.")
		return

	main_node.call("sleep_at_bed")
