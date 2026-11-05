class_name ActivateTargetAction
extends ReactionAction

## Aktion: Ruft activate(), deactivate() oder toggle() an einem Zielknoten auf.

@export var target_path: NodePath
@export_enum("activate", "deactivate", "toggle") var method: String = "activate"

func execute(ctx: Dictionary) -> void:
	if target_path.is_empty():
		return
	var hub: Node = ctx.get("hub")
	if not hub:
		return
	var target = hub.get_node_or_null(target_path)
	if not target and hub.get_tree():
		target = hub.get_tree().root.get_node_or_null(target_path)
	if target and target.has_method(method):
		target.call(method)
