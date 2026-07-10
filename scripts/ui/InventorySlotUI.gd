extends Button
class_name InventorySlotUI

signal inventory_slot_pressed(slot_index: int)

@onready var item_label: Label = $ItemLabel
@onready var amount_label: Label = $AmountLabel

var absolute_slot_index: int = -1
var item_id: String = ""
var item_amount: int = 0
var slot_available: bool = false
var is_selected: bool = false

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	flat = true

	pressed.connect(_on_pressed)

	_refresh_visual()

func configure_slot(
	new_slot_index: int,
	slot_data: Dictionary,
	is_available: bool,
	selected: bool
) -> void:
	absolute_slot_index = new_slot_index
	slot_available = is_available
	is_selected = selected

	item_id = str(slot_data.get("item_id", ""))
	item_amount = int(slot_data.get("amount", 0))

	disabled = not slot_available

	_refresh_visual()

func _refresh_visual() -> void:
	if item_label == null or amount_label == null:
		return

	if not slot_available:
		item_label.text = ""
		amount_label.text = ""

	elif item_id.is_empty() or item_amount <= 0:
		item_label.text = ""
		amount_label.text = ""

	else:
		item_label.text = get_item_display_name(item_id)
		amount_label.text = str(item_amount)

	queue_redraw()

func _draw() -> void:
	var slot_rect: Rect2 = Rect2(Vector2.ZERO, size)

	var background_color: Color = Color(0.12, 0.12, 0.12)
	var border_color: Color = Color(0.52, 0.52, 0.52)

	if not slot_available:
		background_color = Color(0.06, 0.06, 0.06)
		border_color = Color(0.20, 0.20, 0.20)

	elif is_selected:
		background_color = Color(0.45, 0.35, 0.08)
		border_color = Color(1.0, 0.88, 0.35)

	elif not item_id.is_empty() and item_amount > 0:
		background_color = Color(0.18, 0.24, 0.18)
		border_color = Color(0.68, 0.78, 0.68)

	draw_rect(slot_rect, background_color)
	draw_rect(slot_rect, border_color, false, 2.0)

func get_item_display_name(raw_item_id: String) -> String:
	match raw_item_id:
		"seeds":
			return "SEED"
		"scrap":
			return "SCRAP"
		"mutant_seeds":
			return "MUTANT\nSEED"
		_:
			return raw_item_id.to_upper()

func _on_pressed() -> void:
	if not slot_available:
		return

	inventory_slot_pressed.emit(absolute_slot_index)
