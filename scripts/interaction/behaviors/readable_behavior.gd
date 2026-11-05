@tool
class_name ReadableBehavior
extends ObjectBehavior

## Baustein: Lesbar (z. B. für Schilder, Briefe, Anschlagtafeln).
## Öffnet beim Interagieren das HUD-Dialogsystem und feuert das Event "read".

@export_group("Contents")
@export var title: String = "Hinweisschild"
@export_multiline var lines: Array[String] = ["Hier steht ein wichtiger Hinweis."]:
	set(val):
		var typed_lines: Array[String] = []
		for item in val:
			typed_lines.append(str(item))
		lines = typed_lines
		notify_state_changed()

@export_group("Interaction")
@export var prompt_text: String = "Lesen":
	set(val):
		prompt_text = val
		notify_state_changed()

@export var priority: int = 10

var has_been_read: bool = false

func _ready() -> void:
	lines = lines.duplicate()

func can_interact(_player: Node) -> bool:
	return not lines.is_empty()

func get_prompt() -> String:
	return prompt_text

func get_priority() -> int:
	return priority

func interact(player: Node) -> bool:
	_resolve_hub()
	if lines.is_empty():
		return false
		
	var hud := get_tree().root.find_child("HUD", true, false)
	if not hud or not hud.has_method("start_dialogue"):
		return false
		
	if "is_dialogue_active" in hud and hud.is_dialogue_active:
		return false

	has_been_read = true
	
	hud.start_dialogue(title, lines, func():
		notify_state_changed()
	)

	if hub and hub.has_method("emit_object_event"):
		hub.call("emit_object_event", &"read", {"player": player, "source": self})
		
	return true

func get_save_state() -> Dictionary:
	return {
		"has_been_read": has_been_read
	}

func load_save_state(state: Dictionary) -> void:
	has_been_read = state.get("has_been_read", false)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super._get_configuration_warnings()
	if lines.is_empty():
		warnings.append("ReadableBehavior hat keine Textzeilen (lines).")
	return warnings
