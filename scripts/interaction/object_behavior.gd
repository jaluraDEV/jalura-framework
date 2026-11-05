@tool
class_name ObjectBehavior
extends Node

## Basisklasse für modulare Bausteine eines InteractiveObject.
## Bausteine definieren, was mit einem Objekt gemacht werden kann (z. B. Lesen, Öffnen, Schütteln).

signal state_changed

var hub: Node # Typ InteractiveObject (wird dynamisch aufgelöst)

func _ready() -> void:
	_resolve_hub()

func _resolve_hub() -> void:
	if not hub:
		var p := get_parent()
		while p:
			if p.has_method("emit_object_event") or p is InteractiveObject:
				hub = p
				break
			p = p.get_parent()

## Führt die Interaktion aus. Gibt true zurück, wenn die Interaktion erfolgreich behandelt wurde.
func interact(_player: Node) -> bool:
	return false

## Prüft, ob dieser Baustein aktuell mit dem Spieler interagieren kann.
func can_interact(_player: Node) -> bool:
	return true

## Das Verb für den Interaktionsprompt (z. B. "Lesen", "Öffnen", "Ziehen").
func get_prompt() -> String:
	return ""

## Höhere Priorität gewinnt, wenn mehrere Bausteine can_interact == true liefern.
func get_priority() -> int:
	return 0

## Speichert den aktuellen Zustand des Bausteins (z. B. "is_open", "has_read").
func get_save_state() -> Dictionary:
	return {}

## Stellt den gespeicherten Zustand wieder her.
func load_save_state(_state: Dictionary) -> void:
	pass

## Informiert den Hub über eine Zustandsänderung, damit der Prompt sofort aktualisiert wird.
func notify_state_changed() -> void:
	state_changed.emit()
	if hub and hub.has_method("refresh_prompt"):
		hub.call("refresh_prompt")

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	_resolve_hub()
	if not hub:
		warnings.append("ObjectBehavior benötigt ein übergeordnetes InteractiveObject (Hub).")
	return warnings
