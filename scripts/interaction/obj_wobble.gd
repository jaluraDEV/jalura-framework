@tool
class_name ObjWobble
extends InteractiveObject

## Vorlage für dekorative Wackel-Objekte (ObjWobble / Fässer, Büsche, Poller).
## Exponiert wichtige Einstellungen direkt auf dem Wurzel-Node im Inspector.
## Leitet Eigenschaften an das untergeordnete WobbleBehavior weiter.

@export_group("Wobble Properties")
@export var wobble_angle: float = 14.0:
	set(val):
		wobble_angle = val
		_sync_wobble_properties()

@export var wobble_duration: float = 0.45:
	set(val):
		wobble_duration = val
		_sync_wobble_properties()

@export var wobble_on_contact: bool = true:
	set(val):
		wobble_on_contact = val
		_sync_wobble_properties()

@export_group("Visual Feedback")
@export var enable_focus_highlight: bool = false:
	set(val):
		enable_focus_highlight = val
		_sync_wobble_properties()

@export_group("Interaction")
@export var can_interact_with_key: bool = true:
	set(val):
		can_interact_with_key = val
		_sync_wobble_properties()

@export var prompt_text: String = "Nudge":
	set(val):
		prompt_text = val
		_sync_wobble_properties()

func _ready() -> void:
	super._ready()
	_sync_wobble_properties()

func _sync_wobble_properties() -> void:
	var wb := get_wobble_behavior()
	if wb:
		wb.wobble_angle = wobble_angle
		wb.wobble_duration = wobble_duration
		wb.wobble_on_contact = wobble_on_contact
		wb.can_interact_with_key = can_interact_with_key
		wb.prompt_text = prompt_text
		refresh_prompt()
	var fb := find_child("ObjectFeedback", false, false) as ObjectFeedback
	if fb:
		fb.enable_focus_highlight = enable_focus_highlight

func get_wobble_behavior() -> WobbleBehavior:
	return find_child("WobbleBehavior", false, false) as WobbleBehavior

func wobble(angle_deg: float = 0.0, from_source: Node = null) -> void:
	var wb := get_wobble_behavior()
	if wb:
		wb.wobble(angle_deg, from_source)
