@tool
class_name ItemCondition
extends QuestCondition

## Erfüllt, wenn der Spieler eine bestimmte Anzahl eines Items im Inventar hat.

@export var item_id: String = ""
@export var required_count: int = 1

func is_met(_quest_manager: Node = null) -> bool:
	if item_id.is_empty():
		return true
	var inv: Node = null
	if _quest_manager:
		inv = _quest_manager.get_node_or_null("/root/InventoryManager")
		if not inv and _quest_manager.get_tree():
			inv = _quest_manager.get_tree().root.get_node_or_null("InventoryManager")
	if not inv and Engine.has_singleton("InventoryManager"):
		inv = Engine.get_singleton("InventoryManager")
	if not inv:
		return false
	return inv.has_item(item_id, required_count)
