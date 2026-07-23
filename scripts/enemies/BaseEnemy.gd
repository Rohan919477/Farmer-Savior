extends CharacterBody2D
class_name BaseEnemy

const FENCE_COLLISION_MASK: int = 4

@export var enemy_name: String = "Base Enemy"

@export var max_health: int = 45
@export var move_speed: float = 80.0

@export var contact_damage: int = 10
@export var fence_damage_multiplier: float = 1.0
@export var structure_damage_multiplier: float = 1.0

@export var damage_cooldown: float = 0.8

@export var attack_range: float = 28.0
@export var fence_attack_range: float = 34.0

@export var player_priority_distance: float = 240.0
@export var placeable_priority_ratio: float = 0.65
@export var target_refresh_interval: float = 0.20
@export var breach_route_multiplier: float = 1.35

@export var damage_type: String = "Blunt"
@export var debug_ai_logging: bool = true
@export var breach_waypoint_reach_distance: float = 12.0
@export var required_fence_gap_segments: int = 1
@export var body_radius: float = 10.0
@export var visual_scale_multiplier: float = 1.0

@export var seed_drop_scene: PackedScene
@export var scrap_drop_scene: PackedScene
@export var seed_drop_chance: float = 0.5
@export var scrap_drop_chance: float = 0.3

@export var guaranteed_seed_drops: int = 0
@export var guaranteed_scrap_drops: int = 0

var current_health: int
var player: Node2D
var defense_manager: DefenseManager = null
var current_breach_crossing: bool = false

var current_primary_target: Node2D = null
var current_fence_target: Node2D = null
var current_breach_target: Node2D = null

var target_refresh_timer: float = 0.0
var can_attack_target: bool = true
var last_debug_action: String = ""

@onready var sprite: Sprite2D = $Sprite2D
@onready var damage_area: Area2D = $DamageArea

@onready var body_collision: CollisionShape2D = (
	get_node_or_null("CollisionShape2D") as CollisionShape2D
)

@onready var damage_area_collision: CollisionShape2D = (
	get_node_or_null("DamageArea/CollisionShape2D") as CollisionShape2D
)

func _ready() -> void:
	add_to_group("enemies")

	current_health = max_health

	_apply_body_profile()
	
	defense_manager = (
		get_tree().get_first_node_in_group("defense_manager")
		as DefenseManager
	)

	# Fences remain on Collision Layer 3.
	collision_mask |= FENCE_COLLISION_MASK

	_refresh_player_reference()

	if damage_area != null:
		damage_area.body_entered.connect(_on_damage_area_body_entered)
		damage_area.body_exited.connect(_on_damage_area_body_exited)

func _physics_process(delta: float) -> void:
	if _is_tutorial_world_soft_paused():
		velocity = Vector2.ZERO
		return

	_refresh_player_reference()

	if player == null:
		return

	target_refresh_timer -= delta

	if target_refresh_timer <= 0.0:
		_refresh_primary_target()
		target_refresh_timer = target_refresh_interval

	update_enemy_behavior()

func update_enemy_behavior() -> void:
	execute_shared_target_strategy()
	
func _should_use_open_exterior_chase(
	target_position: Vector2
) -> bool:
	if defense_manager == null:
		return false

	var enemy_is_outside_farm: bool = (
		not defense_manager.is_world_position_inside_farm_perimeter(
			global_position
		)
	)

	var target_is_outside_farm: bool = (
		not defense_manager.is_world_position_inside_farm_perimeter(
			target_position
		)
	)

	return enemy_is_outside_farm and target_is_outside_farm

