extends Control
class_name PauseMenu

@onready var resume_btn: Button = %ResumeButton
@onready var save_btn: Button = %SaveButton
@onready var options_btn: Button = %OptionsButton
@onready var main_menu_btn: Button = %MainMenuButton
@onready var quit_btn: Button = %QuitButton

@onready var save_feedback_label: Label = %SaveFeedbackLabel
@onready var options_container: Control = %OptionsContainer

var is_open: bool = false
var _options_menu_inst: Control

func _ready() -> void:
	visible = false
	save_feedback_label.visible = false
	
	resume_btn.pressed.connect(close_menu)
	save_btn.pressed.connect(_on_save_pressed)
	options_btn.pressed.connect(_on_options_pressed)
	main_menu_btn.pressed.connect(_on_main_menu_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		var st = get_node_or_null("/root/SceneTransition")
		if st and st.get("is_transitioning") == true:
			return
		var rm = get_node_or_null("/root/RoomManager")
		if rm and rm.get("is_transitioning") == true:
			return
		var hud = get_tree().root.find_child("HUD", true, false)
		if hud and (hud.is_dialogue_active or hud.is_celebrating):
			return
			
		var inv_menu = get_tree().root.find_child("InventoryMenu", true, false)
		if inv_menu and inv_menu.is_open:
			inv_menu.close_menu()
			get_viewport().set_input_as_handled()
			return
			
		if is_open:
			if _options_menu_inst and _options_menu_inst.visible:
				_close_options()
			else:
				close_menu()
			get_viewport().set_input_as_handled()
		else:
			open_menu()
			get_viewport().set_input_as_handled()

func open_menu() -> void:
	is_open = true
	visible = true
	save_feedback_label.visible = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_menu() -> void:
	is_open = false
	visible = false
	if _options_menu_inst:
		_options_menu_inst.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_save_pressed() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if not sm:
		return
	var slot: int = int(sm.get("current_slot"))
	var success: bool = bool(sm.call("save_game", slot))
	if success:
		save_feedback_label.text = "✓ Game saved to Slot %d!" % slot
		save_feedback_label.modulate = Color(0.3, 1.0, 0.4)
	else:
		save_feedback_label.text = "✗ Error saving game!"
		save_feedback_label.modulate = Color(1.0, 0.3, 0.3)
		
	save_feedback_label.visible = true
	var tween := create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(save_feedback_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): save_feedback_label.visible = false; save_feedback_label.modulate.a = 1.0)

func _on_options_pressed() -> void:
	if not _options_menu_inst:
		var opt_scene := load("res://scenes/ui/options_menu.tscn") as PackedScene
		_options_menu_inst = opt_scene.instantiate() as Control
		_options_menu_inst.connect("closed", _close_options)
		options_container.add_child(_options_menu_inst)
	_options_menu_inst.visible = true

func _close_options() -> void:
	if _options_menu_inst:
		_options_menu_inst.visible = false

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
