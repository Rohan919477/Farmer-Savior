extends Area2D

@export var interaction_name: String = "Interact"

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

func _process(_delta: float) -> void:
	if player_nearby and Input.is_action_just_pressed("interact"):
		var main = get_tree().get_first_node_in_group("main")

		if main != null and main.has_method("open_map_menu"):
			print("Interacted with: ", interaction_name)
			main.open_map_menu()
		else:
			print("Could not find Main or open_map_menu().")

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
