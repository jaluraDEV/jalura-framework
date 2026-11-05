class_name SetFlagAction
extends ReactionAction

## Aktion: Setzt oder löscht ein Story-Flag in GameFlags.

@export var flag_id: String = ""
@export var value: bool = true

func execute(ctx: Dictionary) -> void:
	if flag_id.is_empty():
		return
	var hub: Node = ctx.get("hub")
	var gf: Node = null
	if hub:
		gf = hub.get_node_or_null("/root/GameFlags")
		if not gf and hub.get_tree():
			gf = hub.get_tree().root.get_node_or_null("GameFlags")
	if not gf and Engine.has_singleton("GameFlags"):
		gf = Engine.get_singleton("GameFlags")
	if gf and gf.has_method("set_flag"):
		gf.call("set_flag", flag_id, value)
