@tool
class_name QuestCompletedCondition
extends QuestCondition
## Erfüllt, wenn eine bestimmte Quest abgeschlossen ist (z.B. "help_oma_hildegard" oder "q_apple_for_grantelbart")

@export var quest_id: String = ""

func is_met(context: Node = null) -> bool:
	if quest_id.is_empty():
		return true
	var qm: Node = null
	if context and context.has_method("is_quest_completed"):
		qm = context
	elif context and context.get_node_or_null("/root/QuestManager"):
		qm = context.get_node_or_null("/root/QuestManager")
	elif Engine.has_singleton("QuestManager"):
		qm = Engine.get_singleton("QuestManager")
	elif context and context.get_tree():
		qm = context.get_tree().root.get_node_or_null("QuestManager")
	elif Engine.get_main_loop() is SceneTree:
		var st := Engine.get_main_loop() as SceneTree
		if st.root:
			qm = st.root.get_node_or_null("QuestManager")
		
	if qm and qm.has_method("is_quest_completed"):
		var id_raw := quest_id
		var id_stripped := quest_id.trim_prefix("q_")
		var id_prefixed := "q_" + quest_id if not quest_id.begins_with("q_") else quest_id
		return qm.is_quest_completed(id_raw) or qm.is_quest_completed(id_stripped) or qm.is_quest_completed(id_prefixed)
	return false
