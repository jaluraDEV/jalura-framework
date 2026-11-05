@tool
class_name FlagCondition
extends QuestCondition

## Bedingung: Prüft, ob ein Story-Flag in GameFlags gesetzt (oder nicht gesetzt) ist.

@export var flag_id: String = ""
@export var expected_value: bool = true ## True = Flag muss gesetzt sein, False = Flag darf nicht gesetzt sein

func is_met(_context: Node = null) -> bool:
	if flag_id.is_empty():
		return true
	var gf: Node = null
	if _context and _context.is_inside_tree():
		gf = _context.get_node_or_null("/root/GameFlags")
		if not gf and _context.get_tree():
			gf = _context.get_tree().root.get_node_or_null("GameFlags")
	if not gf and Engine.has_singleton("GameFlags"):
		gf = Engine.get_singleton("GameFlags")
		
	if gf and gf.has_method("has_flag"):
		var val: bool = gf.call("has_flag", flag_id)
		return val == expected_value
	return not expected_value
