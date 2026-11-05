@tool
class_name ObjSign
extends InteractiveObject

## Vorlage für Hinweisschilder.
## Exponiert wichtige Baustein-Einstellungen direkt auf dem Wurzel-Node im Inspector,
## sodass diese ohne "Editable Children" bearbeitet werden können.
## Leitet Title, Lines und Prompt-Text an das untergeordnete ReadableBehavior weiter.

@export_group("Sign Content")
@export var title: String = "Hinweisschild":
	set(val):
		title = val
		_sync_readable_properties()

@export_multiline var lines: Array[String] = ["Hier steht ein wichtiger Hinweis."]:
	set(val):
		var typed_lines: Array[String] = []
		for item in val:
			typed_lines.append(str(item))
		lines = typed_lines
		_sync_readable_properties()

@export_group("Sign Interaction")
@export var prompt_text: String = "Read":
	set(val):
		prompt_text = val
		_sync_readable_properties()

func _ready() -> void:
	lines = lines.duplicate()
	super._ready()
	_sync_readable_properties()

func _sync_readable_properties() -> void:
	var readable := find_child("ReadableBehavior", false, false) as ReadableBehavior
	if readable:
		readable.title = title
		readable.lines = lines.duplicate()
		readable.prompt_text = prompt_text
		refresh_prompt()
