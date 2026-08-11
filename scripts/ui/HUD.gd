extends CanvasLayer

@onready var time_label: Label = $TimeLabel
@onready var night_warning_label: Label = $NightWarningLabel
@onready var fade_overlay: ColorRect = $FadeOverlay

@onready var enemy_count_label: Label = (
	get_node_or_null("EnemyCountLabel") as Label
)

@onready var tutorial_objective_label: Label = (
	get_node_or_null("TutorialObjectiveLabel") as Label
)

@onready var weapon_ammo_hud: Control = (
	get_node_or_null("WeaponAmmoHud") as Control
)

@onready var weapon_panel_texture: TextureRect = (
	get_node_or_null("WeaponAmmoHud/PanelTexture") as TextureRect
)

@onready var pistol_icon: TextureRect = (
	get_node_or_null("WeaponAmmoHud/PistolIcon") as TextureRect
)

@onready var ammo_label: Label = (
	get_node_or_null("WeaponAmmoHud/AmmoLabel") as Label
)

@onready var reserve_ammo_label: Label = (
	get_node_or_null("WeaponAmmoHud/ReserveAmmoLabel") as Label
)

var warning_tween: Tween
var fade_tween: Tween
var tutorial_feedback_tween: Tween
var health_drain_tween: Tween
var health_feedback_tween: Tween

var health_root: Control = null
var health_panel: ColorRect = null
var health_title_label: Label = null
var health_value_label: Label = null
var health_frame: ColorRect = null
var health_background: ColorRect = null
var delayed_damage_bar: ColorRect = null
var current_health_bar: ColorRect = null
var health_grime_overlay: ColorRect = null
var health_flash: ColorRect = null
var health_current: int = 100
var health_maximum: int = 100
var health_delayed: float = 100.0
var health_bar_inner_width: float = 252.0
var health_bar_inner_height: float = 12.0
var health_base_position: Vector2 = Vector2.ZERO
var horror_ui_font: Font = null
var weapon_hud_size: Vector2 = Vector2(438.0, 90.0)
var current_weapon_ammo: int = 6
var current_weapon_magazine_size: int = 6
var current_weapon_reserve_ammo: int = 200

func _ready() -> void:
	horror_ui_font = _create_horror_ui_font()
	_apply_time_display_style()
	_build_health_hud()
	_setup_weapon_ammo_hud()

	fade_overlay.visible = false
	fade_overlay.modulate = Color(1, 1, 1, 0)

	if enemy_count_label != null:
		enemy_count_label.visible = false
		enemy_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		enemy_count_label.add_theme_font_size_override(
			"font_size",
			19
		)
		enemy_count_label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.82, 0.45, 1.0)
		)

	if tutorial_objective_label != null:
		tutorial_objective_label.visible = false
		tutorial_objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tutorial_objective_label.add_theme_font_size_override(
			"font_size",
			20
		)

		tutorial_objective_label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.92, 0.45, 1.0)
		)

		tutorial_objective_label.add_theme_color_override(
			"font_outline_color",
			Color(0.02, 0.0, 0.0, 1.0)
		)

		tutorial_objective_label.add_theme_constant_override(
			"outline_size",
			4
		)

	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()

	call_deferred("_connect_player_health")
	call_deferred("_connect_weapon_ammo_hud_to_player")

func _on_viewport_size_changed() -> void:
	_resize_fade_overlay()
	_layout_time_display()
	_layout_enemy_count()
	_layout_tutorial_objective()
	_layout_health_hud()
	_layout_weapon_ammo_hud()

func _resize_fade_overlay() -> void:
	fade_overlay.position = Vector2.ZERO
	fade_overlay.size = get_viewport().get_visible_rect().size

func _create_horror_ui_font() -> Font:
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray([
		"Segoe Script",
		"Brush Script MT",
		"Lucida Handwriting",
		"Georgia"
	])
	return font

