class_name QuestCountCondition
extends QuestCondition
## Erfüllt, wenn insgesamt mindestens X Quests abgeschlossen wurden

@export var min_completed: int = 1

func is_met(context: Node = null) -> bool:
	var qm: Node = null
	if context and context.has_method("get_completed_quest_count"):
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
		
	if qm and qm.has_method("get_completed_quest_count"):
		return qm.get_completed_quest_count() >= min_completed
	return false
