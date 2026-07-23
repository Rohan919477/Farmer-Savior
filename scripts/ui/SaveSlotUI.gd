extends CanvasLayer
class_name SaveSlotUI

signal save_slot_selected(manual_slot_index: int)
signal save_slot_cancelled

signal new_game_slot_selected(slot_index: int)
signal load_slot_selected(slot_index: int)
signal slot_menu_cancelled(menu_mode: String)
signal slot_deleted(slot_index: int)

const MODE_SLEEP_SAVE: String = "sleep_save"
const MODE_NEW_GAME: String = "new_game"
const MODE_LOAD_GAME: String = "load_game"

const CONFIRM_NONE: String = "none"
const CONFIRM_OVERWRITE: String = "overwrite"
const CONFIRM_DELETE: String = "delete"

const SLOT_AUTOSAVE: int = 0
const SLOT_1: int = 1
const SLOT_2: int = 2
const SLOT_3: int = 3

var current_mode: String = MODE_SLEEP_SAVE
var confirm_action: String = CONFIRM_NONE

var root_control: Control
var backdrop: ColorRect
var center_panel: Panel
var title_label: Label
var instruction_label: Label

var autosave_button: Button
var slot_1_button: Button
var slot_2_button: Button
var slot_3_button: Button

var autosave_delete_button: Button
var slot_1_delete_button: Button
var slot_2_delete_button: Button
var slot_3_delete_button: Button

var sleep_without_manual_button: Button
var cancel_button: Button

var confirm_panel: Panel
var confirm_label: Label
var confirm_yes_button: Button
var confirm_no_button: Button

var slot_buttons: Dictionary = {}
var delete_buttons: Dictionary = {}

var pending_overwrite_slot: int = -1
var pending_delete_slot: int = -1

var save_manager: SaveManager = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_find_save_manager()
	close_save_menu(false)

	get_viewport().size_changed.connect(_layout_ui)

func open_save_menu() -> void:
	open_sleep_save_menu()

func open_sleep_save_menu() -> void:
	current_mode = MODE_SLEEP_SAVE
	_open_menu_common()

func open_new_game_menu() -> void:
	current_mode = MODE_NEW_GAME
	_open_menu_common()

func open_load_game_menu() -> void:
	current_mode = MODE_LOAD_GAME
	_open_menu_common()

func close_save_menu(resume_game: bool = true) -> void:
	if root_control != null:
		root_control.visible = false

	if confirm_panel != null:
		confirm_panel.visible = false

	pending_overwrite_slot = -1
	pending_delete_slot = -1
	confirm_action = CONFIRM_NONE

	if resume_game:
		get_tree().paused = false

func is_save_slot_ui_open() -> bool:
	if root_control == null:
		return false

	return root_control.visible

func _open_menu_common() -> void:
	_find_save_manager()
	_refresh_for_current_mode()

	pending_overwrite_slot = -1
	pending_delete_slot = -1
	confirm_action = CONFIRM_NONE
	confirm_panel.visible = false

	root_control.visible = true
	_layout_ui()

	get_tree().paused = true

func _build_ui() -> void:
	root_control = Control.new()
	root_control.name = "RootControl"
	add_child(root_control)

	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP

	backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	root_control.add_child(backdrop)

	backdrop.color = Color(0.0, 0.0, 0.0, 0.78)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP

	center_panel = Panel.new()
	center_panel.name = "CenterPanel"
	root_control.add_child(center_panel)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	center_panel.add_child(title_label)

	instruction_label = Label.new()
	instruction_label.name = "InstructionLabel"
	center_panel.add_child(instruction_label)

	autosave_button = Button.new()
	autosave_button.name = "AutosaveButton"
	center_panel.add_child(autosave_button)

	autosave_delete_button = Button.new()
	autosave_delete_button.name = "AutosaveDeleteButton"
	center_panel.add_child(autosave_delete_button)

	slot_1_button = Button.new()
	slot_1_button.name = "Slot1Button"
	center_panel.add_child(slot_1_button)

	slot_1_delete_button = Button.new()
	slot_1_delete_button.name = "Slot1DeleteButton"
	center_panel.add_child(slot_1_delete_button)

	slot_2_button = Button.new()
	slot_2_button.name = "Slot2Button"
	center_panel.add_child(slot_2_button)

	slot_2_delete_button = Button.new()
	slot_2_delete_button.name = "Slot2DeleteButton"
	center_panel.add_child(slot_2_delete_button)

	slot_3_button = Button.new()
	slot_3_button.name = "Slot3Button"
	center_panel.add_child(slot_3_button)

	slot_3_delete_button = Button.new()
	slot_3_delete_button.name = "Slot3DeleteButton"
	center_panel.add_child(slot_3_delete_button)

	slot_buttons = {
		SLOT_AUTOSAVE: autosave_button,
		SLOT_1: slot_1_button,
		SLOT_2: slot_2_button,
		SLOT_3: slot_3_button
	}

	delete_buttons = {
		SLOT_AUTOSAVE: autosave_delete_button,
		SLOT_1: slot_1_delete_button,
		SLOT_2: slot_2_delete_button,
		SLOT_3: slot_3_delete_button
	}

	sleep_without_manual_button = Button.new()
	sleep_without_manual_button.name = "SleepWithoutManualButton"
	center_panel.add_child(sleep_without_manual_button)

	cancel_button = Button.new()
	cancel_button.name = "CancelButton"
	center_panel.add_child(cancel_button)

	confirm_panel = Panel.new()
	confirm_panel.name = "ConfirmPanel"
	center_panel.add_child(confirm_panel)

	confirm_label = Label.new()
	confirm_label.name = "ConfirmLabel"
	confirm_panel.add_child(confirm_label)

	confirm_yes_button = Button.new()
	confirm_yes_button.name = "ConfirmYesButton"
	confirm_panel.add_child(confirm_yes_button)

	confirm_no_button = Button.new()
	confirm_no_button.name = "ConfirmNoButton"
	confirm_panel.add_child(confirm_no_button)

	_apply_panel_style()
	_setup_text()
	_connect_buttons()

