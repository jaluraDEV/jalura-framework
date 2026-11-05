extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var logo_label: Label = %LogoTitle
@onready var main_buttons_container: VBoxContainer = %MainButtonsContainer
@onready var slots_container: Control = %SlotsContainer
@onready var options_container: Control = %OptionsContainer

@onready var continue_btn: Button = %ContinueButton
@onready var slots_btn: Button = %SlotsButton
@onready var new_game_btn: Button = %NewGameButton
@onready var options_btn: Button = %OptionsButton
@onready var quit_btn: Button = %QuitButton

# Delete confirmation modal
@onready var delete_modal: Control = %DeleteModal
@onready var delete_confirm_label: Label = %DeleteConfirmLabel
@onready var delete_confirm_btn: Button = %DeleteConfirmButton
@onready var delete_cancel_btn: Button = %DeleteCancelButton

# Slot cards (Slot 1, Slot 2, Slot 3)
@onready var slot_cards: Array[Node] = [
	%SlotCard1,
	%SlotCard2,
	%SlotCard3
]
@onready var slots_back_btn: Button = %SlotsBackButton

# 3D Showcase Objects for background animation
@onready var showcase_pivot: Node3D = $ShowcaseRoot/ShowcasePivot
@onready var coin_node: Node3D = $ShowcaseRoot/ShowcasePivot/CoinPivot
@onready var glider_node: Node3D = $ShowcaseRoot/ShowcasePivot/GliderPivot
@onready var lamp_node: Node3D = $ShowcaseRoot/ShowcasePivot/LampPivot
@onready var lamp_light: OmniLight3D = $ShowcaseRoot/ShowcasePivot/LampPivot/LampLight

var _time: float = 0.0
var _slot_to_delete: int = -1
var _options_menu_inst: Control

func _get_save_manager() -> Node:
	return get_node_or_null("/root/SaveManager")

func _get_settings_manager() -> Node:
	return get_node_or_null("/root/SettingsManager")

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_setup_ui_states()
	_refresh_main_menu()
	_connect_signals()
	_animate_logo()

	var settings = _get_settings_manager()
	if settings and settings.has_method("apply_all_settings"):
		settings.apply_all_settings()

func _process(delta: float) -> void:
	_time += delta

	# Smooth cinematic camera drift around the demo showcase
	if camera:
		var cam_angle: float = _time * 0.15
		camera.position.x = sin(cam_angle) * 4.5
		camera.position.z = cos(cam_angle) * 4.5
		camera.position.y = 1.9 + sin(_time * 0.6) * 0.12
		camera.look_at(Vector3(0.0, 0.9, 0.0), Vector3.UP)

	# Gentle rotation and bobbing for the showcase items
	if showcase_pivot:
		showcase_pivot.rotation.y = _time * 0.25

	if coin_node:
		coin_node.position.y = 1.25 + sin(_time * 2.2) * 0.08
		coin_node.rotation.y = _time * 2.0

	if glider_node:
		glider_node.position.y = 1.1 + sin(_time * 1.8 + 1.2) * 0.06
		glider_node.rotation.z = sin(_time * 1.5) * 0.08

	if lamp_node:
		lamp_node.position.y = 0.95 + sin(_time * 1.6 + 2.5) * 0.05
		if lamp_light:
			lamp_light.light_energy = 1.6 + sin(_time * 9.0) * 0.18 + cos(_time * 15.0) * 0.08

func _setup_ui_states() -> void:
	main_buttons_container.visible = true
	slots_container.visible = false
	delete_modal.visible = false

