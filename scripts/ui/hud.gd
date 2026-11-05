extends CanvasLayer
class_name HUD

@onready var battery_label: Label = %BatteryLabel
@onready var prompt_container: PanelContainer = $CenterPrompt/PromptPanel
@onready var prompt_label: Label = $CenterPrompt/PromptPanel/PromptLabel
@onready var cases_hint_container: PanelContainer = %CasesHintContainer if has_node("%CasesHintContainer") else null
@onready var cases_hint_label: Label = %CasesHintLabel if has_node("%CasesHintLabel") else null
@onready var bag_hint_container: PanelContainer = %BagHintContainer
@onready var bag_hint_label: Label = %BagHintLabel
@onready var fps_container: PanelContainer = %FpsContainer
@onready var fps_label: Label = %FpsLabel
@onready var inventory_menu: InventoryMenu = %InventoryMenu
@onready var pause_menu: PauseMenu = %PauseMenu


@onready var dialogue_panel: PanelContainer = $DialogueContainer/DialoguePanel
@onready var speaker_label: Label = $DialogueContainer/DialoguePanel/MarginContainer/VBoxContainer/SpeakerLabel
@onready var dialogue_text: Label = $DialogueContainer/DialoguePanel/MarginContainer/VBoxContainer/DialogueText
@onready var dialogue_hint: Label = $DialogueContainer/DialoguePanel/MarginContainer/VBoxContainer/DialogueHint

# Milestone Celebration Overlay
@onready var celebration_overlay: Control = $CelebrationOverlay
@onready var celebration_stage: Node3D = $CelebrationOverlay/ViewportContainer/SubViewport/CelebrationStage
@onready var confetti: CPUParticles2D = $CelebrationOverlay/ConfettiParticles
@onready var top_banner: VBoxContainer = $CelebrationOverlay/TopBanner
@onready var quest_title_label: Label = $CelebrationOverlay/TopBanner/QuestTitle
@onready var bottom_reward: VBoxContainer = $CelebrationOverlay/BottomReward
@onready var reward_label: Label = $CelebrationOverlay/BottomReward/RewardPanel/RewardText
@onready var stamp_rect: TextureRect = %StampRect if has_node("%StampRect") else null

var _current_dialogue_lines: Array = []
var _current_dialogue_index: int = 0
var _dialogue_callback: Callable
var _dialogue_queue: Array[Dictionary] = []
var is_dialogue_active: bool = false
var is_celebrating: bool = false
var _fps_update_timer: float = 0.0
var _fps_samples: Array[float] = []


# Toast Notification System
var _toast_panel: PanelContainer
var _toast_badge: Label
var _toast_title: Label
var _toast_text: Label
var _toast_queue: Array[Dictionary] = []
var _is_toast_showing: bool = false
var _toast_tween: Tween = null

func _ready() -> void:
	prompt_container.visible = false
	dialogue_panel.visible = false
	celebration_overlay.visible = false
	
	_setup_toast_ui()
	
	var inv = get_node_or_null("/root/InventoryManager")
	if inv:
		inv.energy_changed.connect(_on_energy_changed)
		inv.inventory_updated.connect(_update_inventory_display)
		_update_energy_display(inv.get_energy(), 0)
		_update_inventory_display()
		
	var qm = get_node_or_null("/root/QuestManager")
	if qm:
		qm.quest_celebration_started.connect(_on_quest_celebration_started)
		qm.quest_celebration_ended.connect(_on_quest_celebration_ended)
		qm.quest_started.connect(_on_quest_started)
		qm.quest_objective_updated.connect(_on_quest_objective_updated)
		qm.quest_ready_to_turn_in.connect(_on_quest_ready_to_turn_in)
		qm.quest_completed.connect(_on_quest_completed)
		_update_cases_display()
		
	var sm = get_node_or_null("/root/SettingsManager")
	if sm:
		sm.settings_changed.connect(_on_settings_changed)
	_update_fps_display()
		
	if cases_hint_container:
		cases_hint_container.gui_input.connect(_on_cases_hint_input)
	if bag_hint_container:
		bag_hint_container.gui_input.connect(_on_bag_hint_input)


