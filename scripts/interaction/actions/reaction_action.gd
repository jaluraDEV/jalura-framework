class_name ReactionAction
extends Resource

## Basisklasse für modulare Reaktionen (Aktionen), die durch ObjectTrigger ausgeführt werden.
## Parameter ctx enthält:
##   - "hub": InteractiveObject (der Hub des Objekts)
##   - "source": Node / ObjectBehavior (der auslösende Baustein)
##   - "player": Node (der Spieler, falls an Interaktion beteiligt)
##   - "event_name": StringName (Name des aufgetretenen Events)
##   - "data": Dictionary (optionale Nutzdaten des Events)

func execute(_ctx: Dictionary) -> void:
	pass
