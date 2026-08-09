extends Control
class_name UpgradeTreeBoard

signal upgrade_selected(upgrade_id: String)

const NODE_SIZE: Vector2 = Vector2(142.0, 72.0)
const NODE_MARGIN: float = 12.0
const LAYER_GAP: float = 44.0
const MIN_ZOOM: float = 0.55
const MAX_ZOOM: float = 1.35
const ZOOM_STEP: float = 0.10
const PAN_PADDING: float = 18.0
const SCROLLBAR_THICKNESS: float = 9.0

const NODE_LABELS: Dictionary = {
	UpgradeManager.UPGRADE_FIELD_CONDITIONING:
		"FIELD\nCONDITIONING I",
	UpgradeManager.UPGRADE_FIELD_CONDITIONING_2:
		"FIELD\nCONDITIONING II",
	UpgradeManager.UPGRADE_FIELD_CONDITIONING_3:
		"FIELD\nCONDITIONING III",
	UpgradeManager.UPGRADE_FIELD_RUNNER:
		"FIELD\nRUNNER I",
	UpgradeManager.UPGRADE_FIELD_RUNNER_2:
		"FIELD\nRUNNER II",
	UpgradeManager.UPGRADE_HOMESTEAD_GUARDIAN:
		"HOMESTEAD\nGUARDIAN I",
	UpgradeManager.UPGRADE_HOMESTEAD_GUARDIAN_2:
		"HOMESTEAD\nGUARDIAN II",

	UpgradeManager.UPGRADE_REINFORCED_TIMBER:
		"REINFORCED\nTIMBER I",
	UpgradeManager.UPGRADE_REINFORCED_TIMBER_2:
		"REINFORCED\nTIMBER II",
	UpgradeManager.UPGRADE_REINFORCED_TIMBER_3:
		"REINFORCED\nTIMBER III",
	UpgradeManager.UPGRADE_STRONGHOLD_FRAMES:
		"STRONGHOLD\nFRAMES",
	UpgradeManager.UPGRADE_IRON_BRACING:
		"IRON\nBRACING",
	UpgradeManager.UPGRADE_RAPID_PATCHWORK:
		"RAPID\nPATCHWORK I",
	UpgradeManager.UPGRADE_RAPID_PATCHWORK_2:
		"RAPID\nPATCHWORK II",

	UpgradeManager.UPGRADE_STABLE_GRIP:
		"STABLE\nGRIP",
	UpgradeManager.UPGRADE_FARMLOAD_ROUNDS:
		"FARMLOAD\nROUNDS",
	UpgradeManager.UPGRADE_QUICK_HANDS:
		"QUICK\nHANDS",
	UpgradeManager.UPGRADE_DEEP_AMMO_POUCH:
		"DEEP AMMO\nPOUCH",
	UpgradeManager.UPGRADE_TUNED_TRIGGER:
		"TUNED\nTRIGGER",
	UpgradeManager.UPGRADE_BIGGER_CHAMBER:
		"BIGGER\nCHAMBER",

	UpgradeManager.UPGRADE_SPARE_SPRAYER:
		"SPARE\nSPRAYER",
	UpgradeManager.UPGRADE_REINFORCED_TANKS:
		"REINFORCED\nTANKS",
	UpgradeManager.UPGRADE_FIELD_MAINTENANCE:
		"FIELD\nMAINTENANCE",
	UpgradeManager.UPGRADE_EXTRA_TURRET_FRAME:
		"EXTRA\nTURRET",
	UpgradeManager.UPGRADE_SEALED_PUMP_HOUSING:
		"SEALED\nPUMP"
}

var upgrade_manager: UpgradeManager = null
var current_tree: String = ""
var selected_upgrade_id: String = ""

var node_buttons: Dictionary = {}
var node_positions: Dictionary = {}

var content_size: Vector2 = Vector2.ZERO
var pan_offset: Vector2 = Vector2.ZERO
var zoom_scale: float = 1.0
var is_dragging_view: bool = false
var last_drag_position: Vector2 = Vector2.ZERO
var view_ready: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	tooltip_text = "Drag empty space to move around the tree. Use the mouse wheel to zoom."

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
		view_ready = false
		zoom_scale = 1.0
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

	_apply_view_transform_to_nodes()
	queue_redraw()


