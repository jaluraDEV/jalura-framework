@tool
class_name ObjExit
extends InteractiveObject

## Vorlage für Szenenausgänge (Türen, Tore, Übergangszonen, Wege).
## Exponiert Zielszene, Zielspawn, Modus, Prompts, Schlösser und Bedingungen
## direkt am Wurzel-Node im Inspector (Wurzel-Inspector-Prinzip).

@export_group("Scene Transition Target")
@export var transition_mode: TransitionBehavior.TransitionMode = TransitionBehavior.TransitionMode.INTERACT:
	set(val):
		transition_mode = val
		_sync_exit_properties()

@export var target_scene_id: StringName = &"":
	set(val):
		target_scene_id = val
		_sync_exit_properties()
		update_configuration_warnings()

@export var target_spawn_id: StringName = &"":
	set(val):
		target_spawn_id = val
		_sync_exit_properties()

@export_group("Lock & Conditions")
@export var is_locked: bool = false:
	set(val):
		is_locked = val
		_sync_exit_properties()

@export var key_item: ItemData = null:
	set(val):
		key_item = val
		if key_item and key_item_id.is_empty():
			key_item_id = key_item.id
		_sync_exit_properties()

@export var key_item_id: String = "":
	set(val):
		key_item_id = val
		_sync_exit_properties()

@export var consume_key: bool = false:
	set(val):
		consume_key = val
		_sync_exit_properties()

@export var lock_conditions: Array[QuestCondition] = []:
	set(val):
		lock_conditions = val.duplicate(true)
		_sync_exit_properties()

@export var locked_message: String = "Hier geht es gerade nicht weiter.":
	set(val):
		locked_message = val
		_sync_exit_properties()

@export var unlock_prompt: String = "Unlock":
	set(val):
		unlock_prompt = val
		_sync_exit_properties()

@export_group("Prompts & Zone")
@export var prompt_text: String = "Enter":
	set(val):
		prompt_text = val
		_sync_exit_properties()

@export var zone_size: Vector3 = Vector3(2.5, 2.0, 1.5):
	set(val):
		zone_size = val
		_sync_zone_size()

func _ready() -> void:
	lock_conditions = lock_conditions.duplicate(true)
	_sync_exit_properties()
	_sync_zone_size()
	super._ready()

func _sync_exit_properties() -> void:
	var tb := find_child("TransitionBehavior", true, false) as TransitionBehavior
	if tb:
		tb.transition_mode = transition_mode
		tb.target_scene_id = target_scene_id
		tb.target_spawn_id = target_spawn_id
		tb.is_locked = is_locked
		tb.key_item = key_item
		tb.key_item_id = key_item_id
		tb.consume_key = consume_key
		tb.lock_conditions = lock_conditions.duplicate(true)
		tb.locked_message = locked_message
		tb.unlock_prompt = unlock_prompt
		tb.prompt_text = prompt_text
		refresh_prompt()

func is_exit_locked() -> bool:
	var tb := find_child("TransitionBehavior", true, false) as TransitionBehavior
	return tb.is_exit_locked() if tb else is_locked

func _sync_zone_size() -> void:
	var area := find_child("TriggerArea", true, false) as Area3D
	if area:
		var col_shape := area.find_child("CollisionShape3D", false, false) as CollisionShape3D
		if col_shape and col_shape.shape is BoxShape3D:
			(col_shape.shape as BoxShape3D).size = zone_size
			col_shape.position = Vector3(0, zone_size.y * 0.5, 0)
		var debug_mesh := area.find_child("ZoneDebugMesh", false, false) as MeshInstance3D
		if debug_mesh and debug_mesh.mesh is BoxMesh:
			(debug_mesh.mesh as BoxMesh).size = zone_size
			debug_mesh.position = Vector3(0, zone_size.y * 0.5, 0)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if target_scene_id.is_empty():
		warnings.append("Dieser Ausgang hat keine 'target_scene_id'. Er weiß nicht, wohin der Übergang führen soll.")
	if not key_item_id.is_empty() and not is_locked:
		warnings.append("Schlüssel '%s' zugewiesen, aber 'is_locked' ist deaktiviert." % key_item_id)
	return warnings
