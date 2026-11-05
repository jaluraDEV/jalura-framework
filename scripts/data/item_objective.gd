@tool
class_name ItemObjective
extends QuestObjective

## Ziel: Sammle oder besitze eine bestimmte Anzahl eines Items.

@export var item_id: String = ""
@export var consume_on_turn_in: bool = true ## Ob dieses Item bei Abgabe eingezogen wird
