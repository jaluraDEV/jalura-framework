extends Node

## Globaler Story- und State-Flag Manager für Barnaby.
## Speichert binäre Spielzustände (z. B. "read_sign_a", "opened_gate_harbor", "talked_to_grantelbart")
## und synchronisiert sich mit dem SaveManager.

signal flag_changed(flag_id: String, value: bool)

var _flags: Dictionary = {}         # flag_id: String -> bool
var _defined_flags: Dictionary = {} # flag_id: String -> bool (registrierte / im Spiel vorkommende Flags)

func register_defined_flag(flag_id: String) -> void:
	if flag_id.is_empty():
		return
	_defined_flags[flag_id] = true

func register_defined_flags(flags: Array) -> void:
	for f in flags:
		var s := str(f)
		if not s.is_empty():
			_defined_flags[s] = true

func is_flag_known(flag_id: String) -> bool:
	if flag_id.is_empty():
		return false
	return _defined_flags.has(flag_id) or _flags.has(flag_id)

func set_flag(flag_id: String, value: bool = true) -> void:
	if flag_id.is_empty():
		return
	_defined_flags[flag_id] = true
	var old_val: bool = bool(_flags.get(flag_id, false))
	if old_val != value:
		_flags[flag_id] = value
		flag_changed.emit(flag_id, value)

func has_flag(flag_id: String) -> bool:
	if flag_id.is_empty():
		return false
	return bool(_flags.get(flag_id, false))

func get_flag(flag_id: String) -> bool:
	return has_flag(flag_id)

func clear_flag(flag_id: String) -> void:
	set_flag(flag_id, false)

func get_all_flags() -> Dictionary:
	return _flags.duplicate()

func load_save_data(data: Dictionary) -> void:
	_flags.clear()
	for k in data.keys():
		var s := str(k)
		_flags[s] = bool(data[k])
		_defined_flags[s] = true

func reset() -> void:
	_flags.clear()

