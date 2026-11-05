@tool
class_name ObjChest
extends InteractiveObject

## Vorlage für Truhen und Behälter (Kisten, Schränke, Beete).
## Exponiert wichtige Baustein-Einstellungen direkt auf dem Wurzel-Node im Inspector,
## sodass diese ohne "Editable Children" bearbeitet werden können.
## Leitet Inhalt, Schloss-Bedingungen und Prompts an das untergeordnete ContainerBehavior weiter.
@export_group("Chest Contents")
## Liste der enthaltenen Items als Dictionaries, z. B. [{"item_id": "apple", "amount": 2}]
@export var contents: Array = []:
	set(val):
		var typed: Array[Dictionary] = []
		for item in val:
			if item is Dictionary:
				typed.append((item as Dictionary).duplicate(true))
		contents = typed
		_sync_container_properties()

var is_empty: bool:
	get:
		var cb := find_child("ContainerBehavior", false, false) as ContainerBehavior
		return cb.is_empty if cb else contents.is_empty()

var is_open: bool:
	get:
		var cb := find_child("ContainerBehavior", false, false) as ContainerBehavior
		return cb.is_open if cb else false



@export_group("Lock & Key")
@export var is_locked: bool = false:
	set(val):
		is_locked = val
		_sync_container_properties()

@export var lock_conditions: Array[QuestCondition] = []:
	set(val):
		lock_conditions = val.duplicate(true)
		_sync_container_properties()

@export var key_item_id: String = "":
	set(val):
		key_item_id = val
		_sync_container_properties()

@export var consume_key: bool = false:
	set(val):
		consume_key = val
		_sync_container_properties()

@export var locked_message: String = "Locked. You need a matching key!":
	set(val):
		locked_message = val
		_sync_container_properties()

@export_group("Prompts & Text")
@export var open_prompt: String = "Open":
	set(val):
		open_prompt = val
		_sync_container_properties()

@export var unlock_prompt: String = "Unlock":
	set(val):
		unlock_prompt = val
		_sync_container_properties()

@export var empty_prompt: String = "Inspect":
	set(val):
		empty_prompt = val
		_sync_container_properties()

@export var loot_prompt: String = "Take":
	set(val):
		loot_prompt = val
		_sync_container_properties()

@export_group("Container Mode")
@export var container_mode: ContainerBehavior.ContainerMode = ContainerBehavior.ContainerMode.CHEST:
	set(val):
		container_mode = val
		_sync_container_properties()

func _ready() -> void:
	contents = contents.duplicate(true)
	lock_conditions = lock_conditions.duplicate(true)
	super._ready()
	_sync_container_properties()

func _sync_container_properties() -> void:
	var container := find_child("ContainerBehavior", false, false) as ContainerBehavior
	if container:
		container.contents = contents.duplicate(true)
		container.is_locked = is_locked
		container.lock_conditions = lock_conditions.duplicate(true)
		container.key_item_id = key_item_id
		container.consume_key = consume_key
		container.locked_message = locked_message
		container.open_prompt = open_prompt
		container.unlock_prompt = unlock_prompt
		container.empty_prompt = empty_prompt
		container.loot_prompt = loot_prompt
		container.container_mode = container_mode
		refresh_prompt()
