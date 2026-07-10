extends CanvasLayer
class_name WorkshopUI

const SIDEBAR_COLLAPSED_WIDTH: float = 54.0
const SIDEBAR_EXPANDED_WIDTH: float = 210.0
const SIDEBAR_PADDING: float = 8.0
const TAB_BUTTON_HEIGHT: float = 42.0

const TAB_PLAYER: String = "player"
const TAB_FENCE: String = "fence"
const TAB_TURRETS: String = "turrets"
const TAB_WEAPONS: String = "weapons"
const TAB_BACKPACK: String = "backpack"
const TAB_GADGETS: String = "gadgets"

const ACTIVE_TREE_TABS = [
	TAB_PLAYER,
	TAB_FENCE
]

const LOCKED_TAB_IDS = [
	TAB_TURRETS,
	TAB_WEAPONS,
	TAB_BACKPACK,
	TAB_GADGETS
]

const TAB_CONTENT: Dictionary = {
	TAB_PLAYER: {
		"title": "PLAYER TREE",
		"subtitle": (
			"Choose a survival direction. "
			+ "Your specialization branch cannot be changed later."
		)
	},
	TAB_FENCE: {
		"title": "FENCE SYSTEM",
		"subtitle": (
			"Choose whether your defences survive pressure "
			+ "or recover faster between attacks."
		)
	},
	TAB_TURRETS: {
		"title": "TURRETS",
		"subtitle": "Locked for this prototype iteration.",
		"body": "This system is planned for a later iteration."
	},
	TAB_WEAPONS: {
		"title": "WEAPONS",
		"subtitle": "Locked for this prototype iteration.",
		"body": "Weapon upgrade trees are planned for a later iteration."
	},
	TAB_BACKPACK: {
		"title": "BACKPACK",
		"subtitle": "Locked for this prototype iteration.",
		"body": "Backpack upgrades are planned for a later iteration."
	},
	TAB_GADGETS: {
		"title": "GADGETS",
		"subtitle": "Locked for this prototype iteration.",
		"body": "No gadget blueprints have been unlocked yet."
	}
}

@onready var overlay: ColorRect = $RootControl/Overlay
@onready var workshop_panel: Panel = $RootControl/WorkshopPanel

@onready var sidebar_panel: Panel = (
	$RootControl/WorkshopPanel/SidebarPanel
)

@onready var pin_button: Button = (
	$RootControl/WorkshopPanel/SidebarPanel/PinButton
)

@onready var player_tab_button: Button = (
	$RootControl/WorkshopPanel/SidebarPanel/PlayerTabButton
)

@onready var fence_tab_button: Button = (
	$RootControl/WorkshopPanel/SidebarPanel/FenceTabButton
)

@onready var turrets_tab_button: Button = (
	$RootControl/WorkshopPanel/SidebarPanel/TurretsTabButton
)

@onready var weapons_tab_button: Button = (
	$RootControl/WorkshopPanel/SidebarPanel/WeaponsTabButton
)

@onready var backpack_tab_button: Button = (
	$RootControl/WorkshopPanel/SidebarPanel/BackpackTabButton
)

@onready var gadgets_tab_button: Button = (
	$RootControl/WorkshopPanel/SidebarPanel/GadgetsTabButton
)

@onready var content_panel: Panel = (
	$RootControl/WorkshopPanel/ContentPanel
)

@onready var content_title_label: Label = (
	$RootControl/WorkshopPanel/ContentPanel/ContentTitleLabel
)

@onready var content_subtitle_label: Label = (
	$RootControl/WorkshopPanel/ContentPanel/ContentSubtitleLabel
)

@onready var content_body_label: Label = (
	$RootControl/WorkshopPanel/ContentPanel/ContentBodyLabel
)

@onready var tree_board: UpgradeTreeBoard = (
	$RootControl/WorkshopPanel/ContentPanel/TreeBoard
)

@onready var upgrade_info_panel: Panel = (
	$RootControl/WorkshopPanel/ContentPanel/UpgradeInfoPanel
)

@onready var upgrade_name_label: Label = (
	$RootControl/WorkshopPanel/ContentPanel/UpgradeInfoPanel/UpgradeNameLabel
)