func execute_shared_target_strategy() -> void:
	if current_primary_target == null:
		velocity = Vector2.ZERO
		return

	if not is_instance_valid(current_primary_target):
		current_primary_target = null
		velocity = Vector2.ZERO
		return

	var target_position: Vector2 = get_target_position(
		current_primary_target
	)

	var target_distance: float = global_position.distance_to(
		target_position
	)
	
	# When both enemy and target are outside the farm perimeter,
	# fences and breach logic are irrelevant.
	if _should_use_open_exterior_chase(target_position):
		current_fence_target = null
		current_breach_target = null
		current_breach_crossing = false

		if target_distance <= get_attack_range():
			velocity = Vector2.ZERO

			_log_ai_action(
				"Directly attacking exterior target %s."
				% _get_target_name(current_primary_target)
			)

			try_attack_target(current_primary_target)
		else:
			_log_ai_action(
				"Chasing exterior target %s."
				% _get_target_name(current_primary_target)
			)

			move_towards_position(target_position)

		return

	# Ranged/AoE enemies can attack through fences.
	if attacks_through_fences() and target_distance <= get_attack_range():
		velocity = Vector2.ZERO

		_log_ai_action(
			"Attacking %s through fence range."
			% _get_target_name(current_primary_target)
		)

		try_attack_target(current_primary_target)
		return

	# A passable breach on the current exterior side has priority.
	var breach_data: Dictionary = find_best_breach_for_target(
		target_position
	)

	if not breach_data.is_empty():
		var selected_breach: Node2D = breach_data.get(
			"fence",
			null
		) as Node2D

		if selected_breach != current_breach_target:
			current_breach_crossing = false

		current_breach_target = selected_breach
		current_fence_target = null

		if _follow_breach_route(breach_data):
			return

	current_breach_target = null
	current_breach_crossing = false

	# Important: do not keep attacking an old fence merely because it was
	# selected before the enemy entered through a breach.
	if not _is_current_fence_target_still_relevant(target_position):
		current_fence_target = null

	# Keep breaking the same relevant intact fence until it breaks.
	if _is_intact_fence(current_fence_target):
		_move_or_attack_fence(
			current_fence_target,
			target_position
		)
		return

	var blocking_fence: Node2D = get_first_blocking_fence_to(
		target_position
	)

	if _should_ignore_blocking_fence(
		blocking_fence,
		target_position
	):
		blocking_fence = null

	if blocking_fence != null:
		var fence_to_break: Node2D = _choose_fence_to_break(
			blocking_fence,
			target_position
		)

		if fence_to_break != null:
			current_fence_target = fence_to_break

			_move_or_attack_fence(
				current_fence_target,
				target_position
			)

			return

		velocity = Vector2.ZERO

		_log_ai_action(
			"Blocked by a narrow broken gap; no adjacent intact fence found."
		)

		return

	if target_distance <= get_attack_range():
		velocity = Vector2.ZERO

		_log_ai_action(
			"Directly attacking %s."
			% _get_target_name(current_primary_target)
		)

		try_attack_target(current_primary_target)
	else:
		_log_ai_action(
			"Moving directly toward %s."
			% _get_target_name(current_primary_target)
		)

		move_towards_position(target_position)

func _apply_body_profile() -> void:
	required_fence_gap_segments = maxi(
		1,
		required_fence_gap_segments
	)

	body_radius = maxf(4.0, body_radius)

	if sprite != null:
		# Important:
		# This multiplies the scene's existing sprite scale instead of
		# replacing it with Vector2.ONE. This prevents placeholder art
		# from becoming unexpectedly huge or losing its original setup.
		sprite.scale = sprite.scale * visual_scale_multiplier

	if body_collision != null:
		_apply_collision_radius(body_collision, body_radius)
	else:
		print(
			"[Enemy Body Profile] ",
			enemy_name,
			" has no root CollisionShape2D. Collision size was not changed."
		)

	if damage_area_collision != null:
		var damage_radius: float = maxf(
			body_radius + 8.0,
			attack_range
		)

		_apply_collision_radius(
			damage_area_collision,
			damage_radius
		)
	else:
		print(
			"[Enemy Body Profile] ",
			enemy_name,
			" has no DamageArea/CollisionShape2D."
		)

func _apply_collision_radius(
	collision_shape: CollisionShape2D,
	radius: float
) -> void:
	if collision_shape == null:
		return

	if collision_shape.shape == null:
		var circle_shape := CircleShape2D.new()
		circle_shape.radius = radius
		collision_shape.shape = circle_shape
		return

	var new_shape: Shape2D = collision_shape.shape.duplicate()

	if new_shape is CircleShape2D:
		var circle_shape: CircleShape2D = new_shape as CircleShape2D
		circle_shape.radius = radius
		collision_shape.shape = circle_shape
		return

	if new_shape is RectangleShape2D:
		var rectangle_shape: RectangleShape2D = (
			new_shape as RectangleShape2D
		)

		rectangle_shape.size = Vector2(
			radius * 2.0,
			radius * 2.0
		)

		collision_shape.shape = rectangle_shape
		return

	if new_shape is CapsuleShape2D:
		var capsule_shape: CapsuleShape2D = (
			new_shape as CapsuleShape2D
		)

		capsule_shape.radius = radius
		capsule_shape.height = radius * 2.4

		collision_shape.shape = capsule_shape
		return

	collision_shape.shape = new_shape

