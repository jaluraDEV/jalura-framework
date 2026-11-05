class_name ShowTextAction
extends ReactionAction

## Aktion: Öffnet eine Text-/Dialogbox über das HUD-System.

@export var speaker: String = ""
@export_multiline var lines: Array[String] = []

func execute(ctx: Dictionary) -> void:
	if lines.is_empty():
		return
	var hub: Node = ctx.get("hub")
	var hud: Node = null
	if hub and hub.get_tree():
		hud = hub.get_tree().root.find_child("HUD", true, false)
	if hud and hud.has_method("start_dialogue"):
		hud.call("start_dialogue", speaker, lines)
