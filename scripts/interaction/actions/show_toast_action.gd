class_name ShowToastAction
extends ReactionAction

## Action: Displays a toast message on the HUD.

@export var badge: String = "✨"
@export var title: String = "HINWEIS"
@export var text: String = ""
@export var color: Color = Color(1.0, 0.85, 0.4)

func execute(ctx: Dictionary) -> void:
	var hub: Node = ctx.get("hub")
	var hud: Node = null
	if hub and hub.get_tree():
		hud = hub.get_tree().root.find_child("HUD", true, false)
	if not hud:
		var player: Node = ctx.get("player")
		if player and player.get_tree():
			hud = player.get_tree().root.find_child("HUD", true, false)
	if not hud:
		var source: Node = ctx.get("source")
		if source and source.get_tree():
			hud = source.get_tree().root.find_child("HUD", true, false)
	if not hud and Engine.get_main_loop() is SceneTree:
		var st := Engine.get_main_loop() as SceneTree
		if st.root:
			hud = st.root.find_child("HUD", true, false)

	if hud and hud.has_method("show_toast"):
		hud.call("show_toast", badge, title, text, color)
	else:
		push_warning("ShowToastAction: HUD nicht gefunden oder besitzt keine show_toast Methode.")