func _setup_toast_ui() -> void:
	var anchor := Control.new()
	anchor.name = "ToastAnchor"
	anchor.set_anchors_preset(Control.PRESET_TOP_WIDE)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)
	if inventory_menu:
		move_child(anchor, inventory_menu.get_index())
	
	_toast_panel = PanelContainer.new()
	_toast_panel.name = "ToastPanel"
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.visible = false
	_toast_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	
	var noir_font: Font = null
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.11, 0.10, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.85, 0.72, 0.46, 0.85)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 12
	style.expand_margin_left = 18.0
	style.expand_margin_right = 18.0
	style.expand_margin_top = 8.0
	style.expand_margin_bottom = 8.0
	_toast_panel.add_theme_stylebox_override("panel", style)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	
	_toast_badge = Label.new()
	_toast_badge.text = "🎯"
	_toast_badge.add_theme_font_size_override("font_size", 22)
	hbox.add_child(_toast_badge)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	
	_toast_title = Label.new()
	_toast_title.text = "QUEST NOTE"
	if noir_font:
		_toast_title.add_theme_font_override("font", noir_font)
	_toast_title.add_theme_font_size_override("font_size", 14)
	_toast_title.modulate = Color(0.92, 0.78, 0.48)
	vbox.add_child(_toast_title)
	
	_toast_text = Label.new()
	_toast_text.text = "Objective updated"
	if noir_font:
		_toast_text.add_theme_font_override("font", noir_font)
	_toast_text.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_toast_text)
	
	hbox.add_child(vbox)
	_toast_panel.add_child(hbox)
	anchor.add_child(_toast_panel)

func show_toast(badge: String, title: String, text: String, color: Color = Color(1.0, 0.85, 0.4)) -> void:
	_toast_queue.append({
		"badge": badge,
		"title": title,
		"text": text,
		"color": color
	})
	if not _is_toast_showing and not is_celebrating:
		_process_next_toast()

func _process_next_toast() -> void:
	if _toast_queue.is_empty():
		_is_toast_showing = false
		return
	if is_celebrating:
		return
		
	_is_toast_showing = true
	var item: Dictionary = _toast_queue.pop_front()
	
	_toast_badge.text = item.get("badge", "✨")
	_toast_badge.visible = not _toast_badge.text.is_empty()
	
	var title_str: String = str(item.get("title", ""))
	_toast_title.text = title_str
	_toast_title.modulate = item.get("color", Color(1.0, 0.85, 0.4))
	_toast_title.visible = not title_str.is_empty()
	
	var text_str: String = str(item.get("text", ""))
	_toast_text.text = text_str
	_toast_text.visible = not text_str.is_empty()
	
	_toast_panel.reset_size()
	_toast_panel.position.y = -55.0
	_toast_panel.modulate.a = 0.0
	_toast_panel.visible = true
	
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
		
	var tw := create_tween()
	_toast_tween = tw
	
	# 1. Slide in from top (parallel: position + alpha)
	tw.tween_property(_toast_panel, "position:y", 28.0, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_toast_panel, "modulate:a", 1.0, 0.22)
	
	# 2. Hold for comfortable reading time (3.0s)
	tw.tween_interval(3.0)
	
	# 3. Slide out to top (parallel: position + alpha)
	tw.tween_property(_toast_panel, "position:y", -55.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_toast_panel, "modulate:a", 0.0, 0.22)
	
	tw.finished.connect(func():
		if is_instance_valid(_toast_panel):
			_toast_panel.visible = false
		_is_toast_showing = false
		_toast_tween = null
		if not is_celebrating:
			_process_next_toast()
	)

func _on_quest_started(quest: QuestData) -> void:
	show_toast("📋", "NEW QUEST", quest.title, Color(0.92, 0.78, 0.48))
	_update_cases_display()

func _on_quest_objective_updated(_quest: QuestData, objective: QuestObjective) -> void:
	if objective.is_completed():
		show_toast("🔍", "OBJECTIVE COMPLETED", objective.description, Color(0.4, 0.95, 0.5))
	else:
		show_toast("🖋️", "OBJECTIVE UPDATED", objective.get_progress_text(), Color(0.92, 0.78, 0.48))
	_update_cases_display()

func _on_quest_ready_to_turn_in(quest: QuestData) -> void:
	var npc_name := quest.turn_in_npc_id if not quest.turn_in_npc_id.is_empty() else quest.giver_npc_id
	show_toast("📁", "QUEST READY", "Report back to %s!" % npc_name.capitalize(), Color(0.95, 0.55, 0.35))
	_update_cases_display()

func _on_quest_completed(_quest: QuestData, _reward: int) -> void:
	_update_cases_display()


func _process(delta: float) -> void:
	if fps_container and fps_container.visible and not is_celebrating:
		_fps_update_timer += delta
		_fps_samples.append(delta)
		if _fps_samples.size() > 20:
			_fps_samples.pop_front()
			
		if _fps_update_timer >= 0.15:
			_fps_update_timer = 0.0
			var current_fps := Engine.get_frames_per_second()
			var avg_delta := 0.0
			for s in _fps_samples:
				avg_delta += s
			avg_delta /= max(1.0, float(_fps_samples.size()))
			var ms := avg_delta * 1000.0
			
			var sm = get_node_or_null("/root/SettingsManager")
			if sm and sm.fps_limit_enabled and sm.max_fps > 0:
				fps_label.text = "%d / %d FPS (%.1f ms)" % [current_fps, sm.max_fps, ms]
			else:
				fps_label.text = "%d FPS (%.1f ms)" % [current_fps, ms]

