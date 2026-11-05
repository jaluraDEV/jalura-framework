@tool
class_name ObjSwitch
extends InteractiveObject

## Vorlage für Hebel, Schalter und Druckknöpfe (ObjSwitch / ObjLever).
## Exponiert wichtige Baustein-Einstellungen direkt auf dem Wurzel-Node im Inspector,
## sodass diese ohne "Editable Children" konfiguriert werden können.
## Leitet Modus, Ziele und Prompts an das untergeordnete SwitchBehavior weiter.
@export_group("Switch Mode")
@export var switch_mode: SwitchBehavior.SwitchMode = SwitchBehavior.SwitchMode.TOGGLE:
	set(val):
		switch_mode = val
		_sync_switch_properties()

var _is_active: bool = false
@export var is_active: bool = false:
	get:
		var sw := find_child("SwitchBehavior", false, false) as SwitchBehavior
		return sw.is_active if sw else _is_active
	set(val):
		_is_active = val
		_sync_switch_properties()

@export var timed_duration: float = 5.0:
	set(val):
		timed_duration = val
		_sync_switch_properties()

@export var can_player_interact: bool = true:
	set(val):
		can_player_interact = val
		_sync_switch_properties()

@export_group("Targets & Remote Control")
@export var target_objects: Array[NodePath] = []:
	set(val):
		target_objects = val.duplicate()
		_sync_switch_properties()

@export var target_method: String = "toggle":
	set(val):
		target_method = val
		_sync_switch_properties()

@export var call_deactivate_on_off: bool = true:
	set(val):
		call_deactivate_on_off = val
		_sync_switch_properties()

@export_group("Prompts & Text")
@export var activate_prompt: String = "Activate":
	set(val):
		activate_prompt = val
		_sync_switch_properties()

@export var deactivate_prompt: String = "Reset":
	set(val):
		deactivate_prompt = val
		_sync_switch_properties()

@export var already_active_prompt: String = "":
	set(val):
		already_active_prompt = val
		_sync_switch_properties()

@export_group("Toast Feedback")
@export var activate_toast_message: String = "":
	set(val):
		activate_toast_message = val
		_sync_switch_properties()

func _ready() -> void:
	target_objects = target_objects.duplicate()
	super._ready()
	_sync_switch_properties()

func _sync_switch_properties() -> void:
	var sw := find_child("SwitchBehavior", false, false) as SwitchBehavior
	if sw:
		sw.switch_mode = switch_mode
		sw.is_active = _is_active
		sw.timed_duration = timed_duration
		sw.can_player_interact = can_player_interact
		sw.target_objects = target_objects.duplicate()
		sw.target_method = target_method
		sw.call_deactivate_on_off = call_deactivate_on_off
		sw.activate_prompt = activate_prompt
		sw.deactivate_prompt = deactivate_prompt
		sw.already_active_prompt = already_active_prompt
		sw.activate_toast_message = activate_toast_message
		refresh_prompt()

## Öffentliche Steuerungsmethoden
func activate(animate: bool = true, player: Node = null) -> void:
	var sw := find_child("SwitchBehavior", false, false) as SwitchBehavior
	if sw:
		sw.activate(animate, player)

func deactivate(animate: bool = true, player: Node = null) -> void:
	var sw := find_child("SwitchBehavior", false, false) as SwitchBehavior
	if sw:
		sw.deactivate(animate, player)

func toggle(animate: bool = true, player: Node = null) -> void:
	var sw := find_child("SwitchBehavior", false, false) as SwitchBehavior
	if sw:
		sw.toggle(animate, player)
