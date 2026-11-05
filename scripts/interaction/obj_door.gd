@tool
class_name ObjDoor
extends InteractiveObject

## Vorlage für Türen und Tore (ObjDoor).
## Exponiert wichtige Baustein-Einstellungen direkt auf dem Wurzel-Node im Inspector,
## sodass diese ohne "Editable Children" bearbeitet werden können.
## Leitet Mechanik, Schloss-Bedingungen und Prompts an das untergeordnete DoorBehavior weiter.
@export_group("Door Mechanics")
@export var open_mode: DoorBehavior.OpenMode = DoorBehavior.OpenMode.ROTATE:
	set(val):
		open_mode = val
		_sync_door_properties()

@export var open_angle: float = 90.0:
	set(val):
		open_angle = val
		_sync_door_properties()

@export var slide_offset: Vector3 = Vector3(0.0, 2.5, 0.0):
	set(val):
		slide_offset = val
		_sync_door_properties()

@export var animation_duration: float = 0.55:
	set(val):
		animation_duration = val
		_sync_door_properties()

@export var can_player_interact: bool = true:
	set(val):
		can_player_interact = val
		_sync_door_properties()

@export var can_close: bool = true:
	set(val):
		can_close = val
		_sync_door_properties()

@export var auto_close: bool = false:
	set(val):
		auto_close = val
		_sync_door_properties()

@export var auto_close_delay: float = 3.0:
	set(val):
		auto_close_delay = val
		_sync_door_properties()

@export var disable_collision_when_open: bool = true:
	set(val):
		disable_collision_when_open = val
		_sync_door_properties()

var is_open: bool:
	get:
		var db := find_child("DoorBehavior", false, false) as DoorBehavior
		return db.is_open if db else false

@export_group("Lock & Key")
@export var is_locked: bool = false:
	set(val):
		is_locked = val
		_sync_door_properties()

@export var lock_conditions: Array[QuestCondition] = []:
	set(val):
		lock_conditions = val.duplicate(true)
		_sync_door_properties()

@export var key_item_id: String = "":
	set(val):
		key_item_id = val
		_sync_door_properties()

@export var consume_key: bool = false:
	set(val):
		consume_key = val
		_sync_door_properties()

@export var locked_message: String = "Locked. You need a matching key!":
	set(val):
		locked_message = val
		_sync_door_properties()

@export_group("Automatic Conditions")
@export var auto_open_conditions: Array[QuestCondition] = []:
	set(val):
		auto_open_conditions = val.duplicate(true)
		_sync_door_properties()

@export_group("Prompts & Text")
@export var open_prompt: String = "Open":
	set(val):
		open_prompt = val
		_sync_door_properties()

@export var close_prompt: String = "Close":
	set(val):
		close_prompt = val
		_sync_door_properties()

@export var unlock_prompt: String = "Unlock":
	set(val):
		unlock_prompt = val
		_sync_door_properties()

func _ready() -> void:
	lock_conditions = lock_conditions.duplicate(true)
	auto_open_conditions = auto_open_conditions.duplicate(true)
	super._ready()
	_sync_door_properties()

func _sync_door_properties() -> void:
	var door := find_child("DoorBehavior", false, false) as DoorBehavior
	if door:
		door.open_mode = open_mode
		door.open_angle = open_angle
		door.slide_offset = slide_offset
		door.animation_duration = animation_duration
		door.can_player_interact = can_player_interact
		door.can_close = can_close
		door.auto_close = auto_close
		door.auto_close_delay = auto_close_delay
		door.disable_collision_when_open = disable_collision_when_open
		door.is_locked = is_locked
		door.lock_conditions = lock_conditions.duplicate(true)
		door.auto_open_conditions = auto_open_conditions.duplicate(true)
		door.key_item_id = key_item_id
		door.consume_key = consume_key
		door.locked_message = locked_message
		door.open_prompt = open_prompt
		door.close_prompt = close_prompt
		door.unlock_prompt = unlock_prompt
		refresh_prompt()

## Öffentliche Steuerungsmethoden
func open(animate: bool = true, player: Node = null) -> void:
	var door := find_child("DoorBehavior", false, false) as DoorBehavior
	if door:
		door.open(animate, player)

func close(animate: bool = true, player: Node = null) -> void:
	var door := find_child("DoorBehavior", false, false) as DoorBehavior
	if door:
		door.close(animate, player)

func toggle(animate: bool = true, player: Node = null) -> void:
	var door := find_child("DoorBehavior", false, false) as DoorBehavior
	if door:
		door.toggle(animate, player)

func activate() -> void:
	open(true)

func deactivate() -> void:
	close(true)

func unlock(player: Node = null) -> void:
	var door := find_child("DoorBehavior", false, false) as DoorBehavior
	if door:
		door.unlock(player)

func lock() -> void:
	var door := find_child("DoorBehavior", false, false) as DoorBehavior
	if door:
		door.lock()