func _apply_time_display_style() -> void:
	if time_label == null:
		return

	if horror_ui_font != null:
		time_label.add_theme_font_override("font", horror_ui_font)

	time_label.add_theme_font_size_override("font_size", 18)
	time_label.add_theme_color_override(
		"font_color",
		Color(0.34, 0.015, 0.010, 1.0)
	)
	time_label.add_theme_color_override(
		"font_outline_color",
		Color(0.015, 0.0, 0.0, 1.0)
	)
	time_label.add_theme_constant_override("outline_size", 2)
	time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _layout_time_display() -> void:
	if time_label == null:
		return

	time_label.position = Vector2(16.0, 4.0)
	time_label.size = Vector2(420.0, 28.0)

func _layout_enemy_count() -> void:
	if enemy_count_label == null:
		return

	var viewport_size: Vector2 = (
		get_viewport().get_visible_rect().size
	)

	enemy_count_label.position = Vector2(18.0, 14.0)
	enemy_count_label.size = Vector2(
		viewport_size.x - 36.0,
		34.0
	)

func _layout_tutorial_objective() -> void:
	if tutorial_objective_label == null:
		return

	var viewport_size: Vector2 = (
		get_viewport().get_visible_rect().size
	)

	tutorial_objective_label.position = Vector2(18.0, 94.0)
	tutorial_objective_label.size = Vector2(
		viewport_size.x - 36.0,
		52.0
	)
	tutorial_objective_label.z_index = 100

func _build_health_hud() -> void:
	health_root = Control.new()
	health_root.name = "HealthHUD"
	health_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_root.z_index = 20
	add_child(health_root)

	health_panel = ColorRect.new()
	health_panel.name = "HealthPanel"
	health_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_panel.color = Color(0.0, 0.0, 0.0, 0.0)
	health_root.add_child(health_panel)

	health_title_label = Label.new()
	health_title_label.name = "HealthTitleLabel"
	health_title_label.text = "HP"
	health_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if horror_ui_font != null:
		health_title_label.add_theme_font_override("font", horror_ui_font)
	health_title_label.add_theme_font_size_override("font_size", 17)
	health_title_label.add_theme_color_override(
		"font_color",
		Color(0.38, 0.015, 0.010, 1.0)
	)
	health_title_label.add_theme_color_override(
		"font_outline_color",
		Color(0.015, 0.0, 0.0, 1.0)
	)
	health_title_label.add_theme_constant_override("outline_size", 2)
	health_root.add_child(health_title_label)

	health_value_label = Label.new()
	health_value_label.name = "HealthValueLabel"
	health_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	health_value_label.add_theme_font_size_override("font_size", 13)
	health_value_label.add_theme_color_override(
		"font_color",
		Color(0.77, 0.67, 0.52, 1.0)
	)
	health_value_label.add_theme_color_override(
		"font_outline_color",
		Color(0.02, 0.0, 0.0, 1.0)
	)
	health_value_label.add_theme_constant_override("outline_size", 1)
	health_root.add_child(health_value_label)

	health_frame = ColorRect.new()
	health_frame.name = "HealthFrame"
	health_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_frame.color = Color(0.025, 0.010, 0.008, 1.0)
	health_root.add_child(health_frame)

	health_background = ColorRect.new()
	health_background.name = "HealthBackground"
	health_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_background.color = Color(0.010, 0.008, 0.007, 1.0)
	health_root.add_child(health_background)

	delayed_damage_bar = ColorRect.new()
	delayed_damage_bar.name = "DelayedDamageBar"
	delayed_damage_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	delayed_damage_bar.color = Color(0.28, 0.055, 0.035, 0.92)
	health_root.add_child(delayed_damage_bar)

	current_health_bar = ColorRect.new()
	current_health_bar.name = "CurrentHealthBar"
	current_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_root.add_child(current_health_bar)

	health_grime_overlay = ColorRect.new()
	health_grime_overlay.name = "HealthGrimeOverlay"
	health_grime_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_grime_overlay.color = Color(0.08, 0.0, 0.0, 0.0)
	health_root.add_child(health_grime_overlay)

	health_flash = ColorRect.new()
	health_flash.name = "HealthFlash"
	health_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_flash.color = Color(0.40, 0.015, 0.010, 0.0)
	health_flash.visible = false
	health_root.add_child(health_flash)

	_refresh_health_visuals()