func get_required_fence_gap_segments() -> int:
	return maxi(1, required_fence_gap_segments)
	
func get_fence_damage_amount() -> float:
	return maxf(
		1.0,
		float(contact_damage) * fence_damage_multiplier
	)

func get_structure_damage_amount() -> int:
	return maxi(
		1,
		roundi(float(contact_damage) * structure_damage_multiplier)
	)

func _move_or_attack_fence(
	fence: Node2D,
	target_position: Vector2
) -> void:
	if not _is_intact_fence(fence):
		current_fence_target = null
		return

	var distance_to_fence: float = global_position.distance_to(
		fence.global_position
	)

	var fence_name: String = _get_fence_name(fence)

	if distance_to_fence <= fence_attack_range:
		velocity = Vector2.ZERO

		_log_ai_action(
			"Breaking %s to reach %s."
			% [
				fence_name,
				_get_target_name(current_primary_target)
			]
		)

		try_attack_fence(fence)
		return

	_log_ai_action(
		"Moving to break %s."
		% fence_name
	)

	move_towards_position(fence.global_position)

func _refresh_player_reference() -> void:
	if player != null and is_instance_valid(player):
		return

	player = get_tree().get_first_node_in_group("player") as Node2D

func _refresh_primary_target() -> void:
	if player == null:
		current_primary_target = _get_nearest_attackable_placeable()
		return

	var nearest_placeable: Node2D = (
		_get_nearest_attackable_placeable()
	)

	if nearest_placeable == null:
		current_primary_target = player
		return

	var player_distance: float = global_position.distance_to(
		player.global_position
	)

	var placeable_distance: float = global_position.distance_to(
		nearest_placeable.global_position
	)

	if player_distance <= player_priority_distance:
		current_primary_target = player
		return

	if placeable_distance < player_distance * placeable_priority_ratio:
		current_primary_target = nearest_placeable
		return

	current_primary_target = player

func _get_nearest_attackable_placeable() -> Node2D:
	var nearest_placeable: Node2D = null
	var nearest_distance_squared: float = INF

	for candidate_node in get_tree().get_nodes_in_group(
		"attackable_placeables"
	):
		if not is_instance_valid(candidate_node):
			continue

		if not (candidate_node is Node2D):
			continue

		var placeable: Node2D = candidate_node as Node2D

		if placeable.has_method("can_be_targeted_by_enemy"):
			var can_target: bool = bool(
				placeable.call("can_be_targeted_by_enemy")
			)

			if not can_target:
				continue

		var distance_squared: float = global_position.distance_squared_to(
			placeable.global_position
		)

		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_placeable = placeable

	return nearest_placeable

func get_primary_target() -> Node2D:
	return current_primary_target

func get_target_position(target: Node2D) -> Vector2:
	if target == null:
		return global_position

	if target.has_method("get_target_position"):
		return target.call("get_target_position")

	return target.global_position

func get_attack_range() -> float:
	return attack_range

func attacks_through_fences() -> bool:
	return false

func has_clear_path_to(target_position: Vector2) -> bool:
	return get_first_blocking_fence_to(target_position) == null

func move_towards_position(
	target_position: Vector2,
	allow_fence_collision_retarget: bool = true
) -> void:
	var direction: Vector2 = global_position.direction_to(
		target_position
	)

	if direction.length() <= 0.0:
		velocity = Vector2.ZERO
		return

	velocity = direction * move_speed
	move_and_slide()

	# While deliberately crossing a known gap, do not accidentally select
	# another perimeter fence as a new attack target.
	if not allow_fence_collision_retarget:
		return

	for collision_index in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(
			collision_index
		)

		var collided_fence: Node2D = get_fence_from_collider(
			collision.get_collider()
		)

		if collided_fence == null:
			continue

		if _should_ignore_blocking_fence(
			collided_fence,
			target_position
		):
			continue

		var fence_to_break: Node2D = _choose_fence_to_break(
			collided_fence,
			target_position
		)

		if fence_to_break == null:
			continue

		current_fence_target = fence_to_break
		velocity = Vector2.ZERO

		_log_ai_action(
			"Physical collision detected; switching to %s."
			% _get_fence_name(fence_to_break)
		)

		try_attack_fence(fence_to_break)
		return

