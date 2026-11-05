extends Node

## Datengetriebenes Inventarsystem.
## Scannt rekursiv `res://resources/items/` nach ItemData-Ressourcen (.tres/.res).
## Neue Items kommen ohne Code dazu: Datei anlegen, fertig.
##
## Energie ist ein eigener Zähler und unabhängig vom Rucksack. Ein Item mit
## `is_currency = true` und `currency_attribute = "energy"` speist ihn mit.

signal item_added(item_id: String, count: int, total: int)
signal item_removed(item_id: String, count: int, total: int)
signal inventory_updated
signal energy_changed(new_amount: int, delta: int)
signal batteries_changed(new_amount: int, delta: int)

const ITEMS_DIR: String = "res://resources/items"
const EQUIPMENT_IDS: PackedStringArray = ["glider", "rail_shoe", "flashlight", "lamp"]

var _items: Dictionary = {}          # item_id -> count
var _item_registry: Dictionary = {}  # item_id -> ItemData
var _energy: int = 0

## 0 = unbegrenzt, > 0 = Slot-Begrenzung
var max_slots: int = 0
## Wenn true, werden alle regulären Items abgewiesen (Rucksack gilt als voll).
var force_full: bool = false


func _init() -> void:
	load_all_items()


func _ready() -> void:
	if _item_registry.is_empty():
		load_all_items()


## Lädt alle ItemData-Ressourcen aus dem Ressourcenordner (rekursiv).
func load_all_items() -> void:
	_load_items_from_folder(ITEMS_DIR)
	_ensure_default_items()


func reload_items() -> void:
	_item_registry.clear()
	load_all_items()
	inventory_updated.emit()


