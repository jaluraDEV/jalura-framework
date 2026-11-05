@tool
class_name ObjPressurePlate
extends InteractiveObject

## Vorlage für Boden-Druckplatten (ObjPressurePlate).
## Exponiert wichtige Baustein-Einstellungen direkt auf dem Wurzel-Node im Inspector,
## sodass diese ohne "Editable Children" konfiguriert werden können.
## Leitet Modus, Filter und Ziele an das untergeordnete PressurePlateBehavior weiter.
@export_group("Plate Mode")
@export var plate_mode: PressurePlateBehavior.PlateMode = PressurePlateBehavior.PlateMode.HOLD:
	set(val):
		plate_mode = val
		_sync_plate_properties()

var _is_pressed: bool = false
@export var is_pressed: bool = false:
	get:
		var pb := find_child("PressurePlateBehavior", false, false) as PressurePlateBehavior
		return pb.is_pressed if pb else _is_pressed
	set(val):
		_is_pressed = val
		_sync_plate_properties()

@export var timed_duration: float = 4.0:
	set(val):
		timed_duration = val
		_sync_plate_properties()

@export_group("Filter & Detection")
@export var trigger_by_player: bool = true:
	set(val):
		trigger_by_player = val
		_sync_plate_properties()

@export var trigger_by_blocks: bool = true:
	set(val):
		trigger_by_blocks = val
		_sync_plate_properties()

@export_group("Targets & Remote Control")
@export var target_objects: Array[NodePath] = []:
	set(val):
		target_objects = val.duplicate()
		_sync_plate_properties()

@export var target_method: String = "activate":
	set(val):
		target_method = val
		_sync_plate_properties()

@export var call_deactivate_on_release: bool = true:
	set(val):
		call_deactivate_on_release = val
		_sync_plate_properties()

@export_group("Toast Feedback")
@export var activate_toast_message: String = "":
	set(val):
		activate_toast_message = val
		_sync_plate_properties()

@export var deactivate_toast_message: String = "":
	set(val):
		deactivate_toast_message = val
		_sync_plate_properties()

func _ready() -> void:
	target_objects = target_objects.duplicate()
	super._ready()
	_sync_plate_properties()

func _sync_plate_properties() -> void:
	var pb := find_child("PressurePlateBehavior", false, false) as PressurePlateBehavior
	if pb:
		pb.plate_mode = plate_mode
		pb.is_pressed = _is_pressed
		pb.timed_duration = timed_duration
		pb.trigger_by_player = trigger_by_player
		pb.trigger_by_blocks = trigger_by_blocks
		pb.target_objects = target_objects.duplicate()
		pb.target_method = target_method
		pb.call_deactivate_on_release = call_deactivate_on_release
		pb.activate_toast_message = activate_toast_message
		pb.deactivate_toast_message = deactivate_toast_message

func press(animate: bool = true) -> void:
	var pb := find_child("PressurePlateBehavior", false, false) as PressurePlateBehavior
	if pb:
		pb.press(animate)

func release(animate: bool = true) -> void:
	var pb := find_child("PressurePlateBehavior", false, false) as PressurePlateBehavior
	if pb:
		pb.release(animate)
