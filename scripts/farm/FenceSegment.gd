extends Node2D
class_name FenceSegment

const SEGMENT_LENGTH: float = 32.0
const SEGMENT_THICKNESS: float = 8.0
const REPAIR_RANGE: float = 42.0

const HEALTH_BAR_WIDTH: float = 28.0
const HEALTH_BAR_HEIGHT: float = 3.0

@onready var blocker: StaticBody2D = $StaticBody2D
@onready var collision_shape: CollisionShape2D = $StaticBody2D/CollisionShape2D

@onready var repair_area: Area2D = $RepairArea
@onready var repair_area_shape: CollisionShape2D = (
	$RepairArea/CollisionShape2D
)

@onready var health_bar: Node2D = $HealthBar
@onready var health_background: Polygon2D = $HealthBar/Background
@onready var health_fill: Polygon2D = $HealthBar/Fill

@onready var repair_prompt: Label = $RepairPrompt

var defense_manager: DefenseManager = null
var fence_key: String = ""

var fence_state: String = "perfect"
var health_ratio: float = 1.0

var player_in_repair_range: Node = null

var repair_debug_session_active: bool = false

func _ready() -> void:
	add_to_group("fences")

	_setup_collision()
	_setup_repair_area()
	_setup_health_bar()

	repair_prompt.visible = false
	health_bar.visible = false

	repair_area.body_entered.connect(_on_repair_area_body_entered)
	repair_area.body_exited.connect(_on_repair_area_body_exited)

	_position_world_ui()
	queue_redraw()

func configure_fence(
	new_defense_manager: DefenseManager,
	new_fence_key: String
) -> void:
	defense_manager = new_defense_manager
	fence_key = new_fence_key
	blocker.set_meta("fence_key", fence_key)
	blocker.set_meta("fence_segment", self)

	if not defense_manager.fence_state_changed.is_connected(
		_on_fence_state_changed
	):
		defense_manager.fence_state_changed.connect(
			_on_fence_state_changed
		)
	
	if not defense_manager.fence_navigation_changed.is_connected(
		_on_fence_navigation_changed
	):
		defense_manager.fence_navigation_changed.connect(
			_on_fence_navigation_changed
		)

	_refresh_from_manager()

func _physics_process(delta: float) -> void:
	_position_world_ui()
	_update_repair_prompt()

	if not _can_repair_now():
		repair_debug_session_active = false
		return

	if Input.is_action_pressed("repair_fence"):
		_repair_while_holding(delta)
	else:
		repair_debug_session_active = false

func _setup_collision() -> void:
	var rectangle_shape: RectangleShape2D = (
		collision_shape.shape as RectangleShape2D
	)

	if rectangle_shape == null:
		rectangle_shape = RectangleShape2D.new()
		collision_shape.shape = rectangle_shape

	rectangle_shape.size = Vector2(
		SEGMENT_LENGTH,
		SEGMENT_THICKNESS
	)

	# Layer 3: movement barrier for player and enemies.
	blocker.collision_layer = 4
	blocker.collision_mask = 0

func _setup_repair_area() -> void:
	var circle_shape: CircleShape2D = (
		repair_area_shape.shape as CircleShape2D
	)

	if circle_shape == null:
		circle_shape = CircleShape2D.new()
		repair_area_shape.shape = circle_shape

	circle_shape.radius = REPAIR_RANGE

	# Detect Player on Layer 1. This does not block movement.
	repair_area.collision_layer = 0
	repair_area.collision_mask = 1
	repair_area.monitoring = true
	repair_area.monitorable = false

func _setup_health_bar() -> void:
	health_background.color = Color(0.82, 0.12, 0.12)
	health_fill.color = Color(0.20, 0.90, 0.28)

	health_background.polygon = _make_rectangle_polygon(
		Vector2(
			-HEALTH_BAR_WIDTH / 2.0,
			-HEALTH_BAR_HEIGHT / 2.0
		),
		Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)
	)

	_update_health_fill()

func _make_rectangle_polygon(
	top_left: Vector2,
	rectangle_size: Vector2
) -> PackedVector2Array:
	return PackedVector2Array([
		top_left,
		top_left + Vector2(rectangle_size.x, 0.0),
		top_left + rectangle_size,
		top_left + Vector2(0.0, rectangle_size.y)
	])