func _build_tree() -> void:
	for child in get_children():
		child.queue_free()

	node_buttons.clear()
	node_positions.clear()
	content_size = Vector2.ZERO

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

		node_button.add_theme_font_size_override("font_size", 12)

		node_button.pressed.connect(
			_on_upgrade_node_pressed.bind(upgrade_id)
		)

		add_child(node_button)

		node_buttons[upgrade_id] = node_button

	call_deferred("_layout_tree")
	call_deferred("refresh_tree")


func _layout_tree() -> void:
	var upgrade_ids: Array[String] = _get_tree_upgrade_ids()

	if upgrade_ids.is_empty():
		return

	var depth_by_upgrade: Dictionary = {}
	var upgrades_by_depth: Dictionary = {}
	var max_depth: int = 0

	for upgrade_id in upgrade_ids:
		var depth: int = _get_upgrade_depth(upgrade_id, depth_by_upgrade)
		max_depth = maxi(max_depth, depth)

		if not upgrades_by_depth.has(depth):
			upgrades_by_depth[depth] = []

		var layer_upgrades: Array = upgrades_by_depth[depth]
		layer_upgrades.append(upgrade_id)
		upgrades_by_depth[depth] = layer_upgrades

	var widest_layer_count: int = 1

	for layer_variant in upgrades_by_depth.values():
		var layer_ids: Array = layer_variant
		widest_layer_count = maxi(widest_layer_count, layer_ids.size())

	var tree_width_from_layers: float = (
		float(widest_layer_count) * NODE_SIZE.x
		+ float(maxi(0, widest_layer_count - 1)) * NODE_MARGIN
		+ NODE_MARGIN * 2.0
	)

	var layout_width: float = maxf(
		size.x,
		tree_width_from_layers
	)

	var top_padding: float = 18.0

	for depth_variant in upgrades_by_depth.keys():
		var depth: int = int(depth_variant)
		var layer_ids: Array = upgrades_by_depth[depth]

		layer_ids.sort_custom(
			Callable(self, "_sort_layer_by_definition_order")
		)

		var count: int = layer_ids.size()
		var y_position: float = top_padding + float(depth) * (
			NODE_SIZE.y + LAYER_GAP
		)

		var total_layer_width: float = (
			float(count) * NODE_SIZE.x
			+ float(maxi(0, count - 1)) * NODE_MARGIN
		)

		var start_x: float = (layout_width - total_layer_width) * 0.5

		for index in range(count):
			var upgrade_id: String = str(layer_ids[index])

			var x_position: float = (
				start_x
				+ float(index) * (NODE_SIZE.x + NODE_MARGIN)
			)

			node_positions[upgrade_id] = Vector2(
				x_position,
				y_position
			)

	var max_x: float = 0.0
	var max_y: float = 0.0

	for upgrade_id_variant in node_positions.keys():
		var upgrade_id: String = str(upgrade_id_variant)
		var node_position: Vector2 = node_positions[upgrade_id]

		max_x = maxf(max_x, node_position.x + NODE_SIZE.x)
		max_y = maxf(max_y, node_position.y + NODE_SIZE.y)

	content_size = Vector2(
		maxf(layout_width, max_x + NODE_MARGIN),
		max_y + 24.0
	)

	if not view_ready:
		_reset_view_to_top()
		view_ready = true
	else:
		_clamp_pan_offset()

	_apply_view_transform_to_nodes()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton

		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			_zoom_at_position(mouse_event.position, ZOOM_STEP)
			accept_event()
			return

		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			_zoom_at_position(mouse_event.position, -ZOOM_STEP)
			accept_event()
			return

		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				is_dragging_view = true
				last_drag_position = mouse_event.position
				accept_event()
			else:
				is_dragging_view = false
				accept_event()
			return

	if event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event as InputEventMouseMotion

		if is_dragging_view:
			pan_offset += motion_event.position - last_drag_position
			last_drag_position = motion_event.position
			_clamp_pan_offset()
			_apply_view_transform_to_nodes()
			queue_redraw()
			accept_event()


