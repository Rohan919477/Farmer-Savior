extends Control
class_name UpgradeTreeBoard

signal upgrade_selected(upgrade_id: String)

const NODE_SIZE: Vector2 = Vector2(150.0, 78.0)
const NODE_MARGIN: float = 12.0

const NODE_LABELS: Dictionary = {
	UpgradeManager.UPGRADE_FIELD_CONDITIONING:
		"FIELD\nCONDITIONING I",
	UpgradeManager.UPGRADE_FIELD_RUNNER:
		"FIELD RUNNER",
	UpgradeManager.UPGRADE_HOMESTEAD_GUARDIAN:
		"HOMESTEAD\nGUARDIAN",

	UpgradeManager.UPGRADE_REINFORCED_TIMBER:
		"REINFORCED\nTIMBER I",
	UpgradeManager.UPGRADE_STRONGHOLD_FRAMES:
		"STRONGHOLD\nFRAMES",
	UpgradeManager.UPGRADE_RAPID_PATCHWORK:
		"RAPID\nPATCHWORK"
}

var upgrade_manager: UpgradeManager = null
var current_tree: String = ""
var selected_upgrade_id: String = ""

var node_buttons: Dictionary = {}
var node_positions: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true

	resized.connect(_on_resized)

func configure_tree(
	new_tree: String,
	new_upgrade_manager: UpgradeManager
) -> void:
	var tree_changed: bool = (
		current_tree != new_tree
		or upgrade_manager != new_upgrade_manager
	)

	current_tree = new_tree
	upgrade_manager = new_upgrade_manager

	if tree_changed:
		_build_tree()
	else:
		refresh_tree()

func set_selected_upgrade(upgrade_id: String) -> void:
	selected_upgrade_id = upgrade_id
	refresh_tree()

func refresh_tree() -> void:
	if upgrade_manager == null:
		return

	for upgrade_id_variant in node_buttons.keys():
		var upgrade_id: String = str(upgrade_id_variant)
		var node_button: Button = node_buttons[upgrade_id] as Button

		if node_button == null:
			continue

		_refresh_node_button(node_button, upgrade_id)

	queue_redraw()

func _build_tree() -> void:
	for child in get_children():
		child.queue_free()

	node_buttons.clear()
	node_positions.clear()

	if upgrade_manager == null:
		return

	for upgrade_id in _get_tree_upgrade_ids():
		var definition: Dictionary = (
			upgrade_manager.get_upgrade_definition(upgrade_id)
		)

		if definition.is_empty():
			continue

		var node_button := Button.new()

		node_button.name = "UpgradeNode_" + upgrade_id
		node_button.custom_minimum_size = NODE_SIZE
		node_button.size = NODE_SIZE
		node_button.focus_mode = Control.FOCUS_NONE
		node_button.clip_text = false
		node_button.tooltip_text = ""

		node_button.add_theme_font_size_override("font_size", 13)

		node_button.pressed.connect(
			_on_upgrade_node_pressed.bind(upgrade_id)
		)

		add_child(node_button)

		node_buttons[upgrade_id] = node_button

	call_deferred("_layout_tree")
	call_deferred("refresh_tree")

func _layout_tree() -> void:
	var upgrade_ids: Array[String] = _get_tree_upgrade_ids()

	if upgrade_ids.size() != 3:
		return

	var root_upgrade_id: String = upgrade_ids[0]
	var left_upgrade_id: String = upgrade_ids[1]
	var right_upgrade_id: String = upgrade_ids[2]

	var usable_width: float = maxf(
		size.x,
		NODE_SIZE.x + NODE_MARGIN * 2.0
	)

	var root_x: float = clampf(
		(usable_width - NODE_SIZE.x) * 0.5,
		NODE_MARGIN,
		usable_width - NODE_SIZE.x - NODE_MARGIN
	)

	var branch_y: float = maxf(
		150.0,
		size.y - NODE_SIZE.y - 22.0
	)

	var left_x: float = NODE_MARGIN

	var right_x: float = maxf(
		NODE_MARGIN,
		usable_width - NODE_SIZE.x - NODE_MARGIN
	)

	node_positions[root_upgrade_id] = Vector2(root_x, 24.0)
	node_positions[left_upgrade_id] = Vector2(left_x, branch_y)
	node_positions[right_upgrade_id] = Vector2(right_x, branch_y)

	for upgrade_id_variant in node_buttons.keys():
		var upgrade_id: String = str(upgrade_id_variant)

		if not node_positions.has(upgrade_id):
			continue

		var node_button: Button = node_buttons[upgrade_id] as Button

		if node_button == null:
			continue

		node_button.position = node_positions[upgrade_id]

	queue_redraw()