func _load_items_from_folder(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			_load_items_from_folder(dir_path + "/" + file_name)
		elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var full_path := dir_path + "/" + file_name
			var res = load(full_path)
			if res is ItemData:
				# Ohne gepflegte ID zählt der Dateiname.
				if res.id.is_empty():
					res.id = file_name.get_basename()
				register_item(res)
		file_name = dir.get_next()


func _ensure_default_items() -> void:
	if not _item_registry.has("glider"):
		var glider := ItemData.new()
		glider.id = "glider"
		glider.name = "Gleitschirm"
		glider.description = "Allows the player to glide through the air!"
		if ResourceLoader.exists("res://assets/chars/extras/glider.glb"):
			glider.model_scene = load("res://assets/chars/extras/glider.glb")
		glider.category = ItemData.Category.TOOL
		glider.max_stack = 1
		glider.can_drop = false
		glider.is_currency = false
		glider.currency_attribute = ""
		register_item(glider)

	if not _item_registry.has("rail_shoe"):
		var shoe := ItemData.new()
		shoe.id = "rail_shoe"
		shoe.name = "Rail-Schuhe"
		shoe.description = "Special shoes with reinforced soles! Allows grinding along rails."
		if ResourceLoader.exists("res://assets/chars/extras/rail_shoe.glb"):
			shoe.model_scene = load("res://assets/chars/extras/rail_shoe.glb")
		shoe.category = ItemData.Category.TOOL
		shoe.max_stack = 1
		shoe.can_drop = false
		shoe.is_currency = false
		shoe.currency_attribute = ""
		register_item(shoe)

	if not _item_registry.has("flashlight"):
		var flash := ItemData.new()
		flash.id = "flashlight"
		flash.name = "Flashlight"
		flash.description = "Eine robuste Kastenlampe mit Metallgriff. Erhellt dunkle Ecken auf Knopfdruck [F]."
		if ResourceLoader.exists("res://assets/items/alte_lampe/alte_lampe.glb"):
			flash.model_scene = load("res://assets/items/alte_lampe/alte_lampe.glb")
		flash.category = ItemData.Category.TOOL
		flash.max_stack = 1
		flash.can_drop = false
		flash.is_currency = false
		flash.currency_attribute = ""
		register_item(flash)

	if not _item_registry.has("battery"):
		var battery := ItemData.new()
		battery.id = "battery"
		battery.name = "Batterie"
		battery.description = "Eine geladene Energie-Batterie. Speist Barnabys Energie-Anzeige."
		battery.category = ItemData.Category.CURRENCY
		battery.max_stack = 999
		battery.is_currency = true
		battery.currency_attribute = "energy"
		battery.can_drop = false
		register_item(battery)


func register_item(data: ItemData) -> void:
	if data and not data.id.is_empty():
		if data.id in EQUIPMENT_IDS:
			data.category = ItemData.Category.TOOL
			data.max_stack = 1
			data.can_drop = false
			data.is_currency = false
			data.currency_attribute = ""
		_item_registry[data.id] = data


func get_item_data(item_id: String) -> ItemData:
	if _item_registry.has(item_id):
		return _item_registry[item_id]
	var fallback_path := "%s/%s.tres" % [ITEMS_DIR, item_id]
	if ResourceLoader.exists(fallback_path):
		var res := load(fallback_path) as ItemData
		if res:
			if res.id.is_empty():
				res.id = item_id
			register_item(res)
			return res
	return null


func is_equipment(item_id: String) -> bool:
	if item_id in EQUIPMENT_IDS:
		return true
	var data := get_item_data(item_id)
	return data != null and data.category == ItemData.Category.TOOL


func get_equipment_items() -> Dictionary:
	var result: Dictionary = {}
	for id in _items.keys():
		if is_equipment(id):
			result[id] = _items[id]
	return result


func get_regular_items() -> Dictionary:
	var result: Dictionary = {}
	for id in _items.keys():
		var data := get_item_data(id)
		if data and data.is_currency:
			continue
		if is_equipment(id):
			continue
		result[id] = _items[id]
	return result


func get_registered_items() -> Dictionary:
	return _item_registry.duplicate()


func set_max_slots(slots: int) -> void:
	max_slots = maxi(0, slots)


func get_max_slots() -> int:
	return max_slots


func get_used_slots() -> int:
	var count := 0
	for id in _items.keys():
		var data := get_item_data(id)
		# Währungen und Ausrüstung (Tools) belegen keinen regulären Asservaten-Slot.
		if data and (data.is_currency or data.category == ItemData.Category.TOOL):
			continue
		if id in EQUIPMENT_IDS:
			continue
		count += 1
	return count


func can_add_item(item_id: String, count: int = 1) -> bool:
	if item_id.is_empty() or count <= 0:
		return false

	var item_data := get_item_data(item_id)
	var max_stack: int = item_data.max_stack if item_data else 999
	var current: int = _items.get(item_id, 0)

	# Währungen und Ausrüstungs-Tools werden immer akzeptiert (belegen keinen Asservaten-Slot).
	if item_data and (item_data.is_currency or item_data.category == ItemData.Category.TOOL):
		return (current + count) <= max_stack
	if item_id in EQUIPMENT_IDS:
		return (current + count) <= 1

	if force_full:
		return false

	if max_slots <= 0:
		return (current + count) <= max_stack

	if _items.has(item_id):
		return (current + count) <= max_stack

	return get_used_slots() < max_slots


func add_item(item_id: String, count: int = 1) -> void:
	if count <= 0 or item_id.is_empty():
		return
	if not can_add_item(item_id, count):
		return

	var item_data := get_item_data(item_id)
	var max_stack: int = item_data.max_stack if item_data else 999
	var current: int = _items.get(item_id, 0)
	var new_total: int = mini(current + count, max_stack)
	_items[item_id] = new_total

	if _is_energy_item(item_data) or item_id == "battery":
		var delta := new_total - _energy
		_energy = new_total
		energy_changed.emit(_energy, delta)
		batteries_changed.emit(_energy, delta)

	item_added.emit(item_id, count, new_total)
	inventory_updated.emit()


func remove_item(item_id: String, count: int = 1) -> bool:
	if not has_item(item_id, count):
		return false

	var current: int = _items[item_id]
	var new_total: int = current - count
	if new_total <= 0:
		_items.erase(item_id)
		new_total = 0
	else:
		_items[item_id] = new_total

	if _is_energy_item(get_item_data(item_id)) or item_id == "battery":
		var delta := new_total - _energy
		_energy = new_total
		energy_changed.emit(_energy, delta)
		batteries_changed.emit(_energy, delta)

	item_removed.emit(item_id, count, new_total)
	inventory_updated.emit()
	return true


func has_item(item_id: String, count: int = 1) -> bool:
	return _items.get(item_id, 0) >= count


func get_item_count(item_id: String) -> int:
	return _items.get(item_id, 0)


func get_all_items() -> Dictionary:
	return _items.duplicate()


## Prüft, ob ein Item den Energie-Zähler speist.
func _is_energy_item(item_data: ItemData) -> bool:
	return item_data != null and item_data.is_currency and item_data.currency_attribute == "energy"


func add_batteries(amount: int) -> void:
	set_energy(_energy + amount)


func get_batteries() -> int:
	return _energy


func add_energy(amount: int) -> void:
	set_energy(_energy + amount)


func set_energy(amount: int) -> void:
	var new_value := maxi(0, amount)
	var delta := new_value - _energy
	_energy = new_value
	energy_changed.emit(_energy, delta)
	batteries_changed.emit(_energy, delta)
	inventory_updated.emit()


func get_energy() -> int:
	return _energy


func reset() -> void:
	_items.clear()
	_energy = 0
	max_slots = 0
	force_full = false
	energy_changed.emit(0, 0)
	batteries_changed.emit(0, 0)
	inventory_updated.emit()


func get_save_data() -> Dictionary:
	return {
		"energy": _energy,
		"items": _items.duplicate(),
	}


func load_save_data(data: Dictionary) -> void:
	_items.clear()
	if data.get("items") is Dictionary:
		for key in data["items"].keys():
			_items[str(key)] = int(data["items"][key])
	_energy = int(data.get("energy", 0))
	energy_changed.emit(_energy, 0)
	batteries_changed.emit(_energy, 0)
	inventory_updated.emit()
