@tool
class_name ObjSceneEvents
extends InteractiveObject

## Wurzel-Node für Szenen-Ereignisse (scene_entered, scene_first_entered).
## Erbt von InteractiveObject und erlaubt das einfache Anbinden von ObjectTriggern
## direkt im Inspector der Szenenwurzel.

@export_group("Scene Event Settings")
@export var auto_trigger: bool = true:
	set(val):
		auto_trigger = val
		_sync_behavior()

@export var delay_seconds: float = 0.05:
	set(val):
		delay_seconds = val
		_sync_behavior()

func _ready() -> void:
	collision_mode = CollisionMode.MANUAL
	super._ready()
	_sync_behavior()

func _sync_behavior() -> void:
	var beh = find_child("SceneEventsBehavior", false, false) as SceneEventsBehavior
	if beh:
		beh.auto_trigger = auto_trigger
		beh.delay_seconds = delay_seconds