func _draw() -> void:
	if upgrade_manager == null:
		return

	var line_colour := Color(0.58, 0.52, 0.31, 0.9)

	for upgrade_id in _get_tree_upgrade_ids():
		if not node_positions.has(upgrade_id):
			continue

		var definition: Dictionary = (
			upgrade_manager.get_upgrade_definition(upgrade_id)
		)

		var required_upgrades: Array = definition.get("requires", [])

		for required_variant in required_upgrades:
			var required_upgrade_id: String = str(required_variant)

			if not node_positions.has(required_upgrade_id):
				continue

			var parent_position: Vector2 = node_positions[required_upgrade_id]
			var child_position: Vector2 = node_positions[upgrade_id]

			var parent_bottom: Vector2 = parent_position + Vector2(
				NODE_SIZE.x * 0.5,
				NODE_SIZE.y
			)

			var child_top: Vector2 = child_position + Vector2(
				NODE_SIZE.x * 0.5,
				0.0
			)

			draw_line(
				_tree_to_screen(parent_bottom),
				_tree_to_screen(child_top),
				line_colour,
				maxf(2.0, 4.0 * zoom_scale),
				true
			)

	_draw_scrollbar_indicators()
	_draw_navigation_hint()


func _apply_view_transform_to_nodes() -> void:
	for upgrade_id_variant in node_buttons.keys():
		var upgrade_id: String = str(upgrade_id_variant)

		if not node_positions.has(upgrade_id):
			continue

		var node_button: Button = node_buttons[upgrade_id] as Button

		if node_button == null:
			continue

		node_button.position = _tree_to_screen(node_positions[upgrade_id])
		node_button.size = NODE_SIZE * zoom_scale
		node_button.custom_minimum_size = NODE_SIZE * zoom_scale
		node_button.scale = Vector2.ONE
		node_button.visible = _is_node_visible(node_button)
		node_button.add_theme_font_size_override(
			"font_size",
			maxi(8, int(round(12.0 * zoom_scale)))
		)


func _tree_to_screen(tree_position: Vector2) -> Vector2:
	return tree_position * zoom_scale + pan_offset


func _screen_to_tree(screen_position: Vector2) -> Vector2:
	return (screen_position - pan_offset) / zoom_scale


func _zoom_at_position(
	mouse_position: Vector2,
	zoom_delta: float
) -> void:
	var old_zoom: float = zoom_scale
	var new_zoom: float = clampf(
		zoom_scale + zoom_delta,
		MIN_ZOOM,
		MAX_ZOOM
	)

	if is_equal_approx(old_zoom, new_zoom):
		return

	var tree_position_under_mouse: Vector2 = _screen_to_tree(mouse_position)
	zoom_scale = new_zoom
	pan_offset = mouse_position - tree_position_under_mouse * zoom_scale

	_clamp_pan_offset()
	_apply_view_transform_to_nodes()
	queue_redraw()


func _reset_view_to_top() -> void:
	var scaled_content_size: Vector2 = content_size * zoom_scale

	pan_offset.x = (size.x - scaled_content_size.x) * 0.5
	pan_offset.y = 8.0

	_clamp_pan_offset()


func _clamp_pan_offset() -> void:
	var scaled_content_size: Vector2 = content_size * zoom_scale

	if scaled_content_size.x <= size.x - PAN_PADDING * 2.0:
		pan_offset.x = (size.x - scaled_content_size.x) * 0.5
	else:
		pan_offset.x = clampf(
			pan_offset.x,
			size.x - scaled_content_size.x - PAN_PADDING,
			PAN_PADDING
		)

	if scaled_content_size.y <= size.y - PAN_PADDING * 2.0:
		pan_offset.y = (size.y - scaled_content_size.y) * 0.5
	else:
		pan_offset.y = clampf(
			pan_offset.y,
			size.y - scaled_content_size.y - PAN_PADDING,
			PAN_PADDING
		)


func _is_node_visible(node_button: Button) -> bool:
	var button_rect := Rect2(
		node_button.position,
		node_button.size
	)

	var visible_rect := Rect2(
		Vector2.ZERO,
		size
	).grow(40.0)

	return visible_rect.intersects(button_rect)


