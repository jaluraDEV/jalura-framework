class_name ObjectTrigger
extends Resource

## Daten-Ressource für Auslöser (Trigger) an Weltobjekten.
## WICHTIG: ObjectTrigger ist zustandslos! Der Ausführungszustand (z. B. 'once')
## wird ausschließlich im InteractiveObject-Hub der jeweiligen Instanz gespeichert.

@export var trigger_id: String = "" ## Optionaler Bezeichner für Savegame-Tracking (falls leer, wird Index genutzt)
@export_enum("read", "opened", "closed", "emptied", "picked_up", "shaken", "depleted", "inventory_full", "pushed", "pulled", "activated", "deactivated", "toggled", "talked", "unlocked", "unlock_failed", "wobbled", "custom") var event: String = "read"
@export var custom_event_name: StringName = &"" ## Nur wirksam, wenn 'custom' oben gewählt ist
@export var conditions: Array[QuestCondition] = [] ## Bedingungen (z.B. ItemCondition, FlagCondition)
@export var actions: Array[ReactionAction] = [] ## Auszuführende Reaktionen
@export var once: bool = false ## Darf pro Spielstand nur ein einziges Mal ausgelöst werden

func get_effective_event_name() -> StringName:
	if event == "custom" and not custom_event_name.is_empty():
		return custom_event_name
	return StringName(event)
