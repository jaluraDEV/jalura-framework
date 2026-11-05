@tool
class_name SpawnPoint
extends Marker3D

## Repräsentiert einen Eingang bzw. Spawn-Punkt für Barnaby in einer Szene.
## Konvention: spawn_id nach Herkunft benennen (z.B. 'von_hafen', 'von_dorfplatz', 'von_garten').
## Die Ausrichtung (Rotation.y) bestimmt Barnabys Blickrichtung beim Erscheinen.

@export var spawn_id: StringName = &"":
	set(val):
		spawn_id = val
		update_configuration_warnings()

@export var is_default: bool = false:
	set(val):
		is_default = val
		update_configuration_warnings()

func _ready() -> void:
	add_to_group("spawn_points")

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if spawn_id.is_empty() and not is_default:
		warnings.append("Dieser SpawnPoint hat keine 'spawn_id' und ist nicht als 'is_default' markiert. Er kann von Ausgängen nicht gezielt angesteuert werden.")
	return warnings