func get_first_blocking_fence_to(
	target_position: Vector2
) -> Node2D:
	if global_position.distance_to(target_position) <= 2.0:
		return null

	var ray_fence: Node2D = get_ray_blocking_fence_to(
		target_position
	)

	if ray_fence != null:
		return ray_fence

	# Detects narrow gaps where the ray may pass but the enemy body cannot.
	return get_body_blocking_fence_to(target_position)

func get_ray_blocking_fence_to(
	target_position: Vector2
) -> Node2D:
	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		target_position,
		FENCE_COLLISION_MASK,
		[get_rid()]
	)

	var ray_result: Dictionary = (
		get_world_2d().direct_space_state.intersect_ray(query)
	)

	if ray_result.is_empty():
		return null

	return get_fence_from_collider(
		ray_result.get("collider", null)
	)

func get_body_blocking_fence_to(
	target_position: Vector2
) -> Node2D:
	var motion: Vector2 = target_position - global_position

	if motion.length() <= 2.0:
		return null

	var collision: KinematicCollision2D = KinematicCollision2D.new()

	var would_collide: bool = test_move(
		global_transform,
		motion,
		collision
	)

	if not would_collide:
		return null

	return get_fence_from_collider(
		collision.get_collider()
	)

func get_fence_from_collider(collider: Object) -> Node2D:
	if collider == null:
		return null

	if not (collider is Node):
		return null

	var collider_node: Node = collider as Node

	if collider_node.has_meta("fence_segment"):
		var fence_variant: Variant = collider_node.get_meta(
			"fence_segment"
		)

		if fence_variant is Node2D:
			var fence_from_meta: Node2D = fence_variant as Node2D

			if is_instance_valid(fence_from_meta):
				return fence_from_meta

	var parent_node: Node = collider_node.get_parent()

	if parent_node == null:
		return null

	if not parent_node.is_in_group("fences"):
		return null

	if not (parent_node is Node2D):
		return null

	return parent_node as Node2D

func find_best_breach_for_target(
	target_position: Vector2
) -> Dictionary:
	var best_breach_data: Dictionary = {}
	var best_score: float = INF

	var exterior_side: String = _get_current_exterior_side()

	# This function is only for enemies currently outside the farm.
	if exterior_side.is_empty():
		return {}

	for candidate_node in get_tree().get_nodes_in_group("fences"):
		if not is_instance_valid(candidate_node):
			continue

		if not (candidate_node is Node2D):
			continue

		var fence: Node2D = candidate_node as Node2D

		var breach_data: Dictionary = get_usable_breach_data(fence)

		if breach_data.is_empty():
			continue

		var breach_side: String = str(
			breach_data.get("perimeter_side", "")
		)

		# Do not drive directly through the farm toward a gap on a
		# different side. Use only a reachable breach on this side.
		if breach_side != exterior_side:
			continue

		var outside_position: Vector2 = breach_data.get(
			"outside_position",
			fence.global_position
		)

		var route_score: float = (
			global_position.distance_to(outside_position)
			+ outside_position.distance_to(target_position) * 0.35
		)

		if route_score < best_score:
			best_score = route_score
			best_breach_data = breach_data

	return best_breach_data

func get_usable_breach_data(fence: Node2D) -> Dictionary:
	if fence == null:
		return {}

	if not fence.has_method("is_passable_gap_for_navigation"):
		return {}

	var required_gap_segments: int = (
		get_required_fence_gap_segments()
	)

	var can_use_breach: bool = bool(
		fence.call(
			"is_passable_gap_for_navigation",
			required_gap_segments
		)
	)

	if not can_use_breach:
		return {}

	if not fence.has_method("get_perimeter_breach_route"):
		return {}

	var route_data: Dictionary = fence.call(
		"get_perimeter_breach_route",
		required_gap_segments
	)

	if route_data.is_empty():
		return {}

	return {
		"fence": fence,
		"perimeter_side": str(route_data.get("side", "")),
		"outside_position": route_data.get(
			"outside_position",
			fence.global_position
		),
		"inside_position": route_data.get(
			"inside_position",
			fence.global_position
		)
	}

func _choose_fence_to_break(
	blocking_fence: Node2D,
	target_position: Vector2
) -> Node2D:
	if blocking_fence == null:
		return null
	
	if _should_ignore_blocking_fence(
		blocking_fence,
		target_position
	):
		return null

	# Intact fence: attack it directly.
	if _is_intact_fence(blocking_fence):
		return blocking_fence

	# Broken but still non-passable: expand this broken run.
	if _is_broken_fence(blocking_fence):
		return _get_adjacent_intact_fence_to_expand_breach(
			blocking_fence,
			target_position
		)

	return null

