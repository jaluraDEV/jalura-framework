@tool
class_name QuestCondition
extends Resource
## Basisklasse für Voraussetzungen. Neue Bedingungen = neues Script, das is_met() überschreibt.

func is_met(_quest_manager: Node) -> bool:
	return true
