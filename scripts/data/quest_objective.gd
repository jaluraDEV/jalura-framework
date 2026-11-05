@tool
class_name QuestObjective
extends Resource

## Basisklasse für alle Quest-Ziele (Objectives).
## Bietet Fortschritts-Tracking, Signale und modulare Erweiterbarkeit.

signal progress_changed(current: int, target: int)
signal completed

@export_group("Objective Properties")
@export var description: String = "Complete objective"
@export var target_amount: int = 1
@export var optional: bool = false            ## Optional bonus task
@export var hidden_until_active: bool = false ## Erst sichtbar, wenn an der Reihe

var current_amount: int = 0

func is_completed() -> bool:
	return current_amount >= target_amount

func add_progress(amount: int = 1) -> void:
	if is_completed():
		return
	current_amount = mini(current_amount + amount, target_amount)
	progress_changed.emit(current_amount, target_amount)
	if is_completed():
		completed.emit()

func set_progress(amount: int) -> void:
	current_amount = clamp(amount, 0, target_amount)
	progress_changed.emit(current_amount, target_amount)
	if is_completed():
		completed.emit()

func get_progress_text() -> String:
	return "%s (%d/%d)" % [description, current_amount, target_amount]

func reset() -> void:
	current_amount = 0