func _get_adjacent_intact_fence_to_expand_breach(
	broken_fence: Node2D,
	target_position: Vector2
) -> Node2D:
	if broken_fence == null:
		return null

	if not broken_fence.has_method("get_fence_orientation"):
		return null

	if not broken_fence.has_method("get_fence_grid_edge"):
		return null

	var orientation: String = str(
		broken_fence.call("get_fence_orientation")
	)

	var grid_edge: Vector2i = broken_fence.call(
		"get_fence_grid_edge"
	)

	if orientation.is_empty():
		return null

	var fixed_axis: int = grid_edge.y
	var current_axis: int = grid_edge.x

	if orientation == "vertical":
		fixed_axis = grid_edge.x
		current_axis = grid_edge.y

	var broken_fences_by_axis: Dictionary = {}
	var intact_fences_by_axis: Dictionary = {}

	for candidate_node in get_tree().get_nodes_in_group("fences"):
		if not is_instance_valid(candidate_node):
			continue

		if not (candidate_node is Node2D):
			continue

		var candidate_fence: Node2D = candidate_node as Node2D

		if not candidate_fence.has_method("get_fence_orientation"):
			continue

		if not candidate_fence.has_method("get_fence_grid_edge"):
			continue

		var candidate_orientation: String = str(
			candidate_fence.call("get_fence_orientation")
		)

		if candidate_orientation != orientation:
			continue

		var candidate_edge: Vector2i = candidate_fence.call(
			"get_fence_grid_edge"
		)

		var candidate_fixed_axis: int = candidate_edge.y
		var candidate_axis: int = candidate_edge.x

		if orientation == "vertical":
			candidate_fixed_axis = candidate_edge.x
			candidate_axis = candidate_edge.y

		if candidate_fixed_axis != fixed_axis:
			continue

		if _is_broken_fence(candidate_fence):
			broken_fences_by_axis[candidate_axis] = candidate_fence
		else:
			intact_fences_by_axis[candidate_axis] = candidate_fence

	if not broken_fences_by_axis.has(current_axis):
		return null

	var start_axis: int = current_axis
	var end_axis: int = current_axis

	while broken_fences_by_axis.has(start_axis - 1):
		start_axis -= 1

	while broken_fences_by_axis.has(end_axis + 1):
		end_axis += 1

	var candidate_axes: Array = [
		start_axis - 1,
		end_axis + 1
	]

	var best_fence: Node2D = null
	var best_score: float = INF

	for candidate_axis_variant in candidate_axes:
		var candidate_axis: int = int(candidate_axis_variant)

		if not intact_fences_by_axis.has(candidate_axis):
			continue

		var candidate_fence: Node2D = (
			intact_fences_by_axis[candidate_axis] as Node2D
		)

		if candidate_fence == null:
			continue

		var score: float = (
			global_position.distance_to(candidate_fence.global_position)
			+ candidate_fence.global_position.distance_to(
				target_position
			) * 0.15
		)

		if score < best_score:
			best_score = score
			best_fence = candidate_fence

	return best_fence

func _is_broken_fence(fence: Node2D) -> bool:
	if fence == null or not is_instance_valid(fence):
		return false

	if not fence.has_method("is_broken_for_navigation"):
		return false

	return bool(fence.call("is_broken_for_navigation"))

func _is_intact_fence(fence: Node2D) -> bool:
	if fence == null or not is_instance_valid(fence):
		return false

	if not fence.has_method("is_broken_for_navigation"):
		return false

	return not bool(fence.call("is_broken_for_navigation"))

func _get_current_exterior_side() -> String:
	if defense_manager == null:
		defense_manager = (
			get_tree().get_first_node_in_group("defense_manager")
			as DefenseManager
		)

	if defense_manager == null:
		return ""

	return defense_manager.get_exterior_side_for_world_position(
		global_position
	)