func _layout_health_hud() -> void:
	if health_root == null:
		return

	# Lowered so it does not overlap the day/time label.
	health_base_position = Vector2(16.0, 38.0)
	health_root.position = health_base_position
	health_root.size = Vector2(282.0, 42.0)
	health_root.pivot_offset = Vector2.ZERO
	health_root.scale = Vector2.ONE

	if health_panel != null:
		health_panel.position = Vector2.ZERO
		health_panel.size = Vector2.ZERO
		health_panel.color = Color(0.0, 0.0, 0.0, 0.0)

	if health_title_label != null:
		health_title_label.position = Vector2(0.0, 0.0)
		health_title_label.size = Vector2(80.0, 18.0)

	if health_value_label != null:
		health_value_label.position = Vector2(134.0, 2.0)
		health_value_label.size = Vector2(124.0, 18.0)

	if health_frame != null:
		health_frame.position = Vector2(0.0, 22.0)
		health_frame.size = Vector2(260.0, 18.0)

	if health_background != null:
		health_background.position = Vector2(4.0, 26.0)
		health_background.size = Vector2(
			health_bar_inner_width,
			health_bar_inner_height
		)

	if delayed_damage_bar != null:
		delayed_damage_bar.position = Vector2(4.0, 26.0)
		delayed_damage_bar.size.y = health_bar_inner_height

	if current_health_bar != null:
		current_health_bar.position = Vector2(4.0, 26.0)
		current_health_bar.size.y = health_bar_inner_height

	if health_grime_overlay != null:
		health_grime_overlay.position = Vector2(4.0, 26.0)
		health_grime_overlay.size.y = health_bar_inner_height

	if health_flash != null:
		health_flash.position = Vector2(4.0, 26.0)
		health_flash.size = Vector2(
			health_bar_inner_width,
			health_bar_inner_height
		)

	_refresh_health_visuals()

func _setup_weapon_ammo_hud() -> void:
	if weapon_ammo_hud == null:
		return

	weapon_ammo_hud.visible = true
	weapon_ammo_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_ammo_hud.z_index = 50

	if weapon_panel_texture != null:
		weapon_panel_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		weapon_panel_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		weapon_panel_texture.stretch_mode = TextureRect.STRETCH_SCALE

	if pistol_icon != null:
		pistol_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pistol_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pistol_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	if ammo_label != null:
		ammo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ammo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ammo_label.add_theme_font_size_override("font_size", 30)
		ammo_label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.90, 0.62, 1.0)
		)
		ammo_label.add_theme_color_override(
			"font_outline_color",
			Color(0.015, 0.006, 0.002, 1.0)
		)
		ammo_label.add_theme_constant_override("outline_size", 5)

	if reserve_ammo_label != null:
		reserve_ammo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reserve_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reserve_ammo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		reserve_ammo_label.add_theme_font_size_override("font_size", 28)
		reserve_ammo_label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.90, 0.62, 1.0)
		)
		reserve_ammo_label.add_theme_color_override(
			"font_outline_color",
			Color(0.015, 0.006, 0.002, 1.0)
		)
		reserve_ammo_label.add_theme_constant_override("outline_size", 5)

	update_weapon_ammo(
		current_weapon_ammo,
		current_weapon_magazine_size,
		current_weapon_reserve_ammo
	)


func _layout_weapon_ammo_hud() -> void:
	if weapon_ammo_hud == null:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var bottom_right_padding: Vector2 = Vector2(14.0, 14.0)

	weapon_ammo_hud.position = Vector2(
		viewport_size.x - weapon_hud_size.x - bottom_right_padding.x,
		viewport_size.y - weapon_hud_size.y - bottom_right_padding.y
	)

	weapon_ammo_hud.size = weapon_hud_size
	weapon_ammo_hud.scale = Vector2.ONE
	weapon_ammo_hud.pivot_offset = Vector2.ZERO

	if weapon_panel_texture != null:
		weapon_panel_texture.position = Vector2.ZERO
		weapon_panel_texture.size = weapon_hud_size
		weapon_panel_texture.scale = Vector2.ONE

	if pistol_icon != null:
		pistol_icon.position = Vector2(20.0, 19.0)
		pistol_icon.size = Vector2(88.0, 52.0)
		pistol_icon.scale = Vector2.ONE

	if ammo_label != null:
		ammo_label.position = Vector2(112.0, 23.0)
		ammo_label.size = Vector2(205.0, 42.0)
		ammo_label.scale = Vector2.ONE

	if reserve_ammo_label != null:
		reserve_ammo_label.position = Vector2(334.0, 23.0)
		reserve_ammo_label.size = Vector2(84.0, 42.0)
		reserve_ammo_label.scale = Vector2.ONE

