class_name CompleteQuestAction
extends ReactionAction

## Aktion: Schließt eine Quest über den QuestManager ab.

@export var quest_id: String = ""

@export_group("Completion Options")
## Wenn aktiviert ("Ziele ignorieren"), wird die Quest forciert abgeschlossen, selbst wenn Quest-Ziele oder Items noch fehlen.
@export var force: bool = false

func execute(ctx: Dictionary) -> void:
	if quest_id.is_empty():
		return
	var hub: Node = ctx.get("hub")
	var qm: Node = null
	if hub:
		qm = hub.get_node_or_null("/root/QuestManager")
		if not qm and hub.get_tree():
			qm = hub.get_tree().root.get_node_or_null("QuestManager")
	if not qm and Engine.has_singleton("QuestManager"):
		qm = Engine.get_singleton("QuestManager")
	if qm and qm.has_method("complete_quest"):
		qm.call("complete_quest", quest_id, force)
