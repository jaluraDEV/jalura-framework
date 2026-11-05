class_name QuestGiver
extends Node
## Generische Komponente: als Child an jeden NPC hängen, npc_id setzen, fertig.
## Fragt den QuestManager, was der NPC gerade sagen soll und benachrichtigt ihn über Gespräche.

signal talk_started(player: Node)
signal talk_finished

@export var npc_id: String = ""
@export var display_name: String = "NPC"
@export var prompt_text: String = "Talk"
@export var interactable: Interactable
## Wenn keine Quest etwas zu sagen hat
@export var idle_dialogue: Array[String] = ["..."]

func _ready() -> void:
	if not interactable:
		interactable = get_parent().get_node_or_null("Interactable") as Interactable
	if interactable:
		interactable.prompt_text = prompt_text
		interactable.action_key = "E"
		if not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)

func _on_interacted(player: Node) -> void:
	var hud = get_tree().root.find_child("HUD", true, false)
	if not hud or hud.is_dialogue_active:
		return

	var qm = get_node_or_null("/root/QuestManager")
	var result: Dictionary = qm.get_npc_dialogue(npc_id) if qm else {}

	var lines: Array = result.get("lines", [])
	if lines.is_empty():
		lines = idle_dialogue
	var on_finished: Callable = result.get("on_finished", Callable())

	if qm and qm.has_method("notify_npc_talked"):
		qm.notify_npc_talked(npc_id)

	talk_started.emit(player)
	hud.start_dialogue(display_name, lines, func():
		if on_finished.is_valid():
			on_finished.call()
		talk_finished.emit()
	)