func _connect_weapon_ammo_hud_to_player() -> void:
	await get_tree().process_frame

	var player_node: Node = get_tree().get_first_node_in_group("player")

	if player_node == null:
		return

	var pistol_node: Node = player_node.get_node_or_null("Pistol")

	if pistol_node == null:
		return

	if pistol_node.has_signal("ammo_changed"):
		var ammo_callable: Callable = Callable(
			self,
			"_on_pistol_ammo_changed"
		)

		if not pistol_node.is_connected("ammo_changed", ammo_callable):
			pistol_node.connect("ammo_changed", ammo_callable)

	var current_ammo: int = current_weapon_ammo
	var magazine_size: int = current_weapon_magazine_size
	var reserve_ammo: int = current_weapon_reserve_ammo

	if pistol_node.has_method("get_current_ammo"):
		current_ammo = int(pistol_node.call("get_current_ammo"))

	if pistol_node.has_method("get_magazine_size"):
		magazine_size = int(pistol_node.call("get_magazine_size"))

	if pistol_node.has_method("get_reserve_ammo"):
		reserve_ammo = int(pistol_node.call("get_reserve_ammo"))
	elif pistol_node.has_method("get_pistol_reserve_ammo"):
		reserve_ammo = int(pistol_node.call("get_pistol_reserve_ammo"))

	update_weapon_ammo(
		current_ammo,
		magazine_size,
		reserve_ammo
	)


func _on_pistol_ammo_changed(
	current_ammo: int,
	magazine_size: int,
	reserve_ammo: int = 200
) -> void:
	update_weapon_ammo(
		current_ammo,
		magazine_size,
		reserve_ammo
	)


func update_weapon_ammo(
	current_ammo: int,
	magazine_size: int,
	reserve_ammo: int
) -> void:
	current_weapon_ammo = clampi(
		current_ammo,
		0,
		maxi(1, magazine_size)
	)

	current_weapon_magazine_size = maxi(
		1,
		magazine_size
	)

	current_weapon_reserve_ammo = maxi(
		0,
		reserve_ammo
	)

	if ammo_label != null:
		ammo_label.text = "%02d / %02d" % [
			current_weapon_ammo,
			current_weapon_magazine_size
		]

	if reserve_ammo_label != null:
		reserve_ammo_label.text = str(current_weapon_reserve_ammo) + "x"

func _connect_player_health() -> void:
	await get_tree().process_frame

	var player_node: Node = get_tree().get_first_node_in_group("player")

	if player_node == null:
		return

	if player_node.has_signal("health_changed"):
		var health_callable: Callable = Callable(
			self,
			"_on_player_health_changed"
		)

		if not player_node.is_connected(
			"health_changed",
			health_callable
		):
			player_node.connect("health_changed", health_callable)

	var current_value: int = health_current
	var maximum_value: int = health_maximum

	if player_node.has_method("get_current_health"):
		current_value = int(player_node.call("get_current_health"))
	elif "current_health" in player_node:
		current_value = int(player_node.get("current_health"))

	if player_node.has_method("get_max_health"):
		maximum_value = int(player_node.call("get_max_health"))
	elif "max_health" in player_node:
		maximum_value = int(player_node.get("max_health"))

	_on_player_health_changed(
		current_value,
		maximum_value,
		0,
		"set"
	)