@onready var upgrade_description_label: Label = (
	$RootControl/WorkshopPanel/ContentPanel/UpgradeInfoPanel/UpgradeDescriptionLabel
)

@onready var upgrade_cost_label: Label = (
	$RootControl/WorkshopPanel/ContentPanel/UpgradeInfoPanel/UpgradeCostLabel
)

@onready var upgrade_status_label: Label = (
	$RootControl/WorkshopPanel/ContentPanel/UpgradeInfoPanel/UpgradeStatusLabel
)

@onready var purchase_button: Button = (
	$RootControl/WorkshopPanel/ContentPanel/UpgradeInfoPanel/PurchaseButton
)

@onready var craft_fence_button: Button = (
	$RootControl/WorkshopPanel/ContentPanel/UpgradeInfoPanel/CraftFenceButton
)

@onready var fence_service_status_label: Label = (
	$RootControl/WorkshopPanel/ContentPanel/UpgradeInfoPanel/FenceServiceStatusLabel
)

@onready var repair_strip: Panel = (
	$RootControl/WorkshopPanel/ContentPanel/RepairStrip
)

@onready var repair_label: Label = (
	$RootControl/WorkshopPanel/ContentPanel/RepairStrip/RepairLabel
)

@onready var repair_quantity_option: OptionButton = (
	$RootControl/WorkshopPanel/ContentPanel/RepairStrip/RepairQuantityOption
)

@onready var repair_button: Button = (
	$RootControl/WorkshopPanel/ContentPanel/RepairStrip/RepairButton
)

@onready var close_button: Button = (
	$RootControl/WorkshopPanel/CloseButton
)

var upgrade_manager: UpgradeManager = null

var defense_manager: DefenseManager = null

var workshop_open: bool = false
var sidebar_hovered: bool = false
var sidebar_pinned: bool = false

var current_tab: String = TAB_PLAYER
var current_subtab: String = ""

var selected_upgrade_by_tree: Dictionary = {
	TAB_PLAYER: UpgradeManager.UPGRADE_FIELD_CONDITIONING,
	TAB_FENCE: UpgradeManager.UPGRADE_REINFORCED_TIMBER
}

var locked_tab_labels: Dictionary = {}

var tutorial_player_upgrade_focus_active: bool = false