func _apply_panel_style() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.075, 0.085, 0.06, 1.0)
	panel_style.border_color = Color(0.72, 0.58, 0.24, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(18)
	center_panel.add_theme_stylebox_override("panel", panel_style)

	var confirm_style := StyleBoxFlat.new()
	confirm_style.bg_color = Color(0.12, 0.08, 0.045, 1.0)
	confirm_style.border_color = Color(0.90, 0.60, 0.20, 1.0)
	confirm_style.set_border_width_all(2)
	confirm_style.set_corner_radius_all(14)
	confirm_panel.add_theme_stylebox_override("panel", confirm_style)

func _setup_text() -> void:
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.86, 0.45, 1.0)
	)

	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction_label.add_theme_font_size_override("font_size", 14)
	instruction_label.add_theme_color_override(
		"font_color",
		Color(0.92, 0.88, 0.75, 1.0)
	)

	for slot_index in slot_buttons.keys():
		var slot_button: Button = slot_buttons[slot_index]
		var delete_button: Button = delete_buttons[slot_index]

		slot_button.focus_mode = Control.FOCUS_NONE
		delete_button.focus_mode = Control.FOCUS_NONE
		delete_button.text = "X"
		delete_button.tooltip_text = "Delete this save slot."

	sleep_without_manual_button.focus_mode = Control.FOCUS_NONE
	cancel_button.focus_mode = Control.FOCUS_NONE
	confirm_yes_button.focus_mode = Control.FOCUS_NONE
	confirm_no_button.focus_mode = Control.FOCUS_NONE

	cancel_button.text = "CANCEL"

	confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_label.add_theme_font_size_override("font_size", 15)

	confirm_yes_button.text = "YES"
	confirm_no_button.text = "CANCEL"

func _connect_buttons() -> void:
	autosave_button.pressed.connect(
		func() -> void:
			_on_slot_pressed(SLOT_AUTOSAVE)
	)

	slot_1_button.pressed.connect(
		func() -> void:
			_on_slot_pressed(SLOT_1)
	)

	slot_2_button.pressed.connect(
		func() -> void:
			_on_slot_pressed(SLOT_2)
	)

	slot_3_button.pressed.connect(
		func() -> void:
			_on_slot_pressed(SLOT_3)
	)

	autosave_delete_button.pressed.connect(
		func() -> void:
			_on_delete_slot_pressed(SLOT_AUTOSAVE)
	)

	slot_1_delete_button.pressed.connect(
		func() -> void:
			_on_delete_slot_pressed(SLOT_1)
	)

	slot_2_delete_button.pressed.connect(
		func() -> void:
			_on_delete_slot_pressed(SLOT_2)
	)

	slot_3_delete_button.pressed.connect(
		func() -> void:
			_on_delete_slot_pressed(SLOT_3)
	)

	sleep_without_manual_button.pressed.connect(
		func() -> void:
			_accept_sleep_save_slot(-1)
	)

	cancel_button.pressed.connect(_on_cancel_pressed)
	confirm_yes_button.pressed.connect(_on_confirm_yes_pressed)
	confirm_no_button.pressed.connect(_on_confirm_no_pressed)

