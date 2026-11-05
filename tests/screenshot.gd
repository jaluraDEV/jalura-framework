extends Node

## Rendert das Demo-Level und speichert einen Screenshot.
## Aufruf: godot --path . res://tests/screenshot.tscn --resolution 1280x720

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	for i in 60:
		await get_tree().process_frame

	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "res://docs/demo_screenshot.png"
	var err := img.save_png(path)
	print("Screenshot: ", path, " (", err, ") ", img.get_width(), "x", img.get_height())
	get_tree().quit(0 if err == OK else 1)