func _draw_scrollbar_indicators() -> void:
	var scaled_content_size: Vector2 = content_size * zoom_scale
	var track_colour := Color(0.06, 0.055, 0.045, 0.92)
	var thumb_colour := Color(0.95, 0.75, 0.28, 0.9)

	if scaled_content_size.y > size.y:
		var track_rect := Rect2(
			Vector2(size.x - SCROLLBAR_THICKNESS - 2.0, 4.0),
			Vector2(SCROLLBAR_THICKNESS, size.y - 16.0)
		)
		draw_rect(track_rect, track_colour, true)

		var view_ratio_y: float = clampf(
			size.y / scaled_content_size.y,
			0.08,
			1.0
		)
		var thumb_height: float = maxf(26.0, track_rect.size.y * view_ratio_y)
		var max_scroll_y: float = scaled_content_size.y - size.y
		var scroll_y: float = clampf(-pan_offset.y, 0.0, max_scroll_y)
		var progress_y: float = 0.0

		if max_scroll_y > 0.0:
			progress_y = scroll_y / max_scroll_y

		var thumb_y: float = track_rect.position.y + (
			track_rect.size.y - thumb_height
		) * progress_y

		draw_rect(
			Rect2(
				Vector2(track_rect.position.x, thumb_y),
				Vector2(track_rect.size.x, thumb_height)
			),
			thumb_colour,
			true
		)

	if scaled_content_size.x > size.x:
		var track_rect_x := Rect2(
			Vector2(4.0, size.y - SCROLLBAR_THICKNESS - 2.0),
			Vector2(size.x - 16.0, SCROLLBAR_THICKNESS)
		)
		draw_rect(track_rect_x, track_colour, true)

		var view_ratio_x: float = clampf(
			size.x / scaled_content_size.x,
			0.08,
			1.0
		)
		var thumb_width: float = maxf(30.0, track_rect_x.size.x * view_ratio_x)
		var max_scroll_x: float = scaled_content_size.x - size.x
		var scroll_x: float = clampf(-pan_offset.x, 0.0, max_scroll_x)
		var progress_x: float = 0.0

		if max_scroll_x > 0.0:
			progress_x = scroll_x / max_scroll_x

		var thumb_x: float = track_rect_x.position.x + (
			track_rect_x.size.x - thumb_width
		) * progress_x

		draw_rect(
			Rect2(
				Vector2(thumb_x, track_rect_x.position.y),
				Vector2(thumb_width, track_rect_x.size.y)
			),
			thumb_colour,
			true
		)


func _draw_navigation_hint() -> void:
	var hint_text: String = "Drag empty space to pan   |   Mouse wheel to zoom"
	var font: Font = get_theme_default_font()
	var font_size: int = 12

	if font == null:
		return

	draw_string(
		font,
		Vector2(10.0, size.y - 14.0),
		hint_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		size.x - 24.0,
		font_size,
		Color(1.0, 0.86, 0.42, 0.88)
	)


func _get_tree_upgrade_ids() -> Array[String]:
	if upgrade_manager == null:
		return []

	return upgrade_manager.get_upgrade_ids_for_tree(current_tree)


func _get_upgrade_depth(
	upgrade_id: String,
	depth_cache: Dictionary
) -> int:
	if depth_cache.has(upgrade_id):
		return int(depth_cache[upgrade_id])

	if upgrade_manager == null:
		depth_cache[upgrade_id] = 0
		return 0

	var definition: Dictionary = upgrade_manager.get_upgrade_definition(
		upgrade_id
	)

	var required_upgrades: Array = definition.get("requires", [])

	if required_upgrades.is_empty():
		depth_cache[upgrade_id] = 0
		return 0

	var deepest_required_depth: int = 0

	for required_variant in required_upgrades:
		var required_upgrade_id: String = str(required_variant)

		deepest_required_depth = maxi(
			deepest_required_depth,
			_get_upgrade_depth(required_upgrade_id, depth_cache)
		)

	var depth: int = deepest_required_depth + 1
	depth_cache[upgrade_id] = depth
	return depth


func _sort_layer_by_definition_order(a, b) -> bool:
	if upgrade_manager == null:
		return str(a) < str(b)

	var a_definition: Dictionary = upgrade_manager.get_upgrade_definition(str(a))
	var b_definition: Dictionary = upgrade_manager.get_upgrade_definition(str(b))

	var a_order: int = int(a_definition.get("order", 9999))
	var b_order: int = int(b_definition.get("order", 9999))

	if a_order == b_order:
		return str(a) < str(b)

	return a_order < b_order


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