func _layout_ui() -> void:
	if root_control == null:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	backdrop.position = Vector2.ZERO
	backdrop.size = viewport_size

	var panel_size: Vector2 = Vector2(600.0, 500.0)

	center_panel.position = (viewport_size - panel_size) * 0.5
	center_panel.size = panel_size

	title_label.position = Vector2(24.0, 28.0)
	title_label.size = Vector2(552.0, 42.0)

	instruction_label.position = Vector2(46.0, 78.0)
	instruction_label.size = Vector2(508.0, 52.0)

	var button_x: float = 78.0
	var button_width: float = 390.0
	var delete_x: float = 478.0
	var delete_width: float = 42.0
	var button_height: float = 42.0
	var first_y: float = 146.0
	var gap: float = 50.0

	_position_slot_row(
		autosave_button,
		autosave_delete_button,
		button_x,
		delete_x,
		first_y,
		button_width,
		delete_width,
		button_height
	)

	_position_slot_row(
		slot_1_button,
		slot_1_delete_button,
		button_x,
		delete_x,
		first_y + gap,
		button_width,
		delete_width,
		button_height
	)

	_position_slot_row(
		slot_2_button,
		slot_2_delete_button,
		button_x,
		delete_x,
		first_y + gap * 2.0,
		button_width,
		delete_width,
		button_height
	)

	_position_slot_row(
		slot_3_button,
		slot_3_delete_button,
		button_x,
		delete_x,
		first_y + gap * 3.0,
		button_width,
		delete_width,
		button_height
	)

	sleep_without_manual_button.position = Vector2(button_x, 360.0)
	sleep_without_manual_button.size = Vector2(
		button_width + delete_width + 10.0,
		button_height
	)

	cancel_button.position = Vector2(button_x, 414.0)
	cancel_button.size = Vector2(
		button_width + delete_width + 10.0,
		button_height
	)

	if not sleep_without_manual_button.visible:
		cancel_button.position = Vector2(button_x, 370.0)

	confirm_panel.position = Vector2(75.0, 156.0)
	confirm_panel.size = Vector2(450.0, 205.0)

	confirm_label.position = Vector2(24.0, 24.0)
	confirm_label.size = Vector2(402.0, 70.0)

	confirm_yes_button.position = Vector2(44.0, 122.0)
	confirm_yes_button.size = Vector2(175.0, 42.0)

	confirm_no_button.position = Vector2(232.0, 122.0)
	confirm_no_button.size = Vector2(175.0, 42.0)

func _position_slot_row(
	slot_button: Button,
	delete_button: Button,
	button_x: float,
	delete_x: float,
	row_y: float,
	button_width: float,
	delete_width: float,
	button_height: float
) -> void:
	slot_button.position = Vector2(button_x, row_y)
	slot_button.size = Vector2(button_width, button_height)

	delete_button.position = Vector2(delete_x, row_y)
	delete_button.size = Vector2(delete_width, button_height)

func _find_save_manager() -> void:
	save_manager = get_tree().get_first_node_in_group(
		"save_manager"
	) as SaveManager

func _refresh_for_current_mode() -> void:
	match current_mode:
		MODE_SLEEP_SAVE:
			title_label.text = "SAVE BEFORE SLEEPING"
			instruction_label.text = (
				"Autosave Slot is updated every time you sleep. "
				+ "Choose a manual slot if you want an extra copy."
			)
			sleep_without_manual_button.visible = true
			sleep_without_manual_button.text = "SLEEP WITH AUTOSAVE ONLY"

		MODE_NEW_GAME:
			title_label.text = "NEW GAME"
			instruction_label.text = (
				"Choose an empty manual slot for this new game. "
				+ "Occupied slots can be deleted if you no longer need them."
			)
			sleep_without_manual_button.visible = false

		MODE_LOAD_GAME:
			title_label.text = "LOAD SAVE"
			instruction_label.text = (
				"Choose Autosave or an occupied manual slot to load. "
				+ "Use X to delete unwanted saves."
			)
			sleep_without_manual_button.visible = false

	_refresh_slot_buttons()

func _refresh_slot_buttons() -> void:
	for slot_index in slot_buttons.keys():
		_refresh_button_for_slot(int(slot_index))

func _refresh_button_for_slot(slot_index: int) -> void:
	var button: Button = slot_buttons[slot_index]
	var delete_button: Button = delete_buttons[slot_index]

	button.text = _get_button_text_for_slot(slot_index)
	button.disabled = _is_slot_disabled_for_mode(slot_index)

	var occupied: bool = false

	if save_manager != null:
		occupied = save_manager.has_slot_save(slot_index)

	delete_button.visible = occupied
	delete_button.disabled = not occupied

