@tool
class_name JaluraConverterContextMenu
extends EditorContextMenuPlugin

## Adds 'Convert to Jalura Object' entries to the FileSystem dock right-click context menu.

signal convert_requested(paths: PackedStringArray, type_key: String)

var _cached_paths: PackedStringArray = []

func _popup_menu(paths: PackedStringArray) -> void:
	_cached_paths = paths

	var has_3d := false
	for p in paths:
		var ext := p.get_extension().to_lower()
		if ext in ["glb", "gltf", "obj"]:
			has_3d = true
			break

	if not has_3d:
		return

	# Add direct Jalura conversion options
	add_context_menu_item("🎒 Jalura: New Inventory Item (ItemData + Pickup)...", _on_item_dialog_selected)
	add_context_menu_item("🎒 Jalura: Schnell-Item (Standard)", _on_item_quick_selected)
	add_context_menu_item("✨ Jalura: Truhe / Container", _on_chest_selected)
	add_context_menu_item("✨ Jalura: Door / Gate", _on_door_selected)
	add_context_menu_item("✨ Jalura: Lever / Switch", _on_switch_selected)
	add_context_menu_item("✨ Jalura: Schild / Text", _on_sign_selected)
	add_context_menu_item("✨ Jalura: Schiebe-Block", _on_pushable_selected)
	add_context_menu_item("✨ Jalura: Wackel-Deko", _on_wobble_selected)
	add_context_menu_item("✨ Jalura: Bounce Pad / Trampoline", _on_bounce_pad_selected)
	add_context_menu_item("⚙️ Jalura: Benutzerdefiniert...", _on_custom_selected)


func _on_item_dialog_selected(a = null, b = null) -> void: _forward("item_dialog", a, b)
func _on_item_quick_selected(a = null, b = null) -> void: _forward("item_quick", a, b)
func _on_chest_selected(a = null, b = null) -> void: _forward("chest", a, b)
func _on_door_selected(a = null, b = null) -> void: _forward("door", a, b)
func _on_switch_selected(a = null, b = null) -> void: _forward("switch", a, b)
func _on_sign_selected(a = null, b = null) -> void: _forward("sign", a, b)
func _on_pickup_selected(a = null, b = null) -> void: _forward("pickup", a, b)
func _on_pushable_selected(a = null, b = null) -> void: _forward("pushable", a, b)
func _on_wobble_selected(a = null, b = null) -> void: _forward("wobble", a, b)
func _on_bounce_pad_selected(a = null, b = null) -> void: _forward("bounce_pad", a, b)
func _on_custom_selected(a = null, b = null) -> void: _forward("custom", a, b)


func _forward(type_key: String, a = null, b = null) -> void:
	var final_paths := _cached_paths
	if a is PackedStringArray and not a.is_empty():
		final_paths = a
	elif b is PackedStringArray and not b.is_empty():
		final_paths = b
	convert_requested.emit(final_paths, type_key)
