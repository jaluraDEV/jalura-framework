class_name PlaySoundAction
extends ReactionAction

## Aktion: Spielt einen AudioStream ab.

@export var sound: AudioStream
@export var volume_db: float = 0.0

func execute(ctx: Dictionary) -> void:
	if not sound:
		return
	var hub: Node = ctx.get("hub")
	if not hub or not hub.is_inside_tree():
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = sound
	player.volume_db = volume_db
	hub.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
