extends CharacterBody2D

signal health_changed(
	current_health: int,
	max_health: int,
	change_amount: int,
	change_type: String
)


@export var move_speed: float = 220.0
@export var max_health: int = 100
@export var damage_taken_multiplier: float = 1.0
@export var aim_deadzone_distance: float = 8.0

var current_health: int
var facing_direction: Vector2 = Vector2.RIGHT
var can_melee_attack: bool = true
var is_dead: bool = false

# Prevents walking/idle animations from replacing a combat animation.
var is_action_animation_playing: bool = false
var hurt_feedback_serial: int = 0
var melee_action_serial: int = 0
var death_sequence_serial: int = 0
var body_sprite_rest_position: Vector2 = Vector2.ZERO

var base_move_speed: float = 220.0
var base_max_health: int = 100
var base_damage_taken_multiplier: float = 1.0

@onready var hoe_hitbox: Area2D = $HoeHitbox
@onready var hoe_collision: CollisionShape2D = (
	$HoeHitbox/CollisionShape2D
)
@onready var health_label: Label = (
	$PlayerDebugUI/HealthLabel
)
@onready var pistol = $Pistol
@onready var body_sprite: AnimatedSprite2D = $BodySprite


func _ready() -> void:
	add_to_group("player")

	if health_label != null:
		health_label.visible = false
		health_label.text = ""

	base_move_speed = move_speed
	base_max_health = max_health
	base_damage_taken_multiplier = damage_taken_multiplier

	current_health = max_health

	if hoe_collision != null:
		hoe_collision.disabled = true

	if body_sprite != null:
		body_sprite.visible = true
		body_sprite.modulate = Color.WHITE
		body_sprite.self_modulate = Color.WHITE
		body_sprite_rest_position = body_sprite.position

		if not body_sprite.animation_finished.is_connected(
			_on_body_animation_finished
		):
			body_sprite.animation_finished.connect(
				_on_body_animation_finished
			)

	update_debug_ui()
	update_body_animation()
	_emit_health_changed(0, "set")


func apply_max_health_upgrade(health_bonus: int) -> void:
	if health_bonus <= 0:
		return

	max_health += health_bonus
	current_health = mini(
		current_health + health_bonus,
		max_health
	)

	update_debug_ui()
	_emit_health_changed(health_bonus, "heal")

	print(
		"[Player Upgrade] Maximum Health increased by ",
		health_bonus,
		". New maximum: ",
		max_health
	)


func apply_move_speed_upgrade(speed_bonus: float) -> void:
	if speed_bonus <= 0.0:
		return

	move_speed += speed_bonus

	print(
		"[Player Upgrade] Movement Speed increased by ",
		speed_bonus,
		". New speed: ",
		move_speed
	)


func apply_damage_taken_multiplier(multiplier: float) -> void:
	if multiplier <= 0.0:
		return

	damage_taken_multiplier = clampf(
		damage_taken_multiplier * multiplier,
		0.10,
		1.0
	)

	print(
		"[Player Upgrade] Damage taken multiplier is now ",
		damage_taken_multiplier
	)


func get_damage_reduction_percent() -> int:
	return int(
		round(
			(1.0 - damage_taken_multiplier) * 100.0
		)
	)


func is_gameplay_input_blocked() -> bool:
	var main_node: Node = get_tree().get_first_node_in_group(
		"main"
	)

	if main_node == null:
		return false

	if main_node.has_method("is_gameplay_input_blocked"):
		return bool(
			main_node.call("is_gameplay_input_blocked")
		)

	return false


func is_crop_planting_menu_open() -> bool:
	var crop_manager: Node = get_tree().get_first_node_in_group(
		"crop_manager"
	)

	if crop_manager == null:
		return false

	if crop_manager.has_method("is_planting_menu_open"):
		return bool(
			crop_manager.call("is_planting_menu_open")
		)

	return false


func handle_mouse_aim() -> void:
	var mouse_world_position: Vector2 = (
		get_global_mouse_position()
	)

	var aim_vector: Vector2 = (
		mouse_world_position - global_position
	)

	if aim_vector.length() < aim_deadzone_distance:
		return

	facing_direction = aim_vector.normalized()

	if pistol != null:
		pistol.rotation = facing_direction.angle()


