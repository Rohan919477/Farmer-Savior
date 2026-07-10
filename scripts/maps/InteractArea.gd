extends Area2D

@export var interaction_name: String = "Interact"
@export var interaction_type: String = "map_menu"
@export var target_location_id: String = ""

var player_nearby: bool = false

@onready var prompt_label: Label = get_node_or_null("PromptLabel")
@onready var highlight_visual: CanvasItem = get_node_or_null("HighlightVisual")

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if prompt_label != null:
		prompt_label.text = interaction_name + "\nPress E"
		prompt_label.visible = false

	if highlight_visual != null:
		highlight_visual.visible = false

func is_gameplay_input_blocked() -> bool:
	var main_node: Node = get_tree().get_first_node_in_group("main")

	if main_node == null:
		return false

	if main_node.has_method("is_gameplay_input_blocked"):
		return bool(main_node.call("is_gameplay_input_blocked"))

	return false

func _process(_delta: float) -> void:
	if not player_nearby:
		return

	if is_gameplay_input_blocked():
		return

	if Input.is_action_just_pressed("interact"):
		perform_interaction()

func perform_interaction() -> void:
	var main = get_tree().get_first_node_in_group("main")

	if main == null:
		print("Could not find Main.")
		return

	print("Interacted with: ", interaction_name)

	match interaction_type:
		"map_menu":
			if main.has_method("open_map_menu"):
				main.open_map_menu()

		"travel":
			if main.has_method("travel_to_location"):
				main.travel_to_location(target_location_id)

		"war_table":
			if main.has_method("open_defense_placement"):
				main.open_defense_placement()
			else:
				print("War Table interaction placeholder.")

		"workshop":
			if main.has_method("open_workshop"):
				main.open_workshop()
			else:
				print("Workshop interaction placeholder.")

		_:
			print("Unknown interaction type: ", interaction_type)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_nearby = true
		show_interaction_feedback()
		print("Press E to interact with ", interaction_name)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_nearby = false
		hide_interaction_feedback()

func show_interaction_feedback() -> void:
	if prompt_label != null:
		prompt_label.visible = true

	if highlight_visual != null:
		highlight_visual.visible = true

func hide_interaction_feedback() -> void:
	if prompt_label != null:
		prompt_label.visible = false

	if highlight_visual != null:
		highlight_visual.visible = false