func _follow_breach_route(
	breach_data: Dictionary
) -> bool:
	var breach_fence: Node2D = breach_data.get(
		"fence",
		null
	) as Node2D

	if breach_fence == null:
		return false

	var breach_side: String = str(
		breach_data.get("perimeter_side", "")
	)

	var outside_position: Vector2 = breach_data.get(
		"outside_position",
		breach_fence.global_position
	)

	var inside_position: Vector2 = breach_data.get(
		"inside_position",
		breach_fence.global_position
	)

	var current_exterior_side: String = (
		_get_current_exterior_side()
	)

	# The enemy center has entered the farm, but large enemies may still
	# be physically overlapping the perimeter. Keep pushing them toward
	# the inside waypoint before releasing normal target logic.
	if current_exterior_side.is_empty():
		var clearance_distance: float = maxf(
			body_radius * 1.10,
			breach_waypoint_reach_distance
		)

		if (
			current_breach_crossing
			and global_position.distance_to(inside_position)
			> clearance_distance
		):
			_log_ai_action(
				"Clearing %s-side breach."
				% breach_side
			)

			move_towards_position(
				inside_position,
				false
			)

			return true

		current_breach_crossing = false
		current_breach_target = null
		current_fence_target = null

		_log_ai_action(
			"Entered farm through %s-side breach."
			% breach_side
		)

		return false

	if current_exterior_side != breach_side:
		return false

	if not current_breach_crossing:
		if global_position.distance_to(outside_position) > (
			breach_waypoint_reach_distance
		):
			_log_ai_action(
				"Approaching %s-side breach."
				% breach_side
			)

			move_towards_position(
				outside_position,
				false
			)

			return true

		current_breach_crossing = true

	_log_ai_action(
		"Crossing %s-side breach."
		% breach_side
	)

	move_towards_position(
		inside_position,
		false
	)

	return true

func _get_fence_perimeter_side(fence: Node2D) -> String:
	if fence == null:
		return ""

	if not fence.has_method("get_perimeter_side"):
		return ""

	return str(fence.call("get_perimeter_side"))
	
func _should_ignore_blocking_fence(
	fence: Node2D,
	target_position: Vector2
) -> bool:
	if fence == null:
		return false

	if defense_manager == null:
		defense_manager = (
			get_tree().get_first_node_in_group("defense_manager")
			as DefenseManager
		)

	if defense_manager == null:
		return false

	var fence_side: String = _get_fence_perimeter_side(fence)

	# Only perimeter fences have a side such as top/bottom/left/right.
	# Player-built interior fences should still be valid blockers.
	if fence_side.is_empty():
		return false

	var enemy_is_inside_farm: bool = (
		defense_manager.is_world_position_inside_farm_perimeter(
			global_position
		)
	)

	var target_is_inside_farm: bool = (
		defense_manager.is_world_position_inside_farm_perimeter(
			target_position
		)
	)

	# Once both the enemy and its target are inside the farm,
	# perimeter fences are no longer meaningful targets.
	return enemy_is_inside_farm and target_is_inside_farm

func _is_current_fence_target_still_relevant(
	target_position: Vector2
) -> bool:
	if not _is_intact_fence(current_fence_target):
		return false

	var exterior_side: String = _get_current_exterior_side()
	var fence_side: String = _get_fence_perimeter_side(
		current_fence_target
	)

	# Once inside, old perimeter fences are never valid ongoing targets.
	if exterior_side.is_empty() and not fence_side.is_empty():
		_log_ai_action(
			"Discarding stale %s-side fence target after entering farm."
			% fence_side
		)

		return false

	# While still outside, keep targeting a perimeter fence only if it is
	# on the same side of the farm as the enemy.
	if not exterior_side.is_empty() and not fence_side.is_empty():
		return fence_side == exterior_side

	# For player-built interior fences, only keep the target if it still
	# directly blocks the current route to the player/placeable.
	var current_blocking_fence: Node2D = get_first_blocking_fence_to(
		target_position
	)

	return current_blocking_fence == current_fence_target

func try_attack_target(target: Node2D) -> void:
	if not can_attack_target:
		return

	if target == null or not is_instance_valid(target):
		return

	perform_attack_on_target(target)

func perform_attack_on_target(target: Node2D) -> void:
	if not target.has_method("take_damage"):
		return

	var damage_to_deal: int = contact_damage

	# Player damage remains controlled.
	# Turrets and future attackable field objects can take heavier damage.
	if target != player and target.is_in_group("attackable_placeables"):
		damage_to_deal = get_structure_damage_amount()

	target.call("take_damage", damage_to_deal)
	start_attack_cooldown()