func _on_player_health_changed(
	new_current_health: int,
	new_max_health: int,
	change_amount: int,
	change_type: String
) -> void:
	var old_current_health: int = health_current

	health_maximum = maxi(1, new_max_health)
	health_current = clampi(
		new_current_health,
		0,
		health_maximum
	)

	if change_type == "damage":
		var damage_amount: int = absi(change_amount)

		health_delayed = maxf(
			health_delayed,
			float(old_current_health)
		)

		_refresh_health_visuals()
		_start_delayed_damage_drain()
		_play_damage_feedback(damage_amount)
		return

	if change_type == "heal":
		health_delayed = float(health_current)
		_refresh_health_visuals()
		_play_heal_feedback(absi(change_amount))
		return

	health_delayed = float(health_current)
	_refresh_health_visuals()

func _start_delayed_damage_drain() -> void:
	if health_drain_tween != null:
		health_drain_tween.kill()

	health_drain_tween = create_tween()
	health_drain_tween.tween_interval(0.18)
	health_drain_tween.tween_method(
		Callable(self, "_set_delayed_health_value"),
		health_delayed,
		float(health_current),
		0.42
	)

func _set_delayed_health_value(new_value: float) -> void:
	health_delayed = new_value
	_refresh_health_visuals()

func _refresh_health_visuals() -> void:
	var current_ratio: float = clampf(
		float(health_current) / float(maxi(1, health_maximum)),
		0.0,
		1.0
	)

	var delayed_ratio: float = clampf(
		health_delayed / float(maxi(1, health_maximum)),
		0.0,
		1.0
	)

	if current_health_bar != null:
		current_health_bar.size = Vector2(
			health_bar_inner_width * current_ratio,
			health_bar_inner_height
		)
		current_health_bar.color = _get_health_colour(current_ratio)

	if delayed_damage_bar != null:
		delayed_damage_bar.size = Vector2(
			health_bar_inner_width * delayed_ratio,
			health_bar_inner_height
		)
		delayed_damage_bar.color = _get_delayed_damage_colour(current_ratio)

	if health_grime_overlay != null:
		health_grime_overlay.size = Vector2(
			health_bar_inner_width * current_ratio,
			health_bar_inner_height
		)
		health_grime_overlay.color = _get_grime_overlay_colour(
			current_ratio
		)

	if health_frame != null:
		health_frame.color = _get_frame_colour(current_ratio)

	if health_panel != null:
		health_panel.color = Color(0.0, 0.0, 0.0, 0.0)

	if health_value_label != null:
		health_value_label.text = "%d / %d" % [
			health_current,
			health_maximum
		]

	if health_title_label != null:
		if current_ratio <= 0.25:
			health_title_label.text = "HP - CRITICAL"
			health_title_label.add_theme_color_override(
				"font_color",
				Color(0.54, 0.020, 0.012, 1.0)
			)
		else:
			health_title_label.text = "HP"
			health_title_label.add_theme_color_override(
				"font_color",
				Color(0.38, 0.015, 0.010, 1.0)
			)

func _get_health_colour(health_ratio: float) -> Color:
	if health_ratio > 0.70:
		return Color(0.22, 0.38, 0.13, 1.0)

	if health_ratio > 0.45:
		var healthy_to_sick: float = inverse_lerp(0.45, 0.70, health_ratio)
		return Color(0.36, 0.24, 0.075, 1.0).lerp(
			Color(0.22, 0.38, 0.13, 1.0),
			healthy_to_sick
		)

	if health_ratio > 0.22:
		var sick_to_blood: float = inverse_lerp(0.22, 0.45, health_ratio)
		return Color(0.26, 0.040, 0.025, 1.0).lerp(
			Color(0.36, 0.24, 0.075, 1.0),
			sick_to_blood
		)

	var critical_t: float = clampf(health_ratio / 0.22, 0.0, 1.0)
	return Color(0.075, 0.003, 0.003, 1.0).lerp(
		Color(0.26, 0.040, 0.025, 1.0),
		critical_t
	)

func _get_delayed_damage_colour(health_ratio: float) -> Color:
	if health_ratio > 0.45:
		return Color(0.42, 0.10, 0.045, 0.86)

	return Color(0.24, 0.020, 0.014, 0.92)