func _on_settings_changed(setting_name: String) -> void:
	if setting_name == "video" or setting_name == "display":
		_update_fps_display()

func _update_fps_display() -> void:
	var sm = get_node_or_null("/root/SettingsManager")
	if fps_container and sm:
		fps_container.visible = sm.show_fps
		if sm.show_fps:
			var current_fps := Engine.get_frames_per_second()
			if sm.fps_limit_enabled and sm.max_fps > 0:
				fps_label.text = "%d / %d FPS" % [current_fps, sm.max_fps]
			else:
				fps_label.text = "%d FPS" % current_fps


func _unhandled_input(event: InputEvent) -> void:
	if is_dialogue_active:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_E or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER)):
			_advance_dialogue()
			get_viewport().set_input_as_handled()

func show_prompt(text: String, key: String = "E") -> void:
	if is_dialogue_active or is_celebrating:
		prompt_container.visible = false
		return
	prompt_label.text = "[%s]  %s" % [key, text]
	prompt_container.visible = true

func hide_prompt() -> void:
	prompt_container.visible = false

func start_dialogue(speaker: String, lines: Array, on_finished: Callable = Callable()) -> void:
	if lines.is_empty():
		return
	if is_dialogue_active:
		_dialogue_queue.append({
			"speaker": speaker,
			"lines": lines,
			"on_finished": on_finished
		})
		return
		
	_current_dialogue_lines = lines
	_current_dialogue_index = 0
	_dialogue_callback = on_finished
	
	is_dialogue_active = true
	hide_prompt()
	speaker_label.text = speaker
	_show_current_dialogue_line()
	dialogue_panel.visible = true

func _show_current_dialogue_line() -> void:
	if _current_dialogue_index < _current_dialogue_lines.size():
		dialogue_text.text = _current_dialogue_lines[_current_dialogue_index]
		if _current_dialogue_index == _current_dialogue_lines.size() - 1:
			dialogue_hint.text = "[E / Space] Close"
		else:
			dialogue_hint.text = "[E / Leertaste] Weiter"

func _advance_dialogue() -> void:
	_current_dialogue_index += 1
	if _current_dialogue_index < _current_dialogue_lines.size():
		_show_current_dialogue_line()
	else:
		end_dialogue()

func end_dialogue() -> void:
	var cb := _dialogue_callback
	_dialogue_callback = Callable()
	if cb.is_valid():
		cb.call()
		
	if not _dialogue_queue.is_empty():
		var next_diag: Dictionary = _dialogue_queue.pop_front()
		_current_dialogue_lines = next_diag.get("lines", [])
		_current_dialogue_index = 0
		_dialogue_callback = next_diag.get("on_finished", Callable())
		speaker_label.text = next_diag.get("speaker", "")
		_show_current_dialogue_line()
		return

	is_dialogue_active = false
	dialogue_panel.visible = false

func clear_dialogue_queue() -> void:
	_dialogue_queue.clear()

func clear_toasts() -> void:
	_toast_queue.clear()
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	if is_instance_valid(_toast_panel):
		_toast_panel.visible = false
	_is_toast_showing = false

func _on_energy_changed(new_amount: int, delta: int) -> void:
	_update_energy_display(new_amount, delta)