func _draw() -> void:
	var upgrade_ids: Array[String] = _get_tree_upgrade_ids()

	if upgrade_ids.size() != 3:
		return

	var root_upgrade_id: String = upgrade_ids[0]
	var left_upgrade_id: String = upgrade_ids[1]
	var right_upgrade_id: String = upgrade_ids[2]

	if (
		not node_positions.has(root_upgrade_id)
		or not node_positions.has(left_upgrade_id)
		or not node_positions.has(right_upgrade_id)
	):
		return

	var root_position: Vector2 = node_positions[root_upgrade_id]
	var left_position: Vector2 = node_positions[left_upgrade_id]
	var right_position: Vector2 = node_positions[right_upgrade_id]

	var root_bottom: Vector2 = root_position + Vector2(
		NODE_SIZE.x * 0.5,
		NODE_SIZE.y
	)

	var left_top: Vector2 = left_position + Vector2(
		NODE_SIZE.x * 0.5,
		0.0
	)

	var right_top: Vector2 = right_position + Vector2(
		NODE_SIZE.x * 0.5,
		0.0
	)

	var junction: Vector2 = Vector2(
		root_bottom.x,
		(root_bottom.y + left_top.y) * 0.5
	)

	var line_colour := Color(0.58, 0.52, 0.31, 0.9)

	draw_line(root_bottom, junction, line_colour, 4.0, true)
	draw_line(junction, left_top, line_colour, 4.0, true)
	draw_line(junction, right_top, line_colour, 4.0, true)

func _get_tree_upgrade_ids() -> Array[String]:
	match current_tree:
		UpgradeManager.TAB_PLAYER:
			return [
				UpgradeManager.UPGRADE_FIELD_CONDITIONING,
				UpgradeManager.UPGRADE_FIELD_RUNNER,
				UpgradeManager.UPGRADE_HOMESTEAD_GUARDIAN
			]

		UpgradeManager.TAB_FENCE:
			return [
				UpgradeManager.UPGRADE_REINFORCED_TIMBER,
				UpgradeManager.UPGRADE_STRONGHOLD_FRAMES,
				UpgradeManager.UPGRADE_RAPID_PATCHWORK
			]

	return []

func _refresh_node_button(
	node_button: Button,
	upgrade_id: String
) -> void:
	var definition: Dictionary = (
		upgrade_manager.get_upgrade_definition(upgrade_id)
	)

	var status: String = upgrade_manager.get_upgrade_status(upgrade_id)

	var label_text: String = str(
		NODE_LABELS.get(
			upgrade_id,
			str(definition.get("title", upgrade_id)).to_upper()
		)
	)

	var selected_prefix: String = ""

	if upgrade_id == selected_upgrade_id:
		selected_prefix = "▶ "

	node_button.text = (
		selected_prefix
		+ label_text
		+ "\n"
		+ _get_short_status_text(status)
	)

	node_button.tooltip_text = (
		str(definition.get("title", upgrade_id))
		+ "\n"
		+ str(definition.get("description", ""))
		+ "\nCost: "
		+ str(definition.get("cost_scrap", 0))
		+ " Scrap"
		+ "\n"
		+ upgrade_manager.get_upgrade_status_message(upgrade_id)
	)

	match status:
		UpgradeManager.STATUS_PURCHASED:
			node_button.modulate = Color(1.0, 0.82, 0.24)

		UpgradeManager.STATUS_AVAILABLE:
			node_button.modulate = Color(0.62, 0.88, 0.58)

		UpgradeManager.STATUS_INSUFFICIENT_SCRAP:
			node_button.modulate = Color(0.88, 0.62, 0.26)

		UpgradeManager.STATUS_LOCKED_BRANCH:
			node_button.modulate = Color(0.72, 0.34, 0.34)

		UpgradeManager.STATUS_LOCKED_PREREQUISITE:
			node_button.modulate = Color(0.52, 0.52, 0.52)

		_:
			node_button.modulate = Color(0.42, 0.42, 0.42)

func _get_short_status_text(status: String) -> String:
	match status:
		UpgradeManager.STATUS_PURCHASED:
			return "PURCHASED"

		UpgradeManager.STATUS_AVAILABLE:
			return "AVAILABLE"

		UpgradeManager.STATUS_INSUFFICIENT_SCRAP:
			return "NEEDS SCRAP"

		UpgradeManager.STATUS_LOCKED_BRANCH:
			return "BRANCH LOCKED"

		UpgradeManager.STATUS_LOCKED_PREREQUISITE:
			return "LOCKED"

	return "UNAVAILABLE"

func _on_upgrade_node_pressed(upgrade_id: String) -> void:
	selected_upgrade_id = upgrade_id
	refresh_tree()

	upgrade_selected.emit(upgrade_id)

func _on_resized() -> void:
	_layout_tree()