func _physics_process(_delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO

		if hoe_collision != null:
			hoe_collision.disabled = true

		return

	if (
		is_gameplay_input_blocked()
		or is_crop_planting_menu_open()
	):
		velocity = Vector2.ZERO

		if hoe_collision != null:
			hoe_collision.disabled = true

		update_body_animation()
		return

	handle_mouse_aim()
	handle_movement()
	update_body_animation()
	handle_combat_input()

func is_pistol_reloading() -> bool:
	if pistol == null:
		return false

	if pistol.has_method("is_reload_in_progress"):
		return bool(pistol.call("is_reload_in_progress"))

	return false

func handle_movement() -> void:
	if is_pistol_reloading():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var input_direction: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	velocity = input_direction * move_speed
	move_and_slide()


# ---------------------------------------------------------
# ANIMATION DIRECTION
# ---------------------------------------------------------

func get_direction_suffix() -> String:
	if absf(facing_direction.x) > absf(facing_direction.y):
		return "side"

	if facing_direction.y > 0.0:
		return "front"

	return "back"


func get_directional_animation_name(
	animation_prefix: String
) -> StringName:
	return StringName(
		animation_prefix
		+ "_"
		+ get_direction_suffix()
	)


func update_sprite_flip() -> void:
	if body_sprite == null:
		return

	if get_direction_suffix() == "side":
		# The source side frames face right.
		body_sprite.flip_h = facing_direction.x < 0.0
	else:
		body_sprite.flip_h = false


# ---------------------------------------------------------
# IDLE AND WALKING ANIMATIONS
# ---------------------------------------------------------

func update_body_animation() -> void:
	if body_sprite == null:
		return

	# Do not allow movement animations to replace an attack,
	# shooting or reload animation before it finishes.
	if is_action_animation_playing:
		return

	var is_moving: bool = (
		velocity.length_squared() > 1.0
	)

	var animation_prefix: String = (
		"walk" if is_moving else "idle"
	)

	var animation_name: StringName = (
		get_directional_animation_name(
			animation_prefix
		)
	)

	if not body_sprite.sprite_frames.has_animation(
		animation_name
	):
		print(
			"[Player Animation] Missing animation: ",
			animation_name
		)
		return

	update_sprite_flip()

	if is_moving:
		if body_sprite.animation != animation_name:
			body_sprite.play(animation_name)
		elif not body_sprite.is_playing():
			body_sprite.play()

	else:
		if body_sprite.animation != animation_name:
			body_sprite.animation = animation_name

		body_sprite.stop()
		body_sprite.frame = 0
		body_sprite.frame_progress = 0.0


# ---------------------------------------------------------
# COMBAT ACTION ANIMATIONS
# ---------------------------------------------------------

func play_directional_action_animation(
	animation_prefix: String,
	custom_speed: float = 1.0
) -> bool:
	if body_sprite == null:
		print("[Player Animation] BodySprite is missing.")
		return false

	var animation_name: StringName = (
		get_directional_animation_name(
			animation_prefix
		)
	)

	if not body_sprite.sprite_frames.has_animation(
		animation_name
	):
		print(
			"[Player Animation] Missing animation: ",
			animation_name
		)
		return false

	is_action_animation_playing = true
	update_sprite_flip()

	# Force the action to restart from frame zero.
	body_sprite.stop()
	body_sprite.speed_scale = 1.0
	body_sprite.animation = animation_name
	body_sprite.frame = 0
	body_sprite.frame_progress = 0.0
	body_sprite.play(animation_name, custom_speed)

	print(
		"[Player Animation] Playing: ",
		animation_name
	)

	return true


func _on_body_animation_finished() -> void:
	if not is_action_animation_playing:
		return

	is_action_animation_playing = false
	update_body_animation()
	
func play_interaction_pose(
	pose_duration: float = 0.30
) -> void:
	if is_dead:
		return

	if body_sprite == null:
		print("[Player Animation] BodySprite is missing.")
		return

	if is_action_animation_playing:
		return

	var animation_name: StringName = &"interact_side"

	if not body_sprite.sprite_frames.has_animation(
		animation_name
	):
		print(
			"[Player Animation] Missing animation: ",
			animation_name
		)
		return

	is_action_animation_playing = true
	velocity = Vector2.ZERO

	# interact_side faces right by default.
	body_sprite.flip_h = facing_direction.x < 0.0

	body_sprite.stop()
	body_sprite.speed_scale = 1.0
	body_sprite.animation = animation_name
	body_sprite.frame = 0
	body_sprite.frame_progress = 0.0

	print("[Player Animation] Playing: interact_side")

	await get_tree().create_timer(pose_duration, false).timeout

	if is_dead:
		return

	# Do not interrupt a different animation that started afterward.
	if body_sprite.animation != animation_name:
		return

	is_action_animation_playing = false
	update_body_animation()


func get_reload_animation_speed() -> float:
	if body_sprite == null or pistol == null:
		return 1.0

	var animation_name: StringName = (
		get_directional_animation_name("reload")
	)

	if not body_sprite.sprite_frames.has_animation(
		animation_name
	):
		return 1.0

	var frame_count: int = (
		body_sprite.sprite_frames.get_frame_count(
			animation_name
		)
	)

	var animation_fps: float = (
		body_sprite.sprite_frames.get_animation_speed(
			animation_name
		)
	)

	if frame_count <= 0 or animation_fps <= 0.0:
		return 1.0

	var normal_animation_duration: float = (
		float(frame_count) / animation_fps
	)

	var actual_reload_duration: float = maxf(
		float(pistol.get_reload_time()),
		0.01
	)

	# Playback duration is divided by the custom speed.
	return (
		normal_animation_duration
		/ actual_reload_duration
	)


# ---------------------------------------------------------
# COMBAT INPUT
# ---------------------------------------------------------

func is_crop_click_being_captured() -> bool:
	var crop_manager: Node = get_tree().get_first_node_in_group(
		"crop_manager"
	)

	if crop_manager == null:
		return false

	if crop_manager.has_method("is_capturing_crop_click"):
		return bool(
			crop_manager.call("is_capturing_crop_click")
		)

	return false


func is_pointer_over_ui_control() -> bool:
	var hovered_control: Control = (
		get_viewport().gui_get_hovered_control()
	)

	return hovered_control != null


func handle_combat_input() -> void:
	if is_crop_click_being_captured():
		return

	# Do not start another combat action while one is playing.
	if is_action_animation_playing:
		return

	if Input.is_action_just_pressed("reload"):
		reload_pistol()
		return

	if Input.is_action_just_pressed("shoot"):
		if is_pointer_over_ui_control():
			return

		fire_pistol()
		return

	if Input.is_action_just_pressed("melee_attack"):
		if is_pointer_over_ui_control():
			return

		use_hoe_swing()


func fire_pistol() -> void:
	if pistol == null:
		print("Pistol node is missing from Player.tscn.")
		return

	var fired_successfully: bool = bool(
		pistol.fire(facing_direction)
	)

	if not fired_successfully:
		return

	play_directional_action_animation("shoot")


func reload_pistol() -> void:
	if pistol == null:
		return

	var reload_started_successfully: bool = bool(
		pistol.start_reload()
	)

	if not reload_started_successfully:
		return

	velocity = Vector2.ZERO

	var reload_animation_speed: float = (
		get_reload_animation_speed()
	)

	play_directional_action_animation(
		"reload",
		reload_animation_speed
	)


func use_hoe_swing() -> void:
	print("Hoe swing pressed")

	if not can_melee_attack:
		return

	melee_action_serial += 1
	var current_melee_serial: int = melee_action_serial

	can_melee_attack = false

	var animation_started: bool = (
		play_directional_action_animation(
			"hoe_attack"
		)
	)

	if not animation_started:
		if current_melee_serial == melee_action_serial:
			can_melee_attack = true
		return

	hoe_hitbox.position = facing_direction * 34.0
	hoe_hitbox.rotation = facing_direction.angle()

	# Frame 0: wind-up.
	await get_tree().create_timer(0.08, false).timeout

	if current_melee_serial != melee_action_serial:
		return

	if is_dead:
		return

	# Frame 1: active damage frame.
	hoe_collision.disabled = false

	await get_tree().create_timer(0.12, false).timeout

	if current_melee_serial != melee_action_serial:
		return

	hoe_collision.disabled = true

	# Frame 2: follow-through.
	await get_tree().create_timer(0.10, false).timeout

	if current_melee_serial != melee_action_serial:
		return

	can_melee_attack = true


func cancel_transient_actions_for_transition() -> void:
	# Player persists while map scenes are swapped. Invalidate delayed melee work
	# and stop reload/cooldown state so an action begun in one map cannot resume
	# after the player has already arrived in another.
	melee_action_serial += 1
	can_melee_attack = true
	is_action_animation_playing = false
	velocity = Vector2.ZERO

	if hoe_collision != null:
		hoe_collision.disabled = true

	if pistol != null and pistol.has_method("cancel_transient_actions"):
		pistol.call("cancel_transient_actions")

	update_body_animation()


# ---------------------------------------------------------
# HEALTH
# ---------------------------------------------------------

func take_damage(amount: int) -> void:
	if is_dead:
		print(
			"[Death Debug] Player is already dead. ",
			"Ignoring damage."
		)
		return

	var final_damage: int = maxi(
		1,
		roundi(
			float(amount)
			* damage_taken_multiplier
		)
	)

	current_health -= final_damage
	current_health = max(current_health, 0)

	print(
		"Player took damage: ",
		final_damage,
		" | Incoming: ",
		amount,
		" | HP: ",
		current_health
	)

	update_debug_ui()
	_emit_health_changed(
		-final_damage,
		"damage"
	)
	
	if current_health > 0:
		play_hurt_feedback()

	if current_health <= 0:
		print(
			"[Death Debug] HP reached 0. Calling die()."
		)
		die()
		
func play_hurt_feedback() -> void:
	if body_sprite == null:
		return

	if is_dead:
		return

	hurt_feedback_serial += 1
	var current_serial: int = hurt_feedback_serial

	body_sprite.self_modulate = Color(
		1.0,
		0.30,
		0.30,
		1.0
	)

	var shake_offsets: Array[Vector2] = [
		Vector2(-2.0, 0.0),
		Vector2(2.0, 0.0),
		Vector2(-1.5, 0.0),
		Vector2(1.5, 0.0),
		Vector2.ZERO
	]

	for shake_offset: Vector2 in shake_offsets:
		if current_serial != hurt_feedback_serial:
			return

		if is_dead:
			return

		body_sprite.position = (
			body_sprite_rest_position
			+ shake_offset
		)

		await get_tree().create_timer(0.035, false).timeout

	if current_serial != hurt_feedback_serial:
		return

	reset_hurt_feedback()


func reset_hurt_feedback() -> void:
	if body_sprite == null:
		return

	body_sprite.position = body_sprite_rest_position
	body_sprite.self_modulate = Color.WHITE


func update_debug_ui() -> void:
	# The old PlayerDebugUI label is intentionally hidden.
	# HUD.gd handles the real player health display.
	if health_label != null:
		health_label.visible = false
		health_label.text = ""


func get_current_health() -> int:
	return current_health


func get_max_health() -> int:
	return max_health


func _emit_health_changed(
	change_amount: int = 0,
	change_type: String = "set"
) -> void:
	health_changed.emit(
		current_health,
		max_health,
		change_amount,
		change_type
	)


# ---------------------------------------------------------
# INVENTORY AND RESOURCES
# ---------------------------------------------------------

func get_inventory_manager() -> InventoryManager:
	return get_tree().get_first_node_in_group(
		"inventory_manager"
	) as InventoryManager


func get_resource_amount(resource_type: String) -> int:
	var inventory_manager: InventoryManager = (
		get_inventory_manager()
	)

	if inventory_manager == null:
		return 0

	return inventory_manager.get_item_amount(
		resource_type
	)


func has_resource(
	resource_type: String,
	amount: int
) -> bool:
	if amount <= 0:
		return true

	var inventory_manager: InventoryManager = (
		get_inventory_manager()
	)

	if inventory_manager == null:
		return false

	return inventory_manager.has_item(
		resource_type,
		amount
	)


func spend_resource(
	resource_type: String,
	amount: int
) -> bool:
	if amount <= 0:
		return true

	var available_amount: int = (
		get_resource_amount(resource_type)
	)

	if available_amount < amount:
		print(
			"[Resources] Cannot spend ",
			amount,
			" ",
			resource_type,
			". Available: ",
			available_amount
		)

		return false

	var inventory_manager: InventoryManager = (
		get_inventory_manager()
	)

	if inventory_manager == null:
		return false

	var spent_successfully: bool = (
		inventory_manager.spend_item(
			resource_type,
			amount
		)
	)

	if not spent_successfully:
		return false

	print(
		"[Resources] Spent ",
		amount,
		" ",
		resource_type,
		" | Seeds: ",
		get_resource_amount("seeds"),
		" Scrap: ",
		get_resource_amount("scrap"),
		" Mutant Seeds: ",
		get_resource_amount("mutant_seeds")
	)

	return true


func can_accept_resource(
	resource_type: String,
	amount: int
) -> bool:
	if amount <= 0:
		return true

	var inventory_manager: InventoryManager = (
		get_inventory_manager()
	)

	if inventory_manager == null:
		return false

	return inventory_manager.can_add_item(resource_type, amount)


func add_resource(
	resource_type: String,
	amount: int
) -> int:
	if amount <= 0:
		return 0

	var inventory_manager: InventoryManager = (
		get_inventory_manager()
	)

	if inventory_manager == null:
		print("[Resources] InventoryManager is missing.")
		return amount

	var remaining_amount: int = (
		inventory_manager.add_item(
			resource_type,
			amount
		)
	)

	var added_amount: int = (
		amount - remaining_amount
	)

	if added_amount > 0:
		print(
			"[Resources] Added ",
			added_amount,
			" ",
			resource_type,
			" | Seeds: ",
			get_resource_amount("seeds"),
			" Scrap: ",
			get_resource_amount("scrap"),
			" Mutant Seeds: ",
			get_resource_amount("mutant_seeds")
		)

	if remaining_amount > 0:
		print(
			"[Resources] Inventory full. Could not collect ",
			remaining_amount,
			" ",
			resource_type
		)

	return remaining_amount


# ---------------------------------------------------------
# DEATH
# ---------------------------------------------------------

func die() -> void:
	if is_dead:
		print(
			"[Death Debug] die() was called, ",
			"but player is already dead."
		)
		return

	is_dead = true
	death_sequence_serial += 1
	var current_death_serial: int = death_sequence_serial
	velocity = Vector2.ZERO
	is_action_animation_playing = false
	can_melee_attack = false
	melee_action_serial += 1
	hurt_feedback_serial += 1
	reset_hurt_feedback()

	if hoe_collision != null:
		hoe_collision.disabled = true

	print("[Death Debug] Player died.")

	await play_directional_death_animation()

	# The Player node persists across Load/New Game. If either happens while
	# this death animation is waiting, a later animation_finished signal must
	# not allow the old death coroutine to open Game Over in the new state.
	if current_death_serial != death_sequence_serial:
		return

	if not is_dead:
		return

	show_game_over_after_death()
	
func play_directional_death_animation() -> void:
	if body_sprite == null:
		print(
			"[Player Animation] BodySprite is missing. ",
			"Skipping death animation."
		)
		return

	var death_animation_name: StringName = (
		get_directional_animation_name("death")
	)

	if not body_sprite.sprite_frames.has_animation(
		death_animation_name
	):
		print(
			"[Player Animation] Missing death animation: ",
			death_animation_name
		)
		return

	update_sprite_flip()

	body_sprite.stop()
	body_sprite.speed_scale = 1.0
	body_sprite.animation = death_animation_name
	body_sprite.frame = 0
	body_sprite.frame_progress = 0.0
	body_sprite.play(death_animation_name)

	print(
		"[Player Animation] Playing: ",
		death_animation_name
	)

	await body_sprite.animation_finished
	
func show_game_over_after_death() -> void:
	print(
		"[Death Debug] Death animation finished. ",
		"Looking for Main node."
	)

	var main_node: Node = get_tree().get_first_node_in_group(
		"main"
	)

	if main_node == null:
		print(
			"[Death Debug] Main node was NOT found ",
			"in group 'main'."
		)
		return

	print(
		"[Death Debug] Main node found: ",
		main_node.name
	)

	if not main_node.has_method("handle_player_death"):
		print(
			"[Death Debug] Main does NOT have ",
			"handle_player_death()."
		)
		return

	print(
		"[Death Debug] Calling ",
		"Main.handle_player_death()."
	)

	main_node.call("handle_player_death")


# ---------------------------------------------------------
# SAVE AND LOAD
# ---------------------------------------------------------

func get_save_data() -> Dictionary:
	var save_data: Dictionary = {
		"position_x": global_position.x,
		"position_y": global_position.y,
		"current_health": current_health,
		"max_health": max_health,
		"move_speed": move_speed,
		"damage_taken_multiplier":
			damage_taken_multiplier,
		"facing_direction_x":
			facing_direction.x,
		"facing_direction_y":
			facing_direction.y,
		"is_dead": is_dead
	}

	if pistol != null and pistol.has_method("get_save_data"):
		save_data["pistol"] = pistol.call("get_save_data")

	return save_data


func load_save_data(data: Dictionary) -> void:
	max_health = maxi(
		1,
		int(data.get("max_health", base_max_health))
	)

	move_speed = maxf(
		1.0,
		float(data.get("move_speed", base_move_speed))
	)

	damage_taken_multiplier = maxf(
		0.0,
		float(
			data.get(
				"damage_taken_multiplier",
				base_damage_taken_multiplier
			)
		)
	)

	current_health = int(
		data.get(
			"current_health",
			max_health
		)
	)

	current_health = clampi(
		current_health,
		0,
		max_health
	)

	global_position = Vector2(
		float(
			data.get(
				"position_x",
				global_position.x
			)
		),
		float(
			data.get(
				"position_y",
				global_position.y
			)
		)
	)

	facing_direction = Vector2(
		float(
			data.get(
				"facing_direction_x",
				1.0
			)
		),
		float(
			data.get(
				"facing_direction_y",
				0.0
			)
		)
	)

	if facing_direction.length() <= 0.01:
		facing_direction = Vector2.RIGHT
	else:
		facing_direction = (
			facing_direction.normalized()
		)

	death_sequence_serial += 1
	is_dead = false
	melee_action_serial += 1
	can_melee_attack = true
	is_action_animation_playing = false
	velocity = Vector2.ZERO

	if hoe_collision != null:
		hoe_collision.disabled = true

	if pistol != null:
		pistol.rotation = facing_direction.angle()

		var pistol_save_data: Dictionary = data.get("pistol", {})

		if not pistol_save_data.is_empty() and pistol.has_method("load_save_data"):
			pistol.call("load_save_data", pistol_save_data)
		elif pistol.has_method("reset_weapon"):
			pistol.call("reset_weapon")
	
	hurt_feedback_serial += 1
	reset_hurt_feedback()

	update_debug_ui()
	update_body_animation()
	_emit_health_changed(0, "set")


func reset_for_new_game() -> void:
	max_health = base_max_health
	move_speed = base_move_speed
	damage_taken_multiplier = (
		base_damage_taken_multiplier
	)

	current_health = max_health
	facing_direction = Vector2.RIGHT
	death_sequence_serial += 1
	melee_action_serial += 1
	can_melee_attack = true
	is_dead = false
	is_action_animation_playing = false
	velocity = Vector2.ZERO

	if hoe_collision != null:
		hoe_collision.disabled = true

	if pistol != null:
		pistol.rotation = facing_direction.angle()
		pistol.reset_weapon()
		
	hurt_feedback_serial += 1
	reset_hurt_feedback()

	update_debug_ui()
	update_body_animation()
	_emit_health_changed(0, "set")