func try_attack_fence(fence: Node2D) -> void:
	if not can_attack_target:
		return

	if not _is_intact_fence(fence):
		return

	var fence_damage: float = get_fence_damage_amount()

	if fence.has_method("take_fence_damage"):
		fence.call("take_fence_damage", fence_damage)

	elif fence.has_method("take_damage"):
		fence.call("take_damage", fence_damage)

	else:
		return

	start_attack_cooldown()

func start_attack_cooldown() -> void:
	can_attack_target = false

	await get_tree().create_timer(damage_cooldown).timeout

	if is_instance_valid(self):
		can_attack_target = true

func take_damage(amount: int) -> void:
	current_health -= amount
	current_health = max(current_health, 0)

	print(
		enemy_name,
		" took damage: ",
		amount,
		" | HP: ",
		current_health
	)

	show_hit_feedback()

	if current_health <= 0:
		die()

func show_hit_feedback() -> void:
	if sprite == null:
		return

	var original_color: Color = sprite.modulate
	sprite.modulate = Color(1, 1, 1)

	await get_tree().create_timer(0.08).timeout

	if is_instance_valid(sprite):
		sprite.modulate = original_color

func _on_damage_area_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player = body as Node2D

func _on_damage_area_body_exited(_body: Node) -> void:
	pass

func die() -> void:
	print(enemy_name, " died.")
	drop_resources()
	queue_free()

func drop_resources() -> void:
	for seed_index in range(guaranteed_seed_drops):
		if seed_drop_scene != null:
			spawn_drop(
				seed_drop_scene,
				Vector2(-10.0 + float(seed_index) * 6.0, 0.0)
			)
		else:
			print(
				enemy_name,
				" has guaranteed seed drops, but SeedDrop scene is missing."
			)

	for scrap_index in range(guaranteed_scrap_drops):
		if scrap_drop_scene != null:
			spawn_drop(
				scrap_drop_scene,
				Vector2(10.0 + float(scrap_index) * 6.0, 0.0)
			)
		else:
			print(
				enemy_name,
				" has guaranteed scrap drops, but ScrapDrop scene is missing."
			)

	if seed_drop_scene != null and randf() <= seed_drop_chance:
		spawn_drop(seed_drop_scene, Vector2(-14.0, 8.0))

	if scrap_drop_scene != null and randf() <= scrap_drop_chance:
		spawn_drop(scrap_drop_scene, Vector2(14.0, 8.0))

func apply_day_scaling(day_number: int) -> void:
	var day_offset: int = day_number - 1

	if day_offset < 0:
		day_offset = 0

	var health_multiplier: float = 1.0 + float(day_offset) * 0.10
	var damage_multiplier: float = 1.0 + float(day_offset) * 0.05
	var speed_multiplier: float = 1.0 + float(day_offset) * 0.03

	max_health = int(round(float(max_health) * health_multiplier))
	current_health = max_health

	contact_damage = int(
		round(float(contact_damage) * damage_multiplier)
	)

	move_speed = move_speed * speed_multiplier

	damage_cooldown = maxf(
		0.35,
		damage_cooldown - float(day_offset) * 0.03
	)

func spawn_drop(
	drop_scene: PackedScene,
	position_offset: Vector2 = Vector2.ZERO
) -> void:
	var drop: Node2D = drop_scene.instantiate() as Node2D

	if drop == null:
		return

	var drop_parent: Node = get_parent()

	if drop_parent == null:
		drop_parent = get_tree().current_scene

	drop_parent.add_child(drop)
	drop.global_position = global_position + position_offset

func _get_fence_name(fence: Node2D) -> String:
	if fence == null:
		return "Unknown Fence"

	if fence.has_method("get_fence_identifier"):
		return str(fence.call("get_fence_identifier"))

	return fence.name

func _get_target_name(target: Node2D) -> String:
	if target == null:
		return "Unknown Target"

	if target == player:
		return "Player"

	return target.name

func _log_ai_action(new_action: String) -> void:
	if not debug_ai_logging:
		return

	if new_action == last_debug_action:
		return

	last_debug_action = new_action

	print(
		"[AI] ",
		enemy_name,
		" | ",
		new_action
	)

func _is_tutorial_world_soft_paused() -> bool:
	var tutorial_manager: Node = get_tree().get_first_node_in_group(
		"tutorial_manager"
	)

	if tutorial_manager == null:
		return false

	if tutorial_manager.has_method("is_world_soft_paused"):
		return bool(tutorial_manager.call("is_world_soft_paused"))

	return false
