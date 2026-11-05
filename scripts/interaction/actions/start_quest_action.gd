class_name StartQuestAction
extends ReactionAction

## Aktion: Startet eine Quest über den QuestManager.

@export var quest_id: String = ""

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
	if qm and qm.has_method("start_quest"):
		qm.call("start_quest", quest_id)