func _refresh_from_manager() -> void:
	if defense_manager == null or fence_key.is_empty():
		return

	fence_state = defense_manager.get_fence_state(fence_key)

	var max_health: float = maxf(
		defense_manager.fence_max_health,
		0.001
	)

	health_ratio = clampf(
		defense_manager.get_fence_current_health(fence_key) / max_health,
		0.0,
		1.0
	)

	var is_broken: bool = (
		fence_state == DefenseManager.FENCE_STATE_BROKEN
	)

	var is_passable_gap: bool = (
		is_broken
		and defense_manager.is_fence_gap_passable(fence_key)
	)

	collision_shape.set_deferred("disabled", is_passable_gap)

	health_bar.visible = (
		fence_state == DefenseManager.FENCE_STATE_DAMAGED
	)

	_update_health_fill()
	_update_repair_prompt()

	queue_redraw()

func _update_health_fill() -> void:
	var fill_width: float = HEALTH_BAR_WIDTH * health_ratio

	health_fill.polygon = _make_rectangle_polygon(
		Vector2(
			-HEALTH_BAR_WIDTH / 2.0,
			-HEALTH_BAR_HEIGHT / 2.0
		),
		Vector2(fill_width, HEALTH_BAR_HEIGHT)
	)

func _position_world_ui() -> void:
	# Keep health and interaction text horizontal on screen
	# for both horizontal and vertical fence pieces.
	health_bar.global_position = global_position + Vector2(0.0, -14.0)
	health_bar.global_rotation = 0.0

	repair_prompt.global_position = (
		global_position + Vector2(-55.0, -44.0)
	)

	repair_prompt.rotation = -global_rotation

func _can_repair_now() -> bool:
	return (
		fence_state == DefenseManager.FENCE_STATE_DAMAGED
		and player_in_repair_range != null
		and _is_daytime()
		and not _is_gameplay_input_blocked()
	)

func _is_daytime() -> bool:
	var time_manager: Node = get_tree().get_first_node_in_group(
		"time_manager"
	)

	if time_manager == null:
		return true

	if time_manager.has_method("is_nighttime"):
		return not bool(time_manager.call("is_nighttime"))

	return true

func _is_gameplay_input_blocked() -> bool:
	var main_node: Node = get_tree().get_first_node_in_group("main")

	if main_node == null:
		return false

	if main_node.has_method("is_gameplay_input_blocked"):
		return bool(main_node.call("is_gameplay_input_blocked"))

	return false

func _update_repair_prompt() -> void:
	var should_show_prompt: bool = (
		fence_state == DefenseManager.FENCE_STATE_DAMAGED
		and player_in_repair_range != null
		and _is_daytime()
		and not _is_gameplay_input_blocked()
	)

	repair_prompt.visible = should_show_prompt

	if not should_show_prompt:
		return

	if Input.is_action_pressed("repair_fence"):
		return

	if defense_manager != null and defense_manager.is_fence_repair_cost_paid(
		fence_key
	):
		repair_prompt.text = "Fix (Hold F)"
	else:
		repair_prompt.text = (
			"Fix (Hold F)\nScrap: %d"
			% defense_manager.damaged_fence_repair_cost_scrap
		)