func _get_grime_overlay_colour(health_ratio: float) -> Color:
	var grime_alpha: float = clampf(
		(0.85 - health_ratio) / 0.85,
		0.0,
		1.0
	)

	return Color(
		0.10,
		0.0,
		0.0,
		0.04 + grime_alpha * 0.46
	)

func _get_frame_colour(health_ratio: float) -> Color:
	if health_ratio > 0.65:
		return Color(0.028, 0.018, 0.013, 1.0)

	if health_ratio > 0.35:
		return Color(0.040, 0.016, 0.010, 1.0)

	return Color(0.018, 0.003, 0.003, 1.0)

func _play_damage_feedback(damage_amount: int) -> void:
	if health_root == null:
		return

	if health_feedback_tween != null:
		health_feedback_tween.kill()

	health_root.position = health_base_position
	health_root.scale = Vector2.ONE

	if health_flash != null:
		health_flash.visible = true
		health_flash.modulate = Color(1.0, 1.0, 1.0, 1.0)
		health_flash.color = Color(0.36, 0.010, 0.006, 0.42)

	health_feedback_tween = create_tween()
	health_feedback_tween.tween_property(
		health_root,
		"position",
		health_base_position + Vector2(-2.0, 0.0),
		0.035
	)
	health_feedback_tween.tween_property(
		health_root,
		"position",
		health_base_position + Vector2(2.0, 0.0),
		0.035
	)
	health_feedback_tween.tween_property(
		health_root,
		"position",
		health_base_position + Vector2(-1.0, 0.0),
		0.03
	)
	health_feedback_tween.tween_property(
		health_root,
		"position",
		health_base_position,
		0.04
	)

	if health_flash != null:
		health_feedback_tween.parallel().tween_property(
			health_flash,
			"modulate:a",
			0.0,
			0.18
		)
		health_feedback_tween.tween_callback(
			func() -> void:
				health_flash.visible = false
				health_flash.modulate = Color(1.0, 1.0, 1.0, 1.0)
		)

	_spawn_health_number("-" + str(damage_amount), false)

func _play_heal_feedback(heal_amount: int) -> void:
	if heal_amount <= 0:
		return

	if health_root == null:
		return

	health_root.position = health_base_position
	health_root.scale = Vector2.ONE

	_spawn_health_number("+" + str(heal_amount), true)

func _spawn_health_number(number_text: String, is_heal: bool) -> void:
	if health_root == null:
		return

	var number_label: Label = Label.new()
	number_label.text = number_text
	number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number_label.position = Vector2(266.0, 2.0)
	number_label.size = Vector2(70.0, 24.0)
	number_label.add_theme_font_size_override("font_size", 14)

	if is_heal:
		number_label.add_theme_color_override(
			"font_color",
			Color(0.44, 0.66, 0.34, 1.0)
		)
	else:
		number_label.add_theme_color_override(
			"font_color",
			Color(0.80, 0.16, 0.10, 1.0)
		)

	health_root.add_child(number_label)

	var number_tween: Tween = create_tween()
	number_tween.tween_property(
		number_label,
		"position",
		number_label.position + Vector2(0.0, -24.0),
		0.48
	)
	number_tween.parallel().tween_property(
		number_label,
		"modulate:a",
		0.0,
		0.48
	)
	number_tween.tween_callback(Callable(number_label, "queue_free"))

func show_tutorial_objective(objective_text: String) -> void:
	if tutorial_objective_label == null:
		return

	if tutorial_feedback_tween != null:
		tutorial_feedback_tween.kill()

	tutorial_objective_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	tutorial_objective_label.text = "Objective: " + objective_text
	tutorial_objective_label.visible = true

	_layout_tutorial_objective()

func hide_tutorial_objective() -> void:
	if tutorial_objective_label == null:
		return

	tutorial_objective_label.visible = false