func _get_button_text_for_slot(slot_index: int) -> String:
	if save_manager == null:
		if slot_index == SLOT_AUTOSAVE:
			return "AUTOSAVE SLOT - SAVE MANAGER MISSING"

		return "MANUAL SLOT %d - SAVE MANAGER MISSING" % slot_index

	var summary: Dictionary = save_manager.get_slot_summary(slot_index)

	var title: String = str(summary.get("title", "Slot"))
	var details: String = str(summary.get("details", "Empty"))

	return "%s | %s" % [
		title.to_upper(),
		details
	]

func _is_slot_disabled_for_mode(slot_index: int) -> bool:
	if save_manager == null:
		return true

	var occupied: bool = save_manager.has_slot_save(slot_index)

	match current_mode:
		MODE_SLEEP_SAVE:
			return slot_index == SLOT_AUTOSAVE

		MODE_NEW_GAME:
			if slot_index == SLOT_AUTOSAVE:
				return true

			return occupied

		MODE_LOAD_GAME:
			return not occupied

	return true

func _on_slot_pressed(slot_index: int) -> void:
	match current_mode:
		MODE_SLEEP_SAVE:
			_on_sleep_save_slot_pressed(slot_index)

		MODE_NEW_GAME:
			_accept_new_game_slot(slot_index)

		MODE_LOAD_GAME:
			_accept_load_slot(slot_index)

func _on_sleep_save_slot_pressed(slot_index: int) -> void:
	if slot_index == SLOT_AUTOSAVE:
		return

	if save_manager == null:
		_accept_sleep_save_slot(slot_index)
		return

	if save_manager.has_slot_save(slot_index):
		pending_overwrite_slot = slot_index
		pending_delete_slot = -1
		confirm_action = CONFIRM_OVERWRITE

		confirm_label.text = (
			"Manual Slot %d already has a save file.\n"
			+ "Overwrite this save?"
		) % slot_index

		confirm_yes_button.text = "YES, OVERWRITE"
		confirm_no_button.text = "CANCEL"

		confirm_panel.visible = true
		return

	_accept_sleep_save_slot(slot_index)

func _on_delete_slot_pressed(slot_index: int) -> void:
	if save_manager == null:
		return

	if not save_manager.has_slot_save(slot_index):
		_refresh_slot_buttons()
		return

	pending_delete_slot = slot_index
	pending_overwrite_slot = -1
	confirm_action = CONFIRM_DELETE

	var slot_name: String = save_manager.get_slot_display_name(slot_index)

	confirm_label.text = (
		"Delete %s?\n"
		+ "This cannot be undone."
	) % slot_name

	confirm_yes_button.text = "YES, DELETE"
	confirm_no_button.text = "CANCEL"

	confirm_panel.visible = true

func _accept_sleep_save_slot(manual_slot_index: int) -> void:
	close_save_menu(true)
	save_slot_selected.emit(manual_slot_index)

func _accept_new_game_slot(slot_index: int) -> void:
	close_save_menu(false)
	new_game_slot_selected.emit(slot_index)

func _accept_load_slot(slot_index: int) -> void:
	close_save_menu(false)
	load_slot_selected.emit(slot_index)

func _on_cancel_pressed() -> void:
	var cancelled_mode: String = current_mode

	close_save_menu(cancelled_mode == MODE_SLEEP_SAVE)

	save_slot_cancelled.emit()
	slot_menu_cancelled.emit(cancelled_mode)

func _on_confirm_yes_pressed() -> void:
	match confirm_action:
		CONFIRM_OVERWRITE:
			_confirm_overwrite_slot()

		CONFIRM_DELETE:
			_confirm_delete_slot()

		_:
			confirm_panel.visible = false

func _confirm_overwrite_slot() -> void:
	if pending_overwrite_slot < SLOT_1:
		_reset_confirmation()
		return

	var selected_slot: int = pending_overwrite_slot

	_reset_confirmation()
	_accept_sleep_save_slot(selected_slot)

func _confirm_delete_slot() -> void:
	if pending_delete_slot < SLOT_AUTOSAVE:
		_reset_confirmation()
		return

	if save_manager == null:
		_reset_confirmation()
		return

	var slot_to_delete: int = pending_delete_slot
	var deleted_successfully: bool = false

	if save_manager.has_method("delete_slot_save"):
		deleted_successfully = bool(
			save_manager.call("delete_slot_save", slot_to_delete)
		)

	_reset_confirmation()
	_refresh_slot_buttons()

	if deleted_successfully:
		slot_deleted.emit(slot_to_delete)

func _on_confirm_no_pressed() -> void:
	_reset_confirmation()

func _reset_confirmation() -> void:
	pending_overwrite_slot = -1
	pending_delete_slot = -1
	confirm_action = CONFIRM_NONE

	confirm_panel.visible = false