func _repair_while_holding(delta: float) -> void:
	if defense_manager == null:
		return

	var repair_cost_was_paid: bool = (
		defense_manager.is_fence_repair_cost_paid(fence_key)
	)

	if not repair_cost_was_paid:
		var repair_cost: int = (
			defense_manager.damaged_fence_repair_cost_scrap
		)

		if repair_cost > 0:
			if player_in_repair_range == null:
				return

			if not player_in_repair_range.has_method("spend_resource"):
				return

			var spent_successfully: bool = bool(
				player_in_repair_range.call(
					"spend_resource",
					"scrap",
					repair_cost
				)
			)

			if not spent_successfully:
				repair_prompt.text = "Need %d Scrap" % repair_cost

				print(
					"[Fence Repair] Cannot start repairing ",
					fence_key,
					". Need ",
					repair_cost,
					" Scrap."
				)

				repair_debug_session_active = false
				return

		defense_manager.mark_fence_repair_cost_paid(fence_key)

	if not repair_debug_session_active:
		print(
			"[Fence Repair] Started repairing ",
			fence_key,
			" | Current HP: ",
			defense_manager.get_fence_current_health(fence_key),
			" | Max HP: ",
			defense_manager.fence_max_health
		)

		repair_debug_session_active = true

	repair_prompt.text = "Fixing..."

	defense_manager.repair_fence(
		fence_key,
		defense_manager.fence_repair_rate_per_second * delta
	)

	if defense_manager.get_fence_state(fence_key) == (
		DefenseManager.FENCE_STATE_PERFECT
	):
		print(
			"[Fence Repair] Completed repair for ",
			fence_key
		)

		repair_debug_session_active = false


func _draw() -> void:
	var fence_rect := Rect2(
		Vector2(
			-SEGMENT_LENGTH / 2.0,
			-SEGMENT_THICKNESS / 2.0
		),
		Vector2(SEGMENT_LENGTH, SEGMENT_THICKNESS)
	)

	if fence_state == DefenseManager.FENCE_STATE_BROKEN:
		var debris_color: Color = Color(0.35, 0.16, 0.05)

		draw_line(
			Vector2(-7.0, -3.5),
			Vector2(7.0, 3.5),
			debris_color,
			2.0
		)

		draw_line(
			Vector2(-7.0, 3.5),
			Vector2(7.0, -3.5),
			debris_color,
			2.0
		)

		return

	draw_rect(fence_rect, Color(0.42, 0.24, 0.08))
	draw_rect(
		fence_rect,
		Color(0.20, 0.11, 0.03),
		false,
		1.0
	)

func _on_repair_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_repair_range = body

func _on_repair_area_body_exited(body: Node2D) -> void:
	if body == player_in_repair_range:
		player_in_repair_range = null

func _on_fence_state_changed(
	changed_fence_key: String,
	_new_fence_state: String
) -> void:
	if changed_fence_key != fence_key:
		return

	_refresh_from_manager()

func take_fence_damage(damage_amount: float) -> void:
	if defense_manager == null:
		return

	defense_manager.damage_fence(fence_key, damage_amount)
	
func take_damage(damage_amount: float) -> void:
	take_fence_damage(damage_amount)

func is_broken_for_navigation() -> bool:
	return fence_state == DefenseManager.FENCE_STATE_BROKEN

func can_be_targeted_by_enemy() -> bool:
	return not is_broken_for_navigation()

func get_target_position() -> Vector2:
	return global_position
	
func get_fence_orientation() -> String:
	if defense_manager == null or fence_key.is_empty():
		return ""

	var fence_data: Dictionary = defense_manager.get_fence_data(fence_key)

	return str(fence_data.get("orientation", ""))

func get_fence_grid_edge() -> Vector2i:
	if defense_manager == null or fence_key.is_empty():
		return Vector2i.ZERO

	var fence_data: Dictionary = defense_manager.get_fence_data(fence_key)

	return fence_data.get("grid_edge", Vector2i.ZERO)

func get_fence_identifier() -> String:
	return fence_key
	
func is_passable_gap_for_navigation(
	required_segment_count: int = 0
) -> bool:
	if defense_manager == null or fence_key.is_empty():
		return false

	return defense_manager.is_fence_gap_passable(
		fence_key,
		required_segment_count
	)

func get_breach_entry_position() -> Vector2:
	if defense_manager == null or fence_key.is_empty():
		return global_position

	return defense_manager.get_fence_gap_center_position(fence_key)

func _on_fence_navigation_changed() -> void:
	_refresh_from_manager()
	
func get_perimeter_breach_route(
	required_segment_count: int = 0
) -> Dictionary:
	if defense_manager == null or fence_key.is_empty():
		return {}

	return defense_manager.get_perimeter_breach_route(
		fence_key,
		required_segment_count
	)

func get_perimeter_side() -> String:
	if defense_manager == null or fence_key.is_empty():
		return ""

	return defense_manager.get_perimeter_side_for_fence(fence_key)
