@tool
class_name QuestData
extends Resource

## Fully data-driven quest definition.
## Kann als .tres-Datei im Ordner res://resources/quests/ (auch in Unterordnern)
## abgelegt werden und wird vom QuestManager automatisch registriert.

enum QuestState {
	NOT_STARTED = 0,
	ACTIVE = 1,
	COMPLETED = 2,
	READY_TO_TURN_IN = 3
}

enum QuestCategory {
	MAIN = 0,       ## Hauptgeschichte
	SIDE = 1,       ## Nebenaufgabe
	DISCOVERY = 2   ## Insel-Geheimnis / Erkundung
}

@export_group("Basic Info")
@export var id: String = ""              ## Eindeutige ID. Wenn leer, wird der Dateiname genutzt!
@export var title: String = ""
@export_multiline var description: String = ""
@export var category: QuestCategory = QuestCategory.SIDE

@export_group("Flow & Phases")
@export var sequential_objectives: bool = false ## Wenn true, werden Ziele nacheinander (schrittweise) freigeschaltet
@export var auto_start: bool = false            ## Startet sofort automatisch, wenn alle Voraussetzungen erfüllt sind

@export_group("Objectives")
@export var objectives: Array[QuestObjective] = []

@export_group("Rewards")
@export var coin_reward: int = 0         ## Münzen / Tickets
@export var energy_reward: int = 50      ## Energie / Batterien
@export var reward_item_id: String = ""  ## Primäres Belohnungs-Item
@export var reward_item_count: int = 1   ## Anzahl des primären Items
@export var reward_items: Dictionary = {} ## Optionale weitere Items: {"item_id": anzahl}

@export_group("Staging")
@export var completion_dance_duration: float = 4.5

# Abwärtskompatibilität für alte Einzel-Fetch-Quests
@export_group("Legacy Compatibility")
@export var target_item_id: String = ""
@export var target_item_count: int = 1

@export_group("NPC & Turn-In")
## Wer die Quest vergibt (muss zur npc_id am QuestGiver passen)
@export var giver_npc_id: String = ""
## Wer sie annimmt. Leer = derselbe NPC wie der Geber
@export var turn_in_npc_id: String = ""
## Reihenfolge, wenn ein NPC mehrere Quests hat (niedrig = zuerst)
@export var priority: int = 0
## Items beim Abgeben automatisch aus dem Inventar nehmen
@export var consume_items_on_turn_in: bool = true

@export_group("Prerequisites")
## ALLE müssen erfüllt sein, damit die Quest angeboten/gestartet wird
@export var prerequisites: Array[QuestCondition] = []

@export_group("Dialogues")
@export var offer_dialogue: Array[String] = []     # Quest wird angeboten
@export var reminder_dialogue: Array[String] = []  # Quest läuft, noch nicht fertig
@export var turn_in_dialogue: Array[String] = []   # Abgabe
@export var after_dialogue: Array[String] = []     # Danach, wenn man den NPC nochmal anspricht

func are_all_objectives_completed() -> bool:
	if objectives.is_empty():
		return true
	for obj in objectives:
		if not obj.optional and not obj.is_completed():
			return false
	return true

func get_active_objectives() -> Array[QuestObjective]:
	if not sequential_objectives:
		return objectives.duplicate()
	var active: Array[QuestObjective] = []
	for obj in objectives:
		if not obj.is_completed():
			active.append(obj)
			break # Nur das aktuelle Ziel ist aktiv
	return active

func get_current_objective() -> QuestObjective:
	var active := get_active_objectives()
	return active[0] if not active.is_empty() else null

func reset_objectives() -> void:
	for obj in objectives:
		obj.reset()

func get_objective_for_item(p_item_id: String) -> ItemObjective:
	for obj in get_active_objectives():
		if obj is ItemObjective and obj.item_id == p_item_id:
			return obj
	return null

func get_objective_for_location(p_location_id: String) -> LocationObjective:
	for obj in get_active_objectives():
		if obj is LocationObjective and obj.location_id == p_location_id:
			return obj
	return null

func get_objective_for_interact(p_interactable_id: String) -> InteractObjective:
	for obj in get_active_objectives():
		if obj is InteractObjective and obj.interactable_id == p_interactable_id:
			return obj
	return null

func get_objective_for_talk(p_npc_id: String) -> TalkObjective:
	for obj in get_active_objectives():
		if obj is TalkObjective and obj.npc_id == p_npc_id:
			return obj
	return null

func get_objective_for_event(p_event_name: String) -> CustomEventObjective:
	for obj in get_active_objectives():
		if obj is CustomEventObjective and obj.event_name == p_event_name:
			return obj
	return null
