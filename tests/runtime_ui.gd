extends SceneTree

## Hängt das HUD in einen echten Baum, damit _ready läuft, und öffnet das Inventar.
## Aufruf: godot --headless --path . -s res://tests/runtime_ui.gd

const HUD_SCENE: String = "res://scenes/ui/hud.tscn"


func _init() -> void:
	var packed := load(HUD_SCENE) as PackedScene
	if packed == null:
		printerr("HUD nicht ladbar")
		quit(1)
		return

	var hud := packed.instantiate()
	root.add_child(hud)

	await process_frame
	await process_frame

	print("HUD-Knoten: ", hud.get_class(), " Kinder: ", hud.get_child_count())

	var inv := hud.find_child("InventoryMenu", true, false)
	print("InventoryMenu gefunden: ", inv != null)
	if inv and inv.has_method("open_menu"):
		inv.call("open_menu")
		await process_frame
		print("Inventar geöffnet: ", inv.visible)
		inv.call("close_menu")

	hud.call("show_prompt", "Test", "E")
	hud.call("show_toast", "TEST", "Titel", "Text")
	await process_frame
	print("Prompt und Toast ohne Fehler")

	var pause := hud.find_child("PauseMenu", true, false)
	print("PauseMenu gefunden: ", pause != null)

	quit(0)