func show_tutorial_completion_message(
	message: String,
	duration: float = 4.0
) -> void:
	if tutorial_objective_label == null:
		return

	if tutorial_feedback_tween != null:
		tutorial_feedback_tween.kill()

	tutorial_objective_label.text = message
	tutorial_objective_label.visible = true
	tutorial_objective_label.modulate = Color(1.0, 0.88, 0.45, 1.0)

	_layout_tutorial_objective()

	tutorial_feedback_tween = create_tween()
	tutorial_feedback_tween.tween_interval(duration)
	tutorial_feedback_tween.tween_property(
		tutorial_objective_label,
		"modulate:a",
		0.0,
		0.65
	)
	tutorial_feedback_tween.tween_callback(
		func() -> void:
			tutorial_objective_label.visible = false
			tutorial_objective_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	)

func update_time(day_number: int, hour: int, minute: int, phase: String) -> void:
	time_label.text = "Day %d | %02d:%02d | %s" % [
		day_number,
		hour,
		minute,
		get_phase_display_name(phase)
	]

func get_phase_display_name(phase: String) -> String:
	match phase:
		"day":
			return "Day"
		"night":
			return "Night"
		"night_cleanup":
			return "Clear Remaining Enemies"
		_:
			return phase.capitalize()

func show_nightfall_message(message: String) -> void:
	show_big_red_message(message, 3.0)

func show_warning_message(message: String) -> void:
	show_big_red_message(message, 2.0)

func show_big_red_message(message: String, duration: float) -> void:
	if warning_tween != null:
		warning_tween.kill()

	night_warning_label.text = message
	night_warning_label.visible = true
	night_warning_label.modulate = Color(1, 0, 0, 1)
	night_warning_label.rotation = -0.08
	night_warning_label.scale = Vector2(1.1, 1.1)

	warning_tween = create_tween()
	warning_tween.tween_property(
		night_warning_label,
		"scale",
		Vector2(1.18, 1.18),
		0.15
	)
	warning_tween.tween_property(
		night_warning_label,
		"scale",
		Vector2(1.1, 1.1),
		0.15
	)
	warning_tween.tween_interval(duration)
	warning_tween.tween_property(
		night_warning_label,
		"modulate:a",
		0.0,
		0.5
	)
	warning_tween.tween_callback(
		func() -> void:
			night_warning_label.visible = false
	)

func fade_to_black(duration: float = 0.35) -> void:
	if fade_tween != null:
		fade_tween.kill()

	fade_overlay.visible = true
	fade_overlay.modulate = Color(1, 1, 1, 0)

	fade_tween = create_tween()
	fade_tween.tween_property(
		fade_overlay,
		"modulate:a",
		1.0,
		duration
	)

	await fade_tween.finished

func fade_from_black(duration: float = 0.35) -> void:
	if fade_tween != null:
		fade_tween.kill()

	fade_overlay.visible = true
	fade_overlay.modulate = Color(1, 1, 1, 1)

	fade_tween = create_tween()
	fade_tween.tween_property(
		fade_overlay,
		"modulate:a",
		0.0,
		duration
	)

	await fade_tween.finished

	fade_overlay.visible = false

func show_time_display() -> void:
	if time_label != null:
		time_label.visible = true

	if enemy_count_label != null:
		enemy_count_label.visible = false

func show_night_enemy_count(enemies_left: int) -> void:
	if time_label != null:
		time_label.visible = false

	if enemy_count_label == null:
		print("[HUD] EnemyCountLabel is missing.")
		return

	enemy_count_label.visible = true
	enemy_count_label.text = "Enemies Remaining = " + str(enemies_left)

	_layout_enemy_count()

func show_night_cleared() -> void:
	if time_label != null:
		time_label.visible = false

	if enemy_count_label == null:
		return

	enemy_count_label.visible = true
	enemy_count_label.text = "Night Cleared. Return to bed."

	_layout_enemy_count()

func show_house_evacuation_warning(seconds_left: int) -> void:
	if time_label != null:
		time_label.visible = false

	if enemy_count_label == null:
		return

	enemy_count_label.visible = true
	enemy_count_label.text = (
		"Leave the house: "
		+ str(seconds_left)
		+ "s"
	)

	_layout_enemy_count()