func _ready() -> void:
	add_to_group("workshop_ui")

	overlay.visible = false
	overlay.color = Color(0.02, 0.02, 0.02, 1.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	workshop_panel.visible = false
	upgrade_info_panel.clip_contents = true

	_create_locked_tab_labels()

	sidebar_panel.mouse_entered.connect(_on_sidebar_mouse_entered)
	sidebar_panel.mouse_exited.connect(_on_sidebar_mouse_exited)

	workshop_panel.resized.connect(_on_workshop_panel_resized)

	pin_button.pressed.connect(_on_pin_button_pressed)
	close_button.pressed.connect(close_workshop)

	player_tab_button.pressed.connect(_on_player_tab_pressed)
	fence_tab_button.pressed.connect(_on_fence_tab_pressed)

	tree_board.upgrade_selected.connect(_on_tree_upgrade_selected)
	purchase_button.pressed.connect(_on_purchase_upgrade_pressed)

	craft_fence_button.pressed.connect(_on_craft_fence_pressed)
	repair_button.pressed.connect(_on_repair_fences_pressed)

	repair_quantity_option.item_selected.connect(
		_on_repair_quantity_selected
	)

	repair_quantity_option.clear()
	repair_quantity_option.add_item("1x")
	repair_quantity_option.add_item("2x")
	repair_quantity_option.add_item("5x")
	repair_quantity_option.add_item("ALL")
	repair_quantity_option.select(0)

	call_deferred("_find_upgrade_manager")
	call_deferred("_find_defense_manager")
	call_deferred("_refresh_layout_and_content")

func _unhandled_input(event: InputEvent) -> void:
	if not workshop_open:
		return

	if event.is_action_pressed("ui_cancel"):
		close_workshop()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not workshop_open:
		return

	_update_sidebar_hover_from_mouse()

func is_workshop_open() -> bool:
	return workshop_open

func open_workshop() -> void:
	_find_upgrade_manager()
	_find_defense_manager()

	workshop_open = true
	overlay.visible = true
	workshop_panel.visible = true

	var tab_to_open: String = TAB_PLAYER
	var subtab_to_open: String = ""

	if upgrade_manager != null:
		tab_to_open = upgrade_manager.get_workshop_tab_to_open()

		subtab_to_open = upgrade_manager.get_last_workshop_subtab(
			tab_to_open
		)

		upgrade_manager.mark_workshop_opened()

	if not _is_active_tree_tab(tab_to_open):
		tab_to_open = TAB_PLAYER
		subtab_to_open = ""

	select_tab(tab_to_open, subtab_to_open)

func set_tutorial_player_upgrade_focus(active: bool) -> void:
	tutorial_player_upgrade_focus_active = active

	if tutorial_player_upgrade_focus_active:
		current_tab = TAB_PLAYER
		current_subtab = ""

		selected_upgrade_by_tree[TAB_PLAYER] = (
			UpgradeManager.UPGRADE_FIELD_CONDITIONING
		)

		if upgrade_manager != null:
			upgrade_manager.set_workshop_selection(TAB_PLAYER, "")

	_refresh_layout_and_content()

func close_workshop() -> void:
	if not workshop_open:
		return

	workshop_open = false
	overlay.visible = false
	workshop_panel.visible = false

func select_tab(
	new_tab: String,
	new_subtab: String = ""
) -> void:
	if not TAB_CONTENT.has(new_tab):
		return

	if not _is_active_tree_tab(new_tab):
		return
	
	if tutorial_player_upgrade_focus_active and new_tab != TAB_PLAYER:
		return

	current_tab = new_tab
	current_subtab = new_subtab

	if upgrade_manager != null:
		upgrade_manager.set_workshop_selection(
			current_tab,
			current_subtab
		)

	_refresh_layout_and_content()

func _find_upgrade_manager() -> void:
	var found_upgrade_manager: UpgradeManager = (
		get_tree().get_first_node_in_group("upgrade_manager")
		as UpgradeManager
	)

	if found_upgrade_manager == null:
		return

	if upgrade_manager == found_upgrade_manager:
		return

	upgrade_manager = found_upgrade_manager

	var purchased_callback := Callable(self, "_on_upgrade_purchased")

	if not upgrade_manager.upgrade_purchased.is_connected(
		purchased_callback
	):
		upgrade_manager.upgrade_purchased.connect(
			purchased_callback
		)

	var failed_callback := Callable(self, "_on_upgrade_purchase_failed")

	if not upgrade_manager.upgrade_purchase_failed.is_connected(
		failed_callback
	):
		upgrade_manager.upgrade_purchase_failed.connect(
			failed_callback
		)
		
func _find_defense_manager() -> void:
	var found_defense_manager: DefenseManager = (
		get_tree().get_first_node_in_group("defense_manager")
		as DefenseManager
	)

	if found_defense_manager == null:
		return

	if defense_manager == found_defense_manager:
		return

	defense_manager = found_defense_manager

	var inventory_callback := Callable(
		self,
		"_on_fence_inventory_changed"
	)

	if not defense_manager.fence_inventory_changed.is_connected(
		inventory_callback
	):
		defense_manager.fence_inventory_changed.connect(
			inventory_callback
		)

	var repair_queue_callback := Callable(
		self,
		"_on_fence_repair_queue_changed"
	)

	if not defense_manager.fence_repair_queue_changed.is_connected(
		repair_queue_callback
	):
		defense_manager.fence_repair_queue_changed.connect(
			repair_queue_callback
		)

func _refresh_layout_and_content() -> void:
	_apply_sidebar_layout()
	_refresh_content()

func _apply_sidebar_layout() -> void:
	var sidebar_width: float = _get_sidebar_width()

	sidebar_panel.position = Vector2.ZERO
	sidebar_panel.size = Vector2(
		sidebar_width,
		workshop_panel.size.y
	)

	pin_button.position = Vector2(
		SIDEBAR_PADDING,
		12.0
	)

	pin_button.size = Vector2(
		sidebar_width - SIDEBAR_PADDING * 2.0,
		30.0
	)

	var tab_width: float = sidebar_width - SIDEBAR_PADDING * 2.0
	var first_tab_y: float = 58.0

	_layout_tab_button(
		player_tab_button,
		first_tab_y,
		tab_width
	)

	_layout_tab_button(
		fence_tab_button,
		first_tab_y + TAB_BUTTON_HEIGHT,
		tab_width
	)

	_layout_tab_button(
		turrets_tab_button,
		first_tab_y + TAB_BUTTON_HEIGHT * 2.0,
		tab_width
	)

	_layout_tab_button(
		weapons_tab_button,
		first_tab_y + TAB_BUTTON_HEIGHT * 3.0,
		tab_width
	)

	_layout_tab_button(
		backpack_tab_button,
		first_tab_y + TAB_BUTTON_HEIGHT * 4.0,
		tab_width
	)

	_layout_tab_button(
		gadgets_tab_button,
		first_tab_y + TAB_BUTTON_HEIGHT * 5.0,
		tab_width
	)

	content_panel.position = Vector2(
		sidebar_width + 14.0,
		14.0
	)

	content_panel.size = Vector2(
		workshop_panel.size.x - sidebar_width - 28.0,
		workshop_panel.size.y - 28.0
	)

	close_button.position = Vector2(
		workshop_panel.size.x - 48.0,
		12.0
	)

	close_button.size = Vector2(34.0, 28.0)

	content_title_label.position = Vector2(24.0, 20.0)
	content_title_label.size = Vector2(
		content_panel.size.x - 330.0,
		34.0
	)

	content_subtitle_label.position = Vector2(24.0, 60.0)
	content_subtitle_label.size = Vector2(
		content_panel.size.x - 330.0,
		52.0
	)

	content_body_label.position = Vector2(28.0, 138.0)
	content_body_label.size = Vector2(
		content_panel.size.x - 56.0,
		content_panel.size.y - 165.0
	)

	tree_board.position = Vector2(18.0, 126.0)
	tree_board.size = Vector2(
		maxf(260.0, content_panel.size.x - 320.0),
		maxf(180.0, content_panel.size.y - 150.0)
	)

	upgrade_info_panel.position = Vector2(
		content_panel.size.x - 286.0,
		126.0
	)

	upgrade_info_panel.size = Vector2(
		262.0,
		maxf(180.0, content_panel.size.y - 150.0)
	)

	_layout_upgrade_info_panel()

	repair_strip.position = Vector2(
		content_panel.size.x - 292.0,
		18.0
	)

	repair_strip.size = Vector2(268.0, 88.0)

	repair_label.position = Vector2(10.0, 8.0)
	repair_label.size = Vector2(248.0, 22.0)

	repair_quantity_option.position = Vector2(12.0, 42.0)
	repair_quantity_option.size = Vector2(78.0, 30.0)

	repair_button.position = Vector2(100.0, 42.0)
	repair_button.size = Vector2(156.0, 30.0)

	_refresh_sidebar_buttons()

func _layout_upgrade_info_panel() -> void:
	var panel_width: float = upgrade_info_panel.size.x
	var panel_height: float = upgrade_info_panel.size.y

	var is_fence_tab: bool = current_tab == TAB_FENCE
	var horizontal_padding: float = 14.0
	var content_width: float = panel_width - horizontal_padding * 2.0

	upgrade_name_label.position = Vector2(
		horizontal_padding,
		14.0
	)
	upgrade_name_label.size = Vector2(
		content_width,
		36.0
	)

	upgrade_description_label.position = Vector2(
		horizontal_padding,
		56.0
	)
	upgrade_description_label.size = Vector2(
		content_width,
		72.0
	)

	upgrade_cost_label.position = Vector2(
		horizontal_padding,
		136.0
	)
	upgrade_cost_label.size = Vector2(
		content_width,
		22.0
	)

	upgrade_status_label.position = Vector2(
		horizontal_padding,
		164.0
	)
	upgrade_status_label.size = Vector2(
		content_width,
		38.0
	)

	fence_service_status_label.position = Vector2(
		horizontal_padding,
		210.0
	)
	fence_service_status_label.size = Vector2(
		content_width,
		44.0
	)

	var button_height: float = 34.0
	var bottom_padding: float = 14.0

	var craft_button_y: float = (
		panel_height
		- bottom_padding
		- button_height
	)

	var purchase_button_y: float = (
		craft_button_y
		- 10.0
		- button_height
	)

	purchase_button.size = Vector2(
		content_width,
		button_height
	)

	craft_fence_button.size = Vector2(
		content_width,
		button_height
	)

	if is_fence_tab:
		purchase_button.position = Vector2(
			horizontal_padding,
			purchase_button_y
		)

		craft_fence_button.position = Vector2(
			horizontal_padding,
			craft_button_y
		)
	else:
		purchase_button.position = Vector2(
			horizontal_padding,
			craft_button_y
		)

		craft_fence_button.position = Vector2(
			horizontal_padding,
			craft_button_y
		)

func _layout_tab_button(
	tab_button: Button,
	y_position: float,
	tab_width: float
) -> void:
	tab_button.position = Vector2(
		SIDEBAR_PADDING,
		y_position
	)

	tab_button.size = Vector2(
		tab_width,
		TAB_BUTTON_HEIGHT - 4.0
	)

func _refresh_sidebar_buttons() -> void:
	var expanded: bool = _is_sidebar_expanded()

	pin_button.text = "<" if sidebar_pinned else ">"

	if sidebar_pinned:
		pin_button.tooltip_text = "Unpin sidebar"
	else:
		pin_button.tooltip_text = "Pin sidebar open"

	_set_tab_button(
		player_tab_button,
		"P",
		"PLAYER",
		TAB_PLAYER,
		expanded
	)

	_set_tab_button(
		fence_tab_button,
		"F",
		"FENCE",
		TAB_FENCE,
		expanded
	)

	_set_tab_button(
		turrets_tab_button,
		"T",
		"TURRETS",
		TAB_TURRETS,
		expanded
	)

	_set_tab_button(
		weapons_tab_button,
		"W",
		"WEAPONS",
		TAB_WEAPONS,
		expanded
	)

	_set_tab_button(
		backpack_tab_button,
		"B",
		"BACKPACK",
		TAB_BACKPACK,
		expanded
	)

	_set_tab_button(
		gadgets_tab_button,
		"G",
		"GADGETS",
		TAB_GADGETS,
		expanded
	)

	_layout_locked_badges()

func _set_tab_button(
	tab_button: Button,
	short_text: String,
	full_text: String,
	tab_id: String,
	expanded: bool
) -> void:
	var tab_is_locked: bool = LOCKED_TAB_IDS.has(tab_id)
	
	if tutorial_player_upgrade_focus_active and tab_id != TAB_PLAYER:
		tab_button.text = full_text if expanded else short_text
		tab_button.disabled = true
		tab_button.modulate = Color(0.38, 0.38, 0.38)
		tab_button.tooltip_text = "Buy Field Conditioning I first."
		return

	tab_button.text = full_text if expanded else short_text
	tab_button.disabled = tab_is_locked

	if tab_is_locked:
		tab_button.modulate = Color(0.42, 0.42, 0.42)
		tab_button.tooltip_text = (
			full_text
			+ "\nLOCKED — planned for a later iteration."
		)
		return

	tab_button.tooltip_text = full_text

	if tab_id == current_tab:
		tab_button.modulate = Color(1.0, 0.86, 0.32)
	else:
		tab_button.modulate = Color.WHITE

func _create_locked_tab_labels() -> void:
	for tab_id in LOCKED_TAB_IDS:
		var locked_label := Label.new()

		locked_label.name = "LockedBadge_" + tab_id
		locked_label.text = "LOCKED"
		locked_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		locked_label.rotation = deg_to_rad(-45.0)
		locked_label.add_theme_font_size_override("font_size", 11)
		locked_label.add_theme_color_override(
			"font_color",
			Color(0.95, 0.32, 0.32, 0.95)
		)

		sidebar_panel.add_child(locked_label)

		locked_tab_labels[tab_id] = locked_label

func _layout_locked_badges() -> void:
	_layout_locked_badge(TAB_TURRETS, turrets_tab_button)
	_layout_locked_badge(TAB_WEAPONS, weapons_tab_button)
	_layout_locked_badge(TAB_BACKPACK, backpack_tab_button)
	_layout_locked_badge(TAB_GADGETS, gadgets_tab_button)

func _layout_locked_badge(
	tab_id: String,
	tab_button: Button
) -> void:
	var locked_label: Label = locked_tab_labels.get(
		tab_id,
		null
	) as Label

	if locked_label == null:
		return

	locked_label.visible = _is_sidebar_expanded()

	if not locked_label.visible:
		return

	locked_label.size = Vector2(70.0, 20.0)
	locked_label.pivot_offset = locked_label.size * 0.5

	locked_label.position = tab_button.position + Vector2(
		tab_button.size.x - 48.0,
		tab_button.size.y * 0.5 - 10.0
	)

func _refresh_content() -> void:
	var tab_data: Dictionary = TAB_CONTENT.get(current_tab, {})

	content_title_label.text = str(
		tab_data.get("title", "WORKSHOP")
	)

	content_subtitle_label.text = str(
		tab_data.get("subtitle", "")
	)

	var showing_tree: bool = _is_active_tree_tab(current_tab)

	tree_board.visible = showing_tree
	upgrade_info_panel.visible = showing_tree
	content_body_label.visible = not showing_tree

	if not showing_tree:
		content_body_label.text = str(tab_data.get("body", ""))

		repair_strip.visible = false
		craft_fence_button.visible = false
		fence_service_status_label.visible = false

		return

	content_body_label.text = ""

	var selected_upgrade_id: String = str(
		selected_upgrade_by_tree.get(
			current_tab,
			_get_default_upgrade_for_tree(current_tab)
		)
	)

	if upgrade_manager != null:
		tree_board.configure_tree(
			current_tab,
			upgrade_manager
		)

		tree_board.set_selected_upgrade(selected_upgrade_id)

	_refresh_selected_upgrade_panel()

	var is_fence_tab: bool = current_tab == TAB_FENCE

	repair_strip.visible = is_fence_tab
	craft_fence_button.visible = is_fence_tab
	fence_service_status_label.visible = is_fence_tab

	if is_fence_tab:
		_refresh_fence_service_controls()

func _refresh_selected_upgrade_panel() -> void:
	if upgrade_manager == null:
		upgrade_name_label.text = "Upgrade Manager Missing"
		upgrade_description_label.text = ""
		upgrade_cost_label.text = ""
		upgrade_status_label.text = ""
		purchase_button.disabled = true
		return

	var selected_upgrade_id: String = str(
		selected_upgrade_by_tree.get(
			current_tab,
			_get_default_upgrade_for_tree(current_tab)
		)
	)

	var definition: Dictionary = (
		upgrade_manager.get_upgrade_definition(selected_upgrade_id)
	)

	if definition.is_empty():
		upgrade_name_label.text = "No Upgrade Selected"
		upgrade_description_label.text = ""
		upgrade_cost_label.text = ""
		upgrade_status_label.text = ""
		purchase_button.disabled = true
		return

	var status: String = upgrade_manager.get_upgrade_status(
		selected_upgrade_id
	)

	var cost_scrap: int = int(
		definition.get("cost_scrap", 0)
	)

	upgrade_name_label.text = str(
		definition.get("title", selected_upgrade_id)
	)

	upgrade_description_label.text = str(
		definition.get("description", "")
	)

	upgrade_cost_label.text = "Cost: %d Scrap" % cost_scrap

	upgrade_status_label.text = (
		"Status: "
		+ upgrade_manager.get_upgrade_status_message(
			selected_upgrade_id
		)
	)

	purchase_button.disabled = (
		status != UpgradeManager.STATUS_AVAILABLE
	)

	match status:
		UpgradeManager.STATUS_AVAILABLE:
			purchase_button.text = (
				"PURCHASE — %d SCRAP" % cost_scrap
			)

		UpgradeManager.STATUS_PURCHASED:
			purchase_button.text = "PURCHASED"

		UpgradeManager.STATUS_INSUFFICIENT_SCRAP:
			purchase_button.text = "NOT ENOUGH SCRAP"

		UpgradeManager.STATUS_LOCKED_BRANCH:
			purchase_button.text = "BRANCH LOCKED"

		UpgradeManager.STATUS_LOCKED_PREREQUISITE:
			purchase_button.text = "REQUIRES PREVIOUS NODE"

		_:
			purchase_button.text = "UNAVAILABLE"
			
func _refresh_fence_service_controls() -> void:
	if current_tab != TAB_FENCE:
		return

	_find_defense_manager()

	if defense_manager == null:
		repair_label.text = "FENCE REPAIR"
		repair_quantity_option.disabled = true
		repair_button.disabled = true
		repair_button.text = "SYSTEM UNAVAILABLE"

		craft_fence_button.disabled = true
		craft_fence_button.text = "SYSTEM UNAVAILABLE"

		fence_service_status_label.text = (
			"Fence service data is unavailable."
		)

		return

	var stored_fences: int = defense_manager.get_fences_available()

	var repair_queue_count: int = (
		defense_manager.get_broken_fences_in_repair_queue()
	)

	fence_service_status_label.text = (
		"Stored: %d\nQueue: %d Broken"
		% [stored_fences, repair_queue_count]
	)

	var craft_scrap_cost: int = (
		defense_manager.get_fence_craft_scrap_cost()
	)

	var craft_seed_cost: int = (
		defense_manager.get_fence_craft_seed_cost()
	)

	var craft_failure_reason: String = (
		defense_manager.get_fence_craft_failure_reason()
	)

	craft_fence_button.text = (
		"CRAFT FENCE — %d SCRAP + %d SEEDS"
		% [craft_scrap_cost, craft_seed_cost]
	)

	craft_fence_button.disabled = not craft_failure_reason.is_empty()

	if craft_failure_reason.is_empty():
		craft_fence_button.tooltip_text = (
			"Craft 1 Fence for %d Scrap and %d Seeds."
			% [craft_scrap_cost, craft_seed_cost]
		)
	else:
		craft_fence_button.tooltip_text = craft_failure_reason

	repair_label.text = (
		"FENCE REPAIR — %d IN QUEUE"
		% repair_queue_count
	)

	if repair_queue_count <= 0:
		repair_quantity_option.disabled = true

		repair_button.disabled = true
		repair_button.text = "NO BROKEN FENCES"
		repair_button.tooltip_text = (
			"No broken fences are waiting for repair."
		)

		return

	repair_quantity_option.disabled = false

	var requested_amount: int = _get_requested_repair_quantity()

	var repair_count: int = (
		defense_manager.get_repairable_broken_fence_count(
			requested_amount
		)
	)

	var repair_scrap_cost: int = (
		defense_manager.get_broken_fence_repair_total_cost(
			repair_count
		)
	)

	var repair_failure_reason: String = (
		defense_manager.get_broken_fence_repair_failure_reason(
			requested_amount
		)
	)

	var selected_quantity_text: String = (
		repair_quantity_option.get_item_text(
			repair_quantity_option.selected
		)
	)

	var repair_quantity_text: String = selected_quantity_text

	if selected_quantity_text != "ALL":
		repair_quantity_text = "%dx" % repair_count

	if repair_failure_reason.is_empty():
		repair_button.disabled = false

		repair_button.text = (
			"REPAIR %s — %d SCRAP"
			% [repair_quantity_text, repair_scrap_cost]
		)

		repair_button.tooltip_text = (
			"Repair %d broken fence(s) for %d Scrap."
			% [repair_count, repair_scrap_cost]
		)
	else:
		repair_button.disabled = true

		if repair_failure_reason.begins_with("Need"):
			repair_button.text = "NOT ENOUGH MATERIALS"
		else:
			repair_button.text = "NO BROKEN FENCES"

		repair_button.tooltip_text = repair_failure_reason

func _get_requested_repair_quantity() -> int:
	if defense_manager == null:
		return 0

	match repair_quantity_option.selected:
		0:
			return 1

		1:
			return 2

		2:
			return 5

		3:
			return defense_manager.get_broken_fences_in_repair_queue()

	return 1

func _on_craft_fence_pressed() -> void:
	if defense_manager == null:
		return

	defense_manager.craft_fence_in_workshop()

	_refresh_fence_service_controls()

func _on_repair_fences_pressed() -> void:
	if defense_manager == null:
		return

	var requested_amount: int = _get_requested_repair_quantity()

	defense_manager.repair_broken_fences_with_materials(
		requested_amount
	)

	_refresh_fence_service_controls()

func _on_repair_quantity_selected(_selected_index: int) -> void:
	_refresh_fence_service_controls()

func _on_fence_inventory_changed(
	_fences_available: int
) -> void:
	if workshop_open and current_tab == TAB_FENCE:
		_refresh_fence_service_controls()

func _on_fence_repair_queue_changed(
	_broken_fences_in_queue: int
) -> void:
	if workshop_open and current_tab == TAB_FENCE:
		_refresh_fence_service_controls()

func _get_default_upgrade_for_tree(tree_id: String) -> String:
	match tree_id:
		TAB_PLAYER:
			return UpgradeManager.UPGRADE_FIELD_CONDITIONING

		TAB_FENCE:
			return UpgradeManager.UPGRADE_REINFORCED_TIMBER

	return ""

func _is_active_tree_tab(tab_id: String) -> bool:
	return ACTIVE_TREE_TABS.has(tab_id)

func _on_tree_upgrade_selected(upgrade_id: String) -> void:
	if tutorial_player_upgrade_focus_active:
		if upgrade_id != UpgradeManager.UPGRADE_FIELD_CONDITIONING:
			selected_upgrade_by_tree[TAB_PLAYER] = (
				UpgradeManager.UPGRADE_FIELD_CONDITIONING
			)

			tree_board.set_selected_upgrade(
				UpgradeManager.UPGRADE_FIELD_CONDITIONING
			)

			_refresh_selected_upgrade_panel()
			return

	selected_upgrade_by_tree[current_tab] = upgrade_id
	_refresh_selected_upgrade_panel()

func _on_purchase_upgrade_pressed() -> void:
	if upgrade_manager == null:
		return

	var selected_upgrade_id: String = str(
		selected_upgrade_by_tree.get(
			current_tab,
			_get_default_upgrade_for_tree(current_tab)
		)
	)

	upgrade_manager.purchase_upgrade(selected_upgrade_id)

func _on_upgrade_purchased(_upgrade_id: String) -> void:
	tree_board.refresh_tree()
	_refresh_selected_upgrade_panel()

func _on_upgrade_purchase_failed(
	failed_upgrade_id: String,
	reason: String
) -> void:
	tree_board.refresh_tree()
	_refresh_selected_upgrade_panel()

	var selected_upgrade_id: String = str(
		selected_upgrade_by_tree.get(
			current_tab,
			""
		)
	)

	if failed_upgrade_id == selected_upgrade_id:
		upgrade_status_label.text = "Status: " + reason

func _update_sidebar_hover_from_mouse() -> void:
	if sidebar_panel == null:
		return

	var mouse_position: Vector2 = get_viewport().get_mouse_position()

	var mouse_is_over_sidebar: bool = (
		sidebar_panel.get_global_rect().has_point(mouse_position)
	)

	if mouse_is_over_sidebar == sidebar_hovered:
		return

	sidebar_hovered = mouse_is_over_sidebar
	_refresh_layout_and_content()

func _get_sidebar_width() -> float:
	if _is_sidebar_expanded():
		return SIDEBAR_EXPANDED_WIDTH

	return SIDEBAR_COLLAPSED_WIDTH

func _is_sidebar_expanded() -> bool:
	return sidebar_hovered or sidebar_pinned

func _on_sidebar_mouse_entered() -> void:
	_update_sidebar_hover_from_mouse()

func _on_sidebar_mouse_exited() -> void:
	call_deferred("_update_sidebar_hover_from_mouse")

func _on_pin_button_pressed() -> void:
	sidebar_pinned = not sidebar_pinned
	_refresh_layout_and_content()

func _on_workshop_panel_resized() -> void:
	_refresh_layout_and_content()

func _on_player_tab_pressed() -> void:
	select_tab(TAB_PLAYER)

func _on_fence_tab_pressed() -> void:
	select_tab(TAB_FENCE)
