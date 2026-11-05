class_name CompositeCondition
extends QuestCondition

## Verknüpft mehrere Bedingungen logisch miteinander (AND = Alle, OR = Mindestens eine).

enum Mode {
	AND = 0, ## Alle Unterbedingungen müssen erfüllt sein
	OR = 1   ## Mindestens eine Unterbedingung muss erfüllt sein
}

@export var mode: Mode = Mode.AND
@export var conditions: Array[QuestCondition] = []

func is_met(quest_manager: Node) -> bool:
	if conditions.is_empty():
		return true
		
	if mode == Mode.AND:
		for cond in conditions:
			if cond and not cond.is_met(quest_manager):
				return false
		return true
	else: # Mode.OR
		for cond in conditions:
			if cond and cond.is_met(quest_manager):
				return true
		return false