func _animate_logo() -> void:
	if not logo_label:
		return
	var base_scale := logo_label.scale
	var tween := create_tween().set_loops()
	tween.tween_property(logo_label, "scale", base_scale * 1.025, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(logo_label, "scale", base_scale, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _refresh_main_menu() -> void:
	var has_any_save := false
	var newest_slot := 1
	var newest_time := -1

	var sm = _get_save_manager()
	if sm:
		for s in range(1, 4):
			if sm.has_method("has_save") and sm.has_save(s):
				has_any_save = true
				var info: Dictionary = sm.get_slot_info(s) if sm.has_method("get_slot_info") else {}
				var t: int = info.get("data", {}).get("timestamp", 0)
				if t > newest_time:
					newest_time = t
					newest_slot = s

	continue_btn.visible = has_any_save
	if has_any_save:
		continue_btn.text = "Continue Game (Slot %d)" % newest_slot
		continue_btn.set_meta("slot_id", newest_slot)

func _refresh_slots_view() -> void:
	var sm = _get_save_manager()
	if not sm:
		return

	for i in range(3):
		var slot_id := i + 1
		var card = slot_cards[i]
		var info: Dictionary = sm.get_slot_info(slot_id) if sm.has_method("get_slot_info") else {}

		var title_lbl: Label = card.get_node("%TitleLabel" + str(slot_id))
		var status_lbl: Label = card.get_node("%StatusLabel" + str(slot_id))
		var details_lbl: Label = card.get_node("%DetailsLabel" + str(slot_id))
		var play_btn: Button = card.get_node("%PlayButton" + str(slot_id))
		var new_btn: Button = card.get_node("%NewButton" + str(slot_id))
		var del_btn: Button = card.get_node("%DeleteButton" + str(slot_id))

		title_lbl.text = "SAVE SLOT %d" % slot_id

		var exists: bool = info.get("exists", false)
		if exists:
			status_lbl.text = "ACTIVE"
			status_lbl.modulate = Color(0.3, 0.9, 0.4)
			details_lbl.text = "%d Energy\n📜 %d Quests\n🕒 %s" % [
				info.get("energy", 0),
				info.get("completed_quests", 0),
				info.get("date_string", "")
			]
			play_btn.visible = true
			play_btn.text = "Load & Play"
			new_btn.visible = true
			new_btn.text = "Overwrite (New)"
			del_btn.visible = true
		else:
			status_lbl.text = "EMPTY"
			status_lbl.modulate = Color(0.65, 0.65, 0.65)
			details_lbl.text = "No save data found.\nReady for a new adventure!"
			play_btn.visible = false
			new_btn.visible = true
			new_btn.text = "Start New Game"
			del_btn.visible = false

func _connect_signals() -> void:
	continue_btn.pressed.connect(_on_continue_pressed)
	slots_btn.pressed.connect(_on_slots_pressed)
	new_game_btn.pressed.connect(_on_slots_pressed)
	options_btn.pressed.connect(_on_options_pressed)
	quit_btn.pressed.connect(func(): get_tree().quit())

	slots_back_btn.pressed.connect(_on_slots_back_pressed)

	for i in range(3):
		var slot_id := i + 1
		var card = slot_cards[i]
		var play_btn: Button = card.get_node("%PlayButton" + str(slot_id))
		var new_btn: Button = card.get_node("%NewButton" + str(slot_id))
		var del_btn: Button = card.get_node("%DeleteButton" + str(slot_id))

		play_btn.pressed.connect(func(): _load_slot(slot_id))
		new_btn.pressed.connect(func(): _new_game_slot(slot_id))
		del_btn.pressed.connect(func(): _confirm_delete_slot(slot_id))

	delete_confirm_btn.pressed.connect(_execute_delete_slot)
	delete_cancel_btn.pressed.connect(_cancel_delete_slot)

func _on_continue_pressed() -> void:
	var slot_id: int = continue_btn.get_meta("slot_id", 1)
	_load_slot(slot_id)

func _load_slot(slot_id: int) -> void:
	var sm = _get_save_manager()
	if sm and sm.has_method("load_game"):
		sm.load_game(slot_id)

func _new_game_slot(slot_id: int) -> void:
	var sm = _get_save_manager()
	if sm and sm.has_method("start_new_game"):
		sm.start_new_game(slot_id)

func _confirm_delete_slot(slot_id: int) -> void:
	_slot_to_delete = slot_id
	delete_confirm_label.text = "Are you sure you want to delete Save Slot %d?\nAll progress will be lost permanently." % slot_id
	delete_modal.visible = true

func _execute_delete_slot() -> void:
	var sm = _get_save_manager()
	if _slot_to_delete > 0 and sm and sm.has_method("delete_save"):
		sm.delete_save(_slot_to_delete)
		_slot_to_delete = -1
		delete_modal.visible = false
		_refresh_slots_view()
		_refresh_main_menu()

func _cancel_delete_slot() -> void:
	_slot_to_delete = -1
	delete_modal.visible = false

func _on_slots_pressed() -> void:
	main_buttons_container.visible = false
	slots_container.visible = true
	_refresh_slots_view()

func _on_slots_back_pressed() -> void:
	slots_container.visible = false
	main_buttons_container.visible = true
	_refresh_main_menu()

func _on_options_pressed() -> void:
	main_buttons_container.visible = false
	if not _options_menu_inst:
		var opt_scene := load("res://scenes/ui/options_menu.tscn") as PackedScene
		if opt_scene:
			_options_menu_inst = opt_scene.instantiate() as Control
			_options_menu_inst.connect("closed", _close_options)
			options_container.add_child(_options_menu_inst)
	if _options_menu_inst:
		_options_menu_inst.visible = true

func _close_options() -> void:
	if _options_menu_inst:
		_options_menu_inst.visible = false
	main_buttons_container.visible = true
