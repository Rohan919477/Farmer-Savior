extends Label
class_name EnemyCountLabel

var spawn_manager: Node = null
var time_manager: Node = null
var map_manager: Node = null

var last_enemy_count: int = -1
var last_visible_state: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	visible = false

	call_deferred("_find_managers")

func _process(_delta: float) -> void:
	if (
		spawn_manager == null
		or time_manager == null
		or map_manager == null
	):
		_find_managers()

	var should_show: bool = _should_show_counter()

	if visible != should_show:
		visible = should_show
		last_visible_state = should_show

	if not should_show:
		return

	if spawn_manager == null:
		text = "Enemies Left: 0"
		return

	if not spawn_manager.has_method("get_active_enemy_count"):
		return

	var active_enemy_count: int = int(
		spawn_manager.call("get_active_enemy_count")
	)

	if active_enemy_count == last_enemy_count:
		return

	last_enemy_count = active_enemy_count
	text = "Enemies Left: %d" % active_enemy_count

func _find_managers() -> void:
	if spawn_manager == null:
		spawn_manager = get_tree().get_first_node_in_group(
			"spawn_manager"
		)

	if time_manager == null:
		time_manager = get_tree().get_first_node_in_group(
			"time_manager"
		)

	if map_manager == null:
		map_manager = get_tree().get_first_node_in_group(
			"map_manager"
		)

func _should_show_counter() -> bool:
	if time_manager == null:
		return false

	if not time_manager.has_method("is_nighttime"):
		return false

	var is_night: bool = bool(
		time_manager.call("is_nighttime")
	)

	if not is_night:
		return false

	if map_manager == null:
		return true

	var location_id: String = str(
		map_manager.get("current_location_id")
	)

	return location_id == "farm"
