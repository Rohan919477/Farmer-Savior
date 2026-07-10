extends CharacterBody2D

@export var move_speed: float = 220.0
@export var max_health: int = 100
@export var damage_taken_multiplier: float = 1.0
@export var aim_deadzone_distance: float = 8.0

var current_health: int
var facing_direction: Vector2 = Vector2.RIGHT
var can_melee_attack: bool = true
var is_dead: bool = false

@onready var hoe_hitbox: Area2D = $HoeHitbox
@onready var hoe_collision: CollisionShape2D = $HoeHitbox/CollisionShape2D
@onready var health_label: Label = $PlayerDebugUI/HealthLabel
@onready var pistol: Pistol = $Pistol

func _ready() -> void:
	add_to_group("player")
	
	current_health = max_health
	hoe_collision.disabled = true
	update_debug_ui()
	
func apply_max_health_upgrade(health_bonus: int) -> void:
	if health_bonus <= 0:
		return

	max_health += health_bonus
	current_health = mini(current_health + health_bonus, max_health)

	update_debug_ui()

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
	return int(round((1.0 - damage_taken_multiplier) * 100.0))

func is_gameplay_input_blocked() -> bool:
	var main_node: Node = get_tree().get_first_node_in_group("main")

	if main_node == null:
		return false

	if main_node.has_method("is_gameplay_input_blocked"):
		return bool(main_node.call("is_gameplay_input_blocked"))

	return false
	
func is_crop_planting_menu_open() -> bool:
	var crop_manager: Node = get_tree().get_first_node_in_group(
		"crop_manager"
	)

	if crop_manager == null:
		return false

	if crop_manager.has_method("is_planting_menu_open"):
		return bool(crop_manager.call("is_planting_menu_open"))

	return false

func handle_mouse_aim() -> void:
	var mouse_world_position: Vector2 = get_global_mouse_position()

	var aim_vector: Vector2 = (
		mouse_world_position - global_position
	)

	if aim_vector.length() < aim_deadzone_distance:
		return

	facing_direction = aim_vector.normalized()
	
	if pistol != null:
		pistol.rotation = facing_direction.angle()

func _physics_process(_delta: float) -> void:
	if is_gameplay_input_blocked() or is_crop_planting_menu_open():
		velocity = Vector2.ZERO
		hoe_collision.disabled = true
		return

	handle_mouse_aim()
	handle_movement()
	handle_combat_input()

func handle_movement() -> void:
	var input_direction: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down",
	)

	velocity = input_direction * move_speed
	move_and_slide()
	
func is_crop_click_being_captured() -> bool:
	var crop_manager: Node = get_tree().get_first_node_in_group(
		"crop_manager"
	)

	if crop_manager == null:
		return false

	if crop_manager.has_method("is_capturing_crop_click"):
		return bool(crop_manager.call("is_capturing_crop_click"))

	return false

func handle_combat_input() -> void:
	if is_crop_click_being_captured():
		return
	
	if Input.is_action_just_pressed("shoot"):
		fire_pistol()

	if Input.is_action_just_pressed("melee_attack"):
		use_hoe_swing()

func fire_pistol() -> void:
	if pistol == null:
		print("Pistol node is missing from Player.tscn.")
		return

	pistol.fire(facing_direction)

func use_hoe_swing() -> void:
	print("Hoe swing pressed")

	if not can_melee_attack:
		return

	can_melee_attack = false

	hoe_hitbox.position = facing_direction * 34.0
	hoe_hitbox.rotation = facing_direction.angle()

	hoe_collision.disabled = false

	await get_tree().create_timer(0.12).timeout
	hoe_collision.disabled = true

	await get_tree().create_timer(0.25).timeout
	can_melee_attack = true

func take_damage(amount: int) -> void:
	if is_dead:
		print("[Death Debug] Player is already dead. Ignoring damage.")
		return

	var final_damage: int = maxi(
		1,
		roundi(float(amount) * damage_taken_multiplier)
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

	if current_health <= 0:
		print("[Death Debug] HP reached 0. Calling die().")
		die()

func update_debug_ui() -> void:
	if health_label != null:
		health_label.text = "HP: %s / %s" % [current_health, max_health]

func get_inventory_manager() -> InventoryManager:
	return get_tree().get_first_node_in_group(
		"inventory_manager"
	) as InventoryManager

func get_resource_amount(resource_type: String) -> int:
	var inventory_manager: InventoryManager = get_inventory_manager()

	if inventory_manager == null:
		return 0

	return inventory_manager.get_item_amount(resource_type)

func has_resource(resource_type: String, amount: int) -> bool:
	if amount <= 0:
		return true

	var inventory_manager: InventoryManager = get_inventory_manager()

	if inventory_manager == null:
		return false

	return inventory_manager.has_item(resource_type, amount)

func spend_resource(resource_type: String, amount: int) -> bool:
	if amount <= 0:
		return true

	var available_amount: int = get_resource_amount(resource_type)

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

	var inventory_manager: InventoryManager = get_inventory_manager()

	if inventory_manager == null:
		return false

	var spent_successfully: bool = inventory_manager.spend_item(
		resource_type,
		amount
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

func add_resource(resource_type: String, amount: int) -> void:
	if amount <= 0:
		return

	var inventory_manager: InventoryManager = get_inventory_manager()

	if inventory_manager == null:
		print("[Resources] InventoryManager is missing.")
		return

	var remaining_amount: int = inventory_manager.add_item(
		resource_type,
		amount
	)

	var added_amount: int = amount - remaining_amount

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

func die() -> void:
	if is_dead:
		print("[Death Debug] die() was called, but player is already dead.")
		return

	is_dead = true

	velocity = Vector2.ZERO

	if hoe_collision != null:
		hoe_collision.disabled = true

	print("[Death Debug] Player died. Looking for Main node.")

	var main_node: Node = get_tree().get_first_node_in_group("main")

	if main_node == null:
		print("[Death Debug] Main node was NOT found in group 'main'.")
		return

	print("[Death Debug] Main node found: ", main_node.name)

	if not main_node.has_method("handle_player_death"):
		print("[Death Debug] Main does NOT have handle_player_death().")
		return

	print("[Death Debug] Calling Main.handle_player_death().")
	main_node.call("handle_player_death")