func _update_energy_display(amount: int, delta: int) -> void:
	if battery_label:
		battery_label.text = str(amount)
		if delta > 0:
			var tween := create_tween()
			battery_label.scale = Vector2(1.25, 1.25)
			tween.tween_property(battery_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_cases_hint_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var st = get_node_or_null("/root/SceneTransition")
		if st and st.get("is_transitioning") == true:
			return
		var rm = get_node_or_null("/root/RoomManager")
		if rm and rm.get("is_transitioning") == true:
			return
		if inventory_menu:
			inventory_menu.toggle_menu(InventoryMenu.MenuTab.CASES)

func _on_bag_hint_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var st = get_node_or_null("/root/SceneTransition")
		if st and st.get("is_transitioning") == true:
			return
		var rm = get_node_or_null("/root/RoomManager")
		if rm and rm.get("is_transitioning") == true:
			return
		if inventory_menu:
			inventory_menu.toggle_menu(InventoryMenu.MenuTab.EVIDENCE)

func _update_cases_display() -> void:
	var qm = get_node_or_null("/root/QuestManager")
	if not qm or not cases_hint_label:
		return
	var active_count: int = qm.get_active_quests().size()
	if active_count > 0:
		cases_hint_label.text = "📋 [Q] Quests (%d)" % active_count
	else:
		cases_hint_label.text = "📋 [Q] Quests"

func _update_inventory_display() -> void:
	var inv = get_node_or_null("/root/InventoryManager")
	if not inv or not bag_hint_label:
		return
		
	var items: Dictionary = inv.get_all_items()
	var reg_items: int = 0
	var eq_items: int = 0
	for id in items.keys():
		var data: ItemData = inv.get_item_data(id)
		if data and data.is_currency:
			continue
		var count: int = int(items[id])
		if (data and data.category == ItemData.Category.TOOL) or (inv.has_method("is_equipment") and inv.is_equipment(id)):
			eq_items += count
		else:
			reg_items += count
		
	if reg_items > 0 and eq_items > 0:
		bag_hint_label.text = "💼 [I] Items (%d)  •  ⚙️ [U] Equipment (%d)" % [reg_items, eq_items]
	elif eq_items > 0:
		bag_hint_label.text = "💼 [I] Items  •  ⚙️ [U] Equipment (%d)" % eq_items
	elif reg_items > 0:
		bag_hint_label.text = "💼 [I] Items (%d)  •  ⚙️ [U] Equipment" % reg_items
	else:
		bag_hint_label.text = "💼 [I] Items  •  ⚙️ [U] Equipment"


func _on_quest_celebration_started(quest: QuestData) -> void:
	is_celebrating = true
	hide_prompt()
	if _toast_panel:
		_toast_panel.visible = false
		
	quest_title_label.text = quest.title
	if not quest.reward_item_id.is_empty():
		var inv = get_node_or_null("/root/InventoryManager")
		var item_data = inv.get_item_data(quest.reward_item_id) if inv else null
		var item_name: String = item_data.name if item_data else quest.reward_item_id
		var count: int = maxi(quest.reward_item_count, 1)
		if quest.energy_reward > 0:
			reward_label.text = "+%d %s & +%d ENERGY" % [count, item_name.to_upper(), quest.energy_reward]
		else:
			reward_label.text = "+%d %s" % [count, item_name.to_upper()]
	else:
		reward_label.text = "+%d ENERGY" % quest.energy_reward
	
	celebration_overlay.visible = true
	celebration_overlay.modulate.a = 0.0
	
	top_banner.position.y = -70.0
	top_banner.modulate.a = 0.0
	bottom_reward.scale = Vector2(0.3, 0.3)
	bottom_reward.pivot_offset = Vector2(200, 37.5)
	bottom_reward.modulate.a = 0.0
	
	if stamp_rect:
		stamp_rect.scale = Vector2(2.8, 2.8)
		stamp_rect.rotation = -0.28
		stamp_rect.modulate.a = 0.0
		stamp_rect.visible = true
	
	if celebration_stage and celebration_stage.has_method("restart_dance"):
		celebration_stage.restart_dance()
		
	if confetti:
		confetti.restart()
		confetti.emitting = true
	
	var tween := create_tween()
	tween.tween_property(celebration_overlay, "modulate:a", 1.0, 0.22)
	
	var banner_tween := create_tween()
	banner_tween.set_parallel(true)
	banner_tween.tween_property(top_banner, "position:y", 22.0, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	banner_tween.tween_property(top_banner, "modulate:a", 1.0, 0.25)
	
	if stamp_rect:
		var stamp_tween := create_tween()
		stamp_tween.tween_interval(0.38)
		stamp_tween.tween_property(stamp_rect, "modulate:a", 1.0, 0.06)
		stamp_tween.parallel().tween_property(stamp_rect, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		stamp_tween.parallel().tween_property(stamp_rect, "rotation", -0.14, 0.26)
	
	var reward_tween := create_tween()
	reward_tween.tween_interval(0.3)
	reward_tween.tween_property(bottom_reward, "modulate:a", 1.0, 0.15)
	reward_tween.parallel().tween_property(bottom_reward, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_quest_celebration_ended(_quest: QuestData) -> void:
	if confetti:
		confetti.emitting = false
		
	var tween := create_tween()
	tween.tween_property(celebration_overlay, "modulate:a", 0.0, 0.5)
	await tween.finished
	celebration_overlay.visible = false
	if stamp_rect:
		stamp_rect.visible = false
	is_celebrating = false
	if not _is_toast_showing and not _toast_queue.is_empty():
		_process_next_toast()
