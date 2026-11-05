extends Control
class_name InventoryMenu

signal opened
signal closed

enum MenuTab {
	CASES,
	EVIDENCE
}

enum EvidenceFilter {
	EVIDENCE,  ## Asservate, Beweismittel & Quest-Items
	TOOLS,     ## Werkzeuge, Ausrüstung & Movement-Gear
	ALL        ## Alle Gegenstände
}

const TOTAL_SLOTS: int = 16

# Tab navigation
@onready var cases_tab_btn: Button = %CasesTabButton
@onready var evidence_tab_btn: Button = %EvidenceTabButton
@onready var cases_view: Control = %CasesView
@onready var evidence_view: Control = %EvidenceView

# Cases (Questlog) view nodes
@onready var filter_active_btn: Button = %FilterActiveBtn
@onready var filter_completed_btn: Button = %FilterCompletedBtn
@onready var cases_list_vbox: VBoxContainer = %CasesListVBox
@onready var cases_empty_label: Label = %CasesEmptyLabel

@onready var case_detail_title: Label = %CaseDetailTitle
@onready var case_detail_category: Label = %CaseDetailCategory
@onready var case_status_badge: Label = %CaseStatusBadge
@onready var case_detail_desc: Label = %CaseDetailDesc
@onready var objectives_vbox: VBoxContainer = %ObjectivesVBox
@onready var case_turn_in_hint: Label = %CaseTurnInHint
@onready var case_rewards_label: Label = %CaseRewardsLabel
@onready var case_closed_stamp: TextureRect = %CaseClosedStamp

# Evidence (Inventory) view nodes
@onready var rucksack_label: Label = %RucksackLabel if has_node("%RucksackLabel") else null
@onready var filter_evidence_btn: Button = %FilterEvidenceBtn if has_node("%FilterEvidenceBtn") else null
@onready var filter_tools_btn: Button = %FilterToolsBtn if has_node("%FilterToolsBtn") else null
@onready var filter_all_btn: Button = %FilterAllBtn if has_node("%FilterAllBtn") else null
@onready var slots_grid: GridContainer = %SlotsGrid
@onready var capacity_label: Label = %CapacityLabel
@onready var currency_bar: HBoxContainer = %CurrencyBar if has_node("%CurrencyBar") else null

# Evidence Detail panel
@onready var detail_title: Label = %DetailTitle
@onready var detail_category: Label = %DetailCategory
@onready var detail_desc: Label = %DetailDesc
@onready var detail_count: Label = %DetailCount
@onready var preview_pivot: Node3D = %ItemPreviewPivot
@onready var preview_container: Control = %PreviewContainer
@onready var no_model_label: Label = %NoModelLabel if has_node("%NoModelLabel") else null

# Header & Footer
@onready var close_btn: Button = %CloseButton
@onready var close_bottom_btn: Button = %CloseBottomButton

var is_open: bool = false
var current_tab: MenuTab = MenuTab.CASES
var current_evidence_filter: EvidenceFilter = EvidenceFilter.EVIDENCE
var _showing_completed: bool = false
var _selected_quest_id: String = ""

# Evidence state
var _selected_slot_idx: int = -1
var _selected_currency_id: String = ""
var _slot_buttons: Array[Button] = []
var _currency_buttons: Array[Button] = []
var _case_buttons: Array[Button] = []
var _preview_model_instance: Node3D = null

# StyleBox references
var _tab_active_style: StyleBox = null
var _tab_inactive_style: StyleBox = null
var _tab_hover_style: StyleBox = null
var _filter_active_style: StyleBox = null
var _filter_inactive_style: StyleBox = null

func _ready() -> void:
	visible = false
	
	# Cache styles from scene
	if cases_tab_btn:
		_tab_active_style = cases_tab_btn.get_theme_stylebox("normal")
		_tab_hover_style = cases_tab_btn.get_theme_stylebox("hover")
		cases_tab_btn.pressed.connect(func(): switch_tab(MenuTab.CASES))
	if evidence_tab_btn:
		_tab_inactive_style = evidence_tab_btn.get_theme_stylebox("normal")
		evidence_tab_btn.pressed.connect(func(): switch_tab(MenuTab.EVIDENCE))
		
	if filter_active_btn:
		_filter_active_style = filter_active_btn.get_theme_stylebox("normal")
		filter_active_btn.pressed.connect(func(): _set_cases_filter(false))
	if filter_completed_btn:
		_filter_inactive_style = filter_completed_btn.get_theme_stylebox("normal")
		filter_completed_btn.pressed.connect(func(): _set_cases_filter(true))
		
	if filter_evidence_btn:
		filter_evidence_btn.pressed.connect(func(): _set_evidence_filter(EvidenceFilter.EVIDENCE))
	if filter_tools_btn:
		filter_tools_btn.pressed.connect(func(): _set_evidence_filter(EvidenceFilter.TOOLS))
	if filter_all_btn:
		filter_all_btn.pressed.connect(func(): _set_evidence_filter(EvidenceFilter.ALL))
		
	_create_slots()
	
	if close_btn:
		close_btn.pressed.connect(close_menu)
	if close_bottom_btn:
		close_bottom_btn.pressed.connect(close_menu)
		
	# Inventory signals
	var inv = get_node_or_null("/root/InventoryManager")
	if inv:
		inv.inventory_updated.connect(_on_inventory_updated)
		
	# Quest signals
	var qm = get_node_or_null("/root/QuestManager")
	if qm:
		qm.quest_started.connect(_on_quest_event)
		qm.quest_ready_to_turn_in.connect(_on_quest_event)
		qm.quest_completed.connect(_on_quest_completed_event)
		qm.quest_objective_updated.connect(_on_quest_event)
		qm.quest_objective_completed.connect(_on_quest_event)

func _process(delta: float) -> void:
	if is_open and current_tab == MenuTab.EVIDENCE and preview_pivot and _preview_model_instance:
		preview_pivot.rotation.y += delta * 1.2

func _unhandled_input(event: InputEvent) -> void:
	var st = get_node_or_null("/root/SceneTransition")
	if st and st.get("is_transitioning") == true:
		return
	var rm = get_node_or_null("/root/RoomManager")
	if rm and rm.get("is_transitioning") == true:
		return
	var hud = get_tree().root.find_child("HUD", true, false)
	if hud and (hud.is_dialogue_active or hud.is_celebrating):
		return
	var pause_menu = get_tree().root.find_child("PauseMenu", true, false)
	if pause_menu and pause_menu.is_open:
		return

	# [Q] / Quest Log Action
	if event.is_action_pressed("quest_log"):
		if not is_open:
			open_cases_tab()
		elif current_tab != MenuTab.CASES:
			switch_tab(MenuTab.CASES)
		else:
			close_menu()
		get_viewport().set_input_as_handled()
		return

	# [I] / Inventory Action
	if event.is_action_pressed("inventory"):
		if not is_open:
			open_evidence_tab()
		elif current_tab != MenuTab.EVIDENCE:
			switch_tab(MenuTab.EVIDENCE)
		else:
			close_menu()
		get_viewport().set_input_as_handled()
		return

	# Direct keycode fallback for Q, J, I, TAB
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q or event.keycode == KEY_J:
			if not is_open:
				open_cases_tab()
			elif current_tab != MenuTab.CASES:
				switch_tab(MenuTab.CASES)
			else:
				close_menu()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_I:
			if not is_open:
				open_evidence_tab()
			elif current_tab != MenuTab.EVIDENCE:
				open_evidence_tab()
			else:
				close_menu()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_U:
			if not is_open:
				open_tools_tab()
			elif current_tab != MenuTab.EVIDENCE or current_evidence_filter != EvidenceFilter.TOOLS:
				open_tools_tab()
			else:
				close_menu()
			get_viewport().set_input_as_handled()
			return
		elif is_open and event.keycode == KEY_TAB:
			if current_tab == MenuTab.CASES:
				open_evidence_tab()
			else:
				if current_evidence_filter == EvidenceFilter.EVIDENCE:
					_set_evidence_filter(EvidenceFilter.TOOLS)
				elif current_evidence_filter == EvidenceFilter.TOOLS:
					_set_evidence_filter(EvidenceFilter.ALL)
				else:
					switch_tab(MenuTab.CASES)
			get_viewport().set_input_as_handled()
			return

	# Close with ESC / Cancel
	if is_open and (event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE)):
		close_menu()
		get_viewport().set_input_as_handled()

func toggle_menu(preferred_tab: MenuTab = MenuTab.CASES) -> void:
	if is_open:
		if current_tab == preferred_tab:
			close_menu()
		else:
			switch_tab(preferred_tab)
	else:
		open_menu(preferred_tab)

func open_cases_tab() -> void:
	open_menu(MenuTab.CASES)

func open_evidence_tab() -> void:
	open_menu(MenuTab.EVIDENCE)
	var inv = get_node_or_null("/root/InventoryManager")
	if inv:
		var reg_count: int = inv.get_regular_items().size() if inv.has_method("get_regular_items") else 0
		var eq_count: int = inv.get_equipment_items().size() if inv.has_method("get_equipment_items") else 0
		if reg_count == 0 and eq_count > 0:
			_set_evidence_filter(EvidenceFilter.TOOLS)
			return
	_set_evidence_filter(EvidenceFilter.EVIDENCE)

func open_tools_tab() -> void:
	open_menu(MenuTab.EVIDENCE)
	_set_evidence_filter(EvidenceFilter.TOOLS)

func open_menu(tab: MenuTab = MenuTab.CASES) -> void:
	is_open = true
	visible = true
	if get_tree():
		get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	switch_tab(tab)
	opened.emit()

func close_menu() -> void:
	is_open = false
	visible = false
	_clear_preview_model()
	if get_tree():
		get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()

func switch_tab(tab: MenuTab) -> void:
	current_tab = tab
	_update_tab_buttons_ui()
	
	if current_tab == MenuTab.CASES:
		if cases_view:
			cases_view.visible = true
		if evidence_view:
			evidence_view.visible = false
		_clear_preview_model()
		refresh_cases()
	else:
		if cases_view:
			cases_view.visible = false
		if evidence_view:
			evidence_view.visible = true
		refresh_inventory()
		_select_default_evidence_slot()

func _update_tab_buttons_ui() -> void:
	if not cases_tab_btn or not evidence_tab_btn:
		return
		
	var active_color := Color(0.96, 0.94, 0.88, 1.0)
	var inactive_color := Color(0.75, 0.70, 0.60, 0.85)
	
	if current_tab == MenuTab.CASES:
		if _tab_active_style:
			cases_tab_btn.add_theme_stylebox_override("normal", _tab_active_style)
			cases_tab_btn.add_theme_stylebox_override("pressed", _tab_active_style)
		if _tab_inactive_style:
			evidence_tab_btn.add_theme_stylebox_override("normal", _tab_inactive_style)
			evidence_tab_btn.add_theme_stylebox_override("pressed", _tab_inactive_style)
		cases_tab_btn.add_theme_color_override("font_color", active_color)
		evidence_tab_btn.add_theme_color_override("font_color", inactive_color)
	else:
		if _tab_active_style:
			evidence_tab_btn.add_theme_stylebox_override("normal", _tab_active_style)
			evidence_tab_btn.add_theme_stylebox_override("pressed", _tab_active_style)
		if _tab_inactive_style:
			cases_tab_btn.add_theme_stylebox_override("normal", _tab_inactive_style)
			cases_tab_btn.add_theme_stylebox_override("pressed", _tab_inactive_style)
		evidence_tab_btn.add_theme_color_override("font_color", active_color)
		cases_tab_btn.add_theme_color_override("font_color", inactive_color)

# =========================================================================
# CASES (QUEST LOG) SYSTEM
# =========================================================================

func _set_cases_filter(showing_completed: bool) -> void:
	_showing_completed = showing_completed
	_update_cases_filter_ui()
	_populate_cases_list()

func _update_cases_filter_ui() -> void:
	if not filter_active_btn or not filter_completed_btn:
		return
		
	var active_color := Color(0.96, 0.94, 0.88, 1.0)
	var inactive_color := Color(0.75, 0.70, 0.60, 0.85)
	
	if not _showing_completed:
		if _filter_active_style:
			filter_active_btn.add_theme_stylebox_override("normal", _filter_active_style)
			filter_active_btn.add_theme_stylebox_override("pressed", _filter_active_style)
		if _filter_inactive_style:
			filter_completed_btn.add_theme_stylebox_override("normal", _filter_inactive_style)
			filter_completed_btn.add_theme_stylebox_override("pressed", _filter_inactive_style)
		filter_active_btn.add_theme_color_override("font_color", active_color)
		filter_completed_btn.add_theme_color_override("font_color", inactive_color)
	else:
		if _filter_active_style:
			filter_completed_btn.add_theme_stylebox_override("normal", _filter_active_style)
			filter_completed_btn.add_theme_stylebox_override("pressed", _filter_active_style)
		if _filter_inactive_style:
			filter_active_btn.add_theme_stylebox_override("normal", _filter_inactive_style)
			filter_active_btn.add_theme_stylebox_override("pressed", _filter_inactive_style)
		filter_completed_btn.add_theme_color_override("font_color", active_color)
		filter_active_btn.add_theme_color_override("font_color", inactive_color)

func refresh_cases() -> void:
	_update_cases_filter_ui()
	_populate_cases_list()

func _populate_cases_list() -> void:
	if not cases_list_vbox:
		return
		
	for child in cases_list_vbox.get_children():
		child.queue_free()
	_case_buttons.clear()
	
	var qm = get_node_or_null("/root/QuestManager")
	if not qm:
		if cases_empty_label:
			cases_empty_label.text = "Inventory unavailable."
			cases_empty_label.visible = true
		_clear_case_details()
		return
		
	var all_quests: Array[QuestData] = qm.get_all_quests()
	var active_quests: Array[QuestData] = []
	var completed_quests: Array[QuestData] = []
	
	for q in all_quests:
		if qm.is_quest_completed(q.id):
			completed_quests.append(q)
		elif qm.is_quest_active(q.id):
			active_quests.append(q)
			
	# Update badge counts on filter buttons
	if filter_active_btn:
		filter_active_btn.text = "▶ Active Quests (%d)" % active_quests.size()
	if filter_completed_btn:
		filter_completed_btn.text = "✓ Completed Quests (%d)" % completed_quests.size()
		
	var target_list: Array[QuestData] = completed_quests if _showing_completed else active_quests
	
	if target_list.is_empty():
		if cases_empty_label:
			if _showing_completed:
				cases_empty_label.text = "Noch keine abgeschlossenen Quests.\nAbgeschlossene Quests erscheinen hier."
			else:
				cases_empty_label.text = "No active quests.\nTalk to NPCs to receive new tasks."
			cases_empty_label.visible = true
		_clear_case_details()
		return
		
	if cases_empty_label:
		cases_empty_label.visible = false
		
	var noir_font: Font = null
	var selected_btn_to_press: Button = null
	
	for quest in target_list:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 56)
		btn.focus_mode = Control.FOCUS_NONE
		btn.text = ""
		btn.set_meta("quest_id", quest.id)
		
		# Button styleboxes
		var b_normal := StyleBoxFlat.new()
		b_normal.content_margin_left = 12.0
		b_normal.content_margin_top = 8.0
		b_normal.content_margin_right = 12.0
		b_normal.content_margin_bottom = 8.0
		b_normal.bg_color = Color(0.14, 0.13, 0.12, 0.92)
		b_normal.border_color = Color(0.65, 0.55, 0.40, 0.45)
		b_normal.set_border_width_all(1)
		b_normal.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", b_normal)
		
		var b_hover := StyleBoxFlat.new()
		b_hover.content_margin_left = 12.0
		b_hover.content_margin_top = 8.0
		b_hover.content_margin_right = 12.0
		b_hover.content_margin_bottom = 8.0
		b_hover.bg_color = Color(0.22, 0.20, 0.17, 0.98)
		b_hover.border_color = Color(0.95, 0.82, 0.45, 0.9)
		b_hover.set_border_width_all(2)
		b_hover.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("hover", b_hover)
		
		var b_pressed := StyleBoxFlat.new()
		b_pressed.content_margin_left = 12.0
		b_pressed.content_margin_top = 8.0
		b_pressed.content_margin_right = 12.0
		b_pressed.content_margin_bottom = 8.0
		b_pressed.bg_color = Color(0.28, 0.23, 0.17, 0.98)
		b_pressed.border_color = Color(1.0, 0.88, 0.35, 1.0)
		b_pressed.set_border_width_all(2)
		b_pressed.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("pressed", b_pressed)
		
		# Inside container
		var vbox := VBoxContainer.new()
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.offset_left = 12
		vbox.offset_top = 6
		vbox.offset_right = -12
		vbox.offset_bottom = -6
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_theme_constant_override("separation", 2)
		
		# Title & Category Tag
		var top_row := HBoxContainer.new()
		top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var title_lbl := Label.new()
		title_lbl.text = quest.title
		if noir_font:
			title_lbl.add_theme_font_override("font", noir_font)
		title_lbl.add_theme_font_size_override("font_size", 15)
		title_lbl.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88, 1.0))
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_row.add_child(title_lbl)
		
		var tag_lbl := Label.new()
		tag_lbl.text = _get_category_tag(quest.category)
		if noir_font:
			tag_lbl.add_theme_font_override("font", noir_font)
		tag_lbl.add_theme_font_size_override("font_size", 11)
		tag_lbl.add_theme_color_override("font_color", Color(0.85, 0.70, 0.45, 0.85))
		tag_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_row.add_child(tag_lbl)
		
		vbox.add_child(top_row)
		
		# Subtitle / Status row
		var sub_lbl := Label.new()
		if noir_font:
			sub_lbl.add_theme_font_override("font", noir_font)
		sub_lbl.add_theme_font_size_override("font_size", 12)
		sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var is_ready: bool = qm.is_quest_ready_to_turn_in(quest.id) if qm else false
		var is_completed: bool = qm.is_quest_completed(quest.id) if qm else false
		
		if is_ready:
			var turn_npc = quest.turn_in_npc_id if not quest.turn_in_npc_id.is_empty() else quest.giver_npc_id
			sub_lbl.text = "★ BEREIT ZUR ABGABE (Auftraggeber: %s)" % turn_npc.capitalize()
			sub_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 1.0))
		elif is_completed:
			sub_lbl.text = "✓ Quest Completed"
			sub_lbl.add_theme_color_override("font_color", Color(0.65, 0.85, 0.65, 0.9))
		else:
			var curr_obj = quest.get_current_objective()
			if curr_obj:
				sub_lbl.text = "▶ %s" % curr_obj.get_progress_text()
			else:
				sub_lbl.text = "▶ In Progress"
			sub_lbl.add_theme_color_override("font_color", Color(0.85, 0.78, 0.65, 0.85))
			
		vbox.add_child(sub_lbl)
		btn.add_child(vbox)
		
		var q_data := quest
		var this_btn := btn
		btn.pressed.connect(func(): _select_case_button(q_data, this_btn))
		
		cases_list_vbox.add_child(btn)
		_case_buttons.append(btn)
		
		if _selected_quest_id == quest.id or selected_btn_to_press == null:
			selected_btn_to_press = btn
			
	if selected_btn_to_press:
		var q_id: String = selected_btn_to_press.get_meta("quest_id", "")
		var q_to_show = qm.get_quest(q_id)
		if q_to_show:
			_select_case_button(q_to_show, selected_btn_to_press)

func _get_category_tag(cat: QuestData.QuestCategory) -> String:
	match cat:
		QuestData.QuestCategory.MAIN:
			return "[HAUPTAUFTRAG]"
		QuestData.QuestCategory.SIDE:
			return "[NEBENFALL]"
		QuestData.QuestCategory.DISCOVERY:
			return "[NOTIZEN]"
		_:
			return "[FALL]"

func _select_case_button(quest: QuestData, selected_btn: Button) -> void:
	_selected_quest_id = quest.id
	
	# Update button border highlights
	for b in _case_buttons:
		var is_sel := (b == selected_btn)
		var norm_style: StyleBoxFlat = b.get_theme_stylebox("normal")
		if norm_style:
			norm_style.bg_color = Color(0.24, 0.20, 0.16, 0.98) if is_sel else Color(0.14, 0.13, 0.12, 0.92)
			norm_style.border_color = Color(1.0, 0.88, 0.35, 1.0) if is_sel else Color(0.65, 0.55, 0.40, 0.45)
			norm_style.set_border_width_all(2 if is_sel else 1)
			
	_show_case_details(quest)

func _show_case_details(quest: QuestData) -> void:
	if not case_detail_title:
		return
		
	var qm = get_node_or_null("/root/QuestManager")
	var is_completed = qm.is_quest_completed(quest.id) if qm else false
	var is_ready = qm.is_quest_ready_to_turn_in(quest.id) if qm else false
	
	case_detail_title.text = quest.title
	
	var cat_name := "NEBENFALL"
	match quest.category:
		QuestData.QuestCategory.MAIN: cat_name = "HAUPTAUFTRAG"
		QuestData.QuestCategory.SIDE: cat_name = "NEBENFALL"
		QuestData.QuestCategory.DISCOVERY: cat_name = "NOTIZEN"
		
	var giver_name: String = quest.giver_npc_id.capitalize() if not quest.giver_npc_id.is_empty() else "Unbekannt"
	case_detail_category.text = "[ %s ]  •  AUFTRAGGEBER: %s" % [cat_name, giver_name]
	
	# Status Badge & Case Closed Stamp
	if is_completed:
		case_status_badge.text = "[ STATUS: COMPLETED ]"
		case_status_badge.add_theme_color_override("font_color", Color(0.65, 0.88, 0.65, 1.0))
		if case_closed_stamp:
			case_closed_stamp.visible = true
			case_closed_stamp.rotation = -0.12
	elif is_ready:
		case_status_badge.text = "[ STATUS: ZIEL ERREICHT - ABGABE BEREIT ]"
		case_status_badge.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 1.0))
		if case_closed_stamp:
			case_closed_stamp.visible = false
	else:
		case_status_badge.text = "[ STATUS: IN PROGRESS ]"
		case_status_badge.add_theme_color_override("font_color", Color(0.85, 0.78, 0.65, 0.9))
		if case_closed_stamp:
			case_closed_stamp.visible = false
			
	case_detail_desc.text = quest.description
	
	# Objectives checklist
	if objectives_vbox:
		for child in objectives_vbox.get_children():
			child.queue_free()
			
		var noir_font: Font = null
		var objs := quest.objectives
		
		if objs.is_empty() and not quest.target_item_id.is_empty():
			# Legacy fetch quest fallback
			var row := HBoxContainer.new()
			var check_lbl := Label.new()
			check_lbl.text = "[✓] " if is_ready or is_completed else "[  ] "
			check_lbl.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5) if (is_ready or is_completed) else Color(0.8, 0.75, 0.65))
			if noir_font:
				check_lbl.add_theme_font_override("font", noir_font)
			check_lbl.add_theme_font_size_override("font_size", 14)
			row.add_child(check_lbl)
			
			var desc_lbl := Label.new()
			desc_lbl.text = "Finde %d %s" % [quest.target_item_count, quest.target_item_id.capitalize()]
			desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if noir_font:
				desc_lbl.add_theme_font_override("font", noir_font)
			desc_lbl.add_theme_font_size_override("font_size", 13)
			desc_lbl.add_theme_color_override("font_color", Color(0.92, 0.90, 0.85))
			row.add_child(desc_lbl)
			objectives_vbox.add_child(row)
		else:
			for obj in objs:
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 6)
				
				var check_lbl := Label.new()
				var done: bool = obj.is_completed() or is_completed
				check_lbl.text = "[✓] " if done else "[  ] "

				check_lbl.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5) if done else Color(0.8, 0.75, 0.65))
				if noir_font:
					check_lbl.add_theme_font_override("font", noir_font)
				check_lbl.add_theme_font_size_override("font_size", 14)
				row.add_child(check_lbl)
				
				var desc_lbl := Label.new()
				desc_lbl.text = obj.get_progress_text() if not is_completed else obj.description
				desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				if noir_font:
					desc_lbl.add_theme_font_override("font", noir_font)
				desc_lbl.add_theme_font_size_override("font_size", 13)
				desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.82) if done else Color(0.94, 0.92, 0.86))
				row.add_child(desc_lbl)
				objectives_vbox.add_child(row)
				
	# Turn in hint
	if case_turn_in_hint:
		if is_ready:
			var turn_npc = quest.turn_in_npc_id if not quest.turn_in_npc_id.is_empty() else quest.giver_npc_id
			case_turn_in_hint.text = "➔ READY! Talk to %s to complete the quest." % turn_npc.capitalize()
			case_turn_in_hint.visible = true
		else:
			case_turn_in_hint.visible = false
			
	# Rewards
	if case_rewards_label:
		var reward_parts: Array[String] = []
		if not quest.reward_item_id.is_empty():
			var inv = get_node_or_null("/root/InventoryManager")
			var item_data = inv.get_item_data(quest.reward_item_id) if inv else null
			var item_name: String = item_data.name if item_data else quest.reward_item_id.capitalize()
			reward_parts.append("%dx %s" % [maxi(quest.reward_item_count, 1), item_name])
		if quest.energy_reward > 0:
			reward_parts.append("%d Energie" % quest.energy_reward)
		if quest.coin_reward > 0:
			reward_parts.append("%d Coins" % quest.coin_reward)
			
		if reward_parts.is_empty():
			case_rewards_label.text = "REWARD: None"
		else:
			case_rewards_label.text = "REWARD:  " + "  •  ".join(reward_parts)

func _clear_case_details() -> void:
	if case_detail_title:
		case_detail_title.text = "No Quest Selected"
	if case_detail_category:
		case_detail_category.text = "[ INVENTORY ]"
	if case_status_badge:
		case_status_badge.text = "[ STATUS: INAKTIV ]"
	if case_detail_desc:
		case_detail_desc.text = "No details available for this entry."
	if objectives_vbox:
		for child in objectives_vbox.get_children():
			child.queue_free()
	if case_turn_in_hint:
		case_turn_in_hint.visible = false
	if case_closed_stamp:
		case_closed_stamp.visible = false
	if case_rewards_label:
		case_rewards_label.text = "REWARD: -"

func _on_quest_event(_quest: QuestData, _extra = null) -> void:
	if is_open and current_tab == MenuTab.CASES:
		refresh_cases()

func _on_quest_completed_event(_quest: QuestData, _reward: int) -> void:
	if is_open and current_tab == MenuTab.CASES:
		refresh_cases()

# =========================================================================
# EVIDENCE (INVENTORY) SYSTEM
# =========================================================================

func _create_slots() -> void:
	if not slots_grid:
		return
	for child in slots_grid.get_children():
		child.queue_free()
	_slot_buttons.clear()
	
	var noir_font: Font = null
	
	for i in range(TOTAL_SLOTS):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(72, 72)
		btn.focus_mode = Control.FOCUS_NONE
		btn.text = ""
		
		# Slot StyleBoxes (Noir Detective evidence tags)
		var style_n := StyleBoxFlat.new()
		style_n.bg_color = Color(0.14, 0.13, 0.12, 0.88)
		style_n.border_color = Color(0.72, 0.60, 0.44, 0.5)
		style_n.set_border_width_all(1)
		style_n.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", style_n)
		
		var style_h := StyleBoxFlat.new()
		style_h.bg_color = Color(0.24, 0.22, 0.18, 0.95)
		style_h.border_color = Color(0.95, 0.82, 0.45, 0.95)
		style_h.set_border_width_all(2)
		style_h.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("hover", style_h)
		
		var style_p := StyleBoxFlat.new()
		style_p.bg_color = Color(0.48, 0.16, 0.16, 0.95)
		style_p.border_color = Color(0.95, 0.82, 0.45, 1.0)
		style_p.set_border_width_all(2)
		style_p.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("pressed", style_p)
		
		# Icon TextureRect
		var icon_rect := TextureRect.new()
		icon_rect.name = "ItemIcon"
		icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_rect.offset_left = 6
		icon_rect.offset_top = 6
		icon_rect.offset_right = -6
		icon_rect.offset_bottom = -6
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon_rect)
		
		# Placeholder Panel (für Items ohne Textur/Icon)
		var placeholder_panel := PanelContainer.new()
		placeholder_panel.name = "PlaceholderPanel"
		placeholder_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		placeholder_panel.offset_left = 8
		placeholder_panel.offset_top = 8
		placeholder_panel.offset_right = -8
		placeholder_panel.offset_bottom = -8
		placeholder_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var p_style := StyleBoxFlat.new()
		p_style.bg_color = Color(0.18, 0.16, 0.14, 0.9)
		p_style.border_color = Color(0.72, 0.60, 0.44, 0.4)
		p_style.set_border_width_all(1)
		p_style.set_corner_radius_all(4)
		placeholder_panel.add_theme_stylebox_override("panel", p_style)
		
		var placeholder_lbl := Label.new()
		placeholder_lbl.name = "PlaceholderLabel"
		placeholder_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		placeholder_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if noir_font:
			placeholder_lbl.add_theme_font_override("font", noir_font)
		placeholder_lbl.add_theme_font_size_override("font_size", 14)
		placeholder_lbl.add_theme_color_override("font_color", Color(0.92, 0.88, 0.80, 0.95))
		placeholder_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		placeholder_panel.add_child(placeholder_lbl)
		placeholder_panel.visible = false
		btn.add_child(placeholder_panel)
		
		# Count Label
		var count_lbl := Label.new()
		count_lbl.name = "CountLabel"
		count_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		count_lbl.offset_left = -34
		count_lbl.offset_top = -22
		count_lbl.offset_right = -4
		count_lbl.offset_bottom = -2
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		if noir_font:
			count_lbl.add_theme_font_override("font", noir_font)
		count_lbl.add_theme_font_size_override("font_size", 13)
		count_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.85, 1.0))
		count_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
		count_lbl.add_theme_constant_override("shadow_offset_x", 1)
		count_lbl.add_theme_constant_override("shadow_offset_y", 1)
		count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(count_lbl)
		
		var slot_idx := i
		btn.pressed.connect(func(): select_slot(slot_idx))
		slots_grid.add_child(btn)
		_slot_buttons.append(btn)

func _set_evidence_filter(filter: EvidenceFilter) -> void:
	current_evidence_filter = filter
	_update_evidence_filter_ui()
	refresh_inventory()
	_select_default_evidence_slot()

func _update_evidence_filter_ui() -> void:
	if not filter_evidence_btn or not filter_tools_btn or not filter_all_btn:
		return
		
	var active_color := Color(0.96, 0.94, 0.88, 1.0)
	var inactive_color := Color(0.75, 0.70, 0.60, 0.85)
	
	var filter_btns := [
		{"btn": filter_evidence_btn, "active": current_evidence_filter == EvidenceFilter.EVIDENCE},
		{"btn": filter_tools_btn, "active": current_evidence_filter == EvidenceFilter.TOOLS},
		{"btn": filter_all_btn, "active": current_evidence_filter == EvidenceFilter.ALL}
	]
	
	for fb in filter_btns:
		var btn: Button = fb["btn"]
		var is_active: bool = fb["active"]
		if is_active:
			if _filter_active_style:
				btn.add_theme_stylebox_override("normal", _filter_active_style)
				btn.add_theme_stylebox_override("pressed", _filter_active_style)
			btn.add_theme_color_override("font_color", active_color)
		else:
			if _filter_inactive_style:
				btn.add_theme_stylebox_override("normal", _filter_inactive_style)
				btn.add_theme_stylebox_override("pressed", _filter_inactive_style)
			btn.add_theme_color_override("font_color", inactive_color)

func _on_inventory_updated() -> void:
	if is_open and current_tab == MenuTab.EVIDENCE:
		refresh_inventory()

func refresh_inventory() -> void:
	var inv = get_node_or_null("/root/InventoryManager")
	if not inv:
		return
		
	_update_evidence_filter_ui()
		
	var all_items: Dictionary = inv.get_all_items()
	var regular_items: Array[String] = []
	var evidence_items: Array[String] = []
	var tool_items: Array[String] = []
	var currency_items: Array[String] = []
	
	for id in all_items.keys():
		var data: ItemData = inv.get_item_data(id)
		var is_tool: bool = (data != null and data.category == ItemData.Category.TOOL) or (inv.has_method("is_equipment") and inv.is_equipment(id))
		if data and data.is_currency:
			currency_items.append(id)
		else:
			regular_items.append(id)
			if is_tool:
				tool_items.append(id)
			else:
				evidence_items.append(id)
			
	if not currency_items.has("battery") and (inv.get_energy() > 0 or inv.get_item_data("battery") != null):
		currency_items.append("battery")
		
	if filter_evidence_btn:
		filter_evidence_btn.text = "🔍 Items (%d)" % evidence_items.size()
	if filter_tools_btn:
		filter_tools_btn.text = "⚙️ Equipment (%d)" % tool_items.size()
	if filter_all_btn:
		filter_all_btn.text = "📦 All (%d)" % regular_items.size()
		
	var active_list: Array[String] = []
	match current_evidence_filter:
		EvidenceFilter.TOOLS:
			active_list = tool_items
			if rucksack_label:
				rucksack_label.text = "E Q U I P M E N T   &   T O O L S"
		EvidenceFilter.ALL:
			active_list = regular_items
			if rucksack_label:
				rucksack_label.text = "A L L   I T E M S"
		_:
			active_list = evidence_items
			if rucksack_label:
				rucksack_label.text = "A S S E R V A T E N - L I S T E"
		
	var occupied_count: int = mini(active_list.size(), TOTAL_SLOTS)
	if capacity_label:
		if inv.force_full:
			capacity_label.text = "%d / %d (VOLL)" % [occupied_count, TOTAL_SLOTS]
		else:
			match current_evidence_filter:
				EvidenceFilter.TOOLS:
					capacity_label.text = "%d / %d Equipment" % [occupied_count, TOTAL_SLOTS]
				EvidenceFilter.ALL:
					capacity_label.text = "%d / %d Items" % [occupied_count, TOTAL_SLOTS]
				_:
					capacity_label.text = "%d / %d Items" % [occupied_count, TOTAL_SLOTS]
		
	# 1. Regular Slots
	for i in range(TOTAL_SLOTS):
		var btn: Button = _slot_buttons[i]
		var icon_rect: TextureRect = btn.get_node("ItemIcon")
		var count_lbl: Label = btn.get_node("CountLabel")
		var placeholder_panel: PanelContainer = btn.get_node_or_null("PlaceholderPanel")
		var placeholder_lbl: Label = placeholder_panel.get_node("PlaceholderLabel") if placeholder_panel else null
		
		if i < active_list.size():
			var item_id := active_list[i]
			var count: int = all_items.get(item_id, 1)
			var data: ItemData = inv.get_item_data(item_id)
			
			btn.set_meta("item_id", item_id)
			btn.set_meta("count", count)
			btn.tooltip_text = data.name if data else item_id
			
			if data and data.icon:
				icon_rect.texture = data.icon
				icon_rect.visible = true
				if placeholder_panel:
					placeholder_panel.visible = false
			else:
				icon_rect.texture = null
				icon_rect.visible = false
				if placeholder_panel and placeholder_lbl:
					var display_name: String = data.name if data else item_id
					placeholder_lbl.text = _get_item_placeholder_text(display_name)

					placeholder_panel.visible = true
					
			count_lbl.text = str(count) if count > 1 else ""
			count_lbl.visible = true
		else:
			btn.remove_meta("item_id")
			btn.remove_meta("count")
			btn.tooltip_text = "Freies Fach"
			icon_rect.texture = null
			icon_rect.visible = false
			if placeholder_panel:
				placeholder_panel.visible = false
			count_lbl.text = ""
			count_lbl.visible = false
			
	# 2. Currency Bar
	if currency_bar:
		for child in currency_bar.get_children():
			child.queue_free()
		_currency_buttons.clear()
		
		var noir_font: Font = null
		
		for curr_id in currency_items:
			var data: ItemData = inv.get_item_data(curr_id)
			var count: int = inv.get_energy() if curr_id == "battery" else all_items.get(curr_id, 0)
			
			var c_btn := Button.new()
			c_btn.custom_minimum_size = Vector2(100, 32)
			c_btn.focus_mode = Control.FOCUS_NONE
			c_btn.set_meta("currency_id", curr_id)
			c_btn.set_meta("count", count)
			
			var c_style := StyleBoxFlat.new()
			c_style.bg_color = Color(0.16, 0.14, 0.12, 0.92)
			c_style.border_color = Color(0.95, 0.82, 0.45, 0.6)
			c_style.set_border_width_all(1)
			c_style.set_corner_radius_all(4)
			c_btn.add_theme_stylebox_override("normal", c_style)
			
			var c_box := HBoxContainer.new()
			c_box.set_anchors_preset(Control.PRESET_FULL_RECT)
			c_box.offset_left = 6
			c_box.offset_right = -6
			c_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			c_box.alignment = BoxContainer.ALIGNMENT_CENTER
			
			var c_icon := TextureRect.new()
			c_icon.custom_minimum_size = Vector2(20, 20)
			c_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			c_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			c_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if data and data.icon:
				c_icon.texture = data.icon
			elif curr_id == "battery":
						c_box.add_child(c_icon)
			
			var c_lbl := Label.new()
			c_lbl.text = "%d" % count
			if noir_font:
				c_lbl.add_theme_font_override("font", noir_font)
			c_lbl.add_theme_font_size_override("font_size", 13)
			c_lbl.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88, 1.0))
			c_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			c_box.add_child(c_lbl)
			
			c_btn.add_child(c_box)
			var captured_id := curr_id
			c_btn.pressed.connect(func(): select_currency(captured_id))
			currency_bar.add_child(c_btn)
			_currency_buttons.append(c_btn)

func _select_default_evidence_slot() -> void:
	if _slot_buttons.is_empty():
		return
	var first_occupied := -1
	for i in range(mini(_slot_buttons.size(), TOTAL_SLOTS)):
		if _slot_buttons[i].has_meta("item_id"):
			first_occupied = i
			break
	if first_occupied >= 0:
		select_slot(first_occupied)
	elif not _currency_buttons.is_empty():
		var first_curr: String = _currency_buttons[0].get_meta("currency_id", "")
		select_currency(first_curr)
	else:
		select_slot(0)

func select_slot(idx: int) -> void:
	if _slot_buttons.is_empty() or idx < 0 or idx >= _slot_buttons.size():
		return
	_selected_slot_idx = idx
	_selected_currency_id = ""
	_update_slot_highlights()
	_show_item_details(idx)


func select_currency(curr_id: String) -> void:
	_selected_slot_idx = -1
	_selected_currency_id = curr_id
	_update_slot_highlights()
	_show_currency_details(curr_id)

func _update_slot_highlights() -> void:
	for i in range(TOTAL_SLOTS):
		var btn: Button = _slot_buttons[i]
		var is_selected := (i == _selected_slot_idx)
		var style: StyleBoxFlat = btn.get_theme_stylebox("normal")
		if style:
			style.bg_color = Color(0.32, 0.15, 0.15, 0.95) if is_selected else Color(0.14, 0.13, 0.12, 0.88)
			style.border_color = Color(1.0, 0.88, 0.45, 1.0) if is_selected else Color(0.72, 0.60, 0.44, 0.5)
			style.set_border_width_all(2 if is_selected else 1)
			
	for c_btn in _currency_buttons:
		var curr_id: String = c_btn.get_meta("currency_id", "")
		var is_selected := (curr_id == _selected_currency_id)
		var c_style: StyleBoxFlat = c_btn.get_theme_stylebox("normal")
		if c_style:
			c_style.bg_color = Color(0.35, 0.22, 0.10, 0.95) if is_selected else Color(0.16, 0.14, 0.12, 0.92)
			c_style.border_color = Color(1.0, 0.88, 0.45, 1.0) if is_selected else Color(0.95, 0.82, 0.45, 0.6)
			c_style.set_border_width_all(2 if is_selected else 1)

func _show_currency_details(curr_id: String) -> void:
	_clear_preview_model()
	var inv = get_node_or_null("/root/InventoryManager")
	var data: ItemData = inv.get_item_data(curr_id) if inv else null
	var count: int = inv.get_energy() if curr_id == "battery" else (inv.get_item_count(curr_id) if inv else 0)
	
	if preview_container:
		preview_container.modulate.a = 1.0
		
	if data:
		detail_title.text = data.name
		detail_category.text = "HAUPT-ASSET"
		detail_desc.text = data.description
		detail_count.text = "Archiviert: %d" % count
		if data.model_scene and preview_pivot:
			var inst := data.model_scene.instantiate() as Node3D
			preview_pivot.add_child(inst)
			_preview_model_instance = inst
			_auto_fit_preview_model(inst)
		else:
			if no_model_label:
				no_model_label.text = "[ %s ]\nKeine 3D-Aufnahme" % _get_item_placeholder_text(data.name)
				no_model_label.visible = true
	else:
		detail_title.text = curr_id.capitalize()
		detail_category.text = "HAUPT-ASSET"
		detail_desc.text = "Currency for gear and upgrades."
		detail_count.text = "Archiviert: %d" % count
		if no_model_label:
			no_model_label.text = "[ %s ]\nKeine 3D-Aufnahme" % _get_item_placeholder_text(curr_id)
			no_model_label.visible = true

func _show_item_details(slot_idx: int) -> void:
	var btn: Button = _slot_buttons[slot_idx]
	_clear_preview_model()
	
	if not btn.has_meta("item_id"):
		match current_evidence_filter:
			EvidenceFilter.TOOLS:
				detail_title.text = "Empty Equipment Slot"
				detail_category.text = "[ EQUIPMENT ]"
				detail_category.add_theme_color_override("font_color", Color(0.96, 0.85, 0.35, 0.8))
				detail_desc.text = "Equip tools and gear from your inventory."
			EvidenceFilter.ALL:
				detail_title.text = "Freies Fach"
				detail_category.text = "[ INVENTORY ]"
				detail_category.add_theme_color_override("font_color", Color(0.85, 0.75, 0.60, 0.8))
				detail_desc.text = "This inventory slot is currently empty."
			_:
				detail_title.text = "Freies Fach"
				detail_category.text = "[ LEERER PLATZ ]"
				detail_category.add_theme_color_override("font_color", Color(0.85, 0.75, 0.60, 0.8))
				detail_desc.text = "This slot is empty. Collected items will appear here."
		detail_count.text = "-"
		if preview_container:
			preview_container.modulate.a = 0.2
		if no_model_label:
			no_model_label.visible = false
		return
		
	var item_id: String = btn.get_meta("item_id")
	var count: int = btn.get_meta("count")
	var inv = get_node_or_null("/root/InventoryManager")
	var data: ItemData = inv.get_item_data(item_id) if inv else null
	if not data:
		var fallback_path := "res://resources/items/%s.tres" % item_id
		if ResourceLoader.exists(fallback_path):
			data = load(fallback_path) as ItemData
	
	if preview_container:
		preview_container.modulate.a = 1.0
		
	if data:
		detail_title.text = data.name
		if data.is_currency:
			detail_category.text = "[ MAIN CURRENCY / ENERGY ]"
			detail_category.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35, 1.0))
		elif data.category == ItemData.Category.TOOL:
			detail_category.text = "[ TOOLS & EQUIPMENT — ACTIVE ]"
			detail_category.add_theme_color_override("font_color", Color(0.96, 0.85, 0.35, 1.0))
		elif data.category == ItemData.Category.KEY_ITEM:
			detail_category.text = "[ GEGENSTAND ]"
			detail_category.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0, 1.0))
		elif data.category == ItemData.Category.CONSUMABLE:
			detail_category.text = "[ PROVIANT & VERBRAUCHSGUT ]"
			detail_category.add_theme_color_override("font_color", Color(0.45, 0.90, 0.55, 1.0))
		elif data.category == ItemData.Category.COLLECTIBLE:
			detail_category.text = "[ COLLECTIBLES & TREASURES ]"
			detail_category.add_theme_color_override("font_color", Color(0.85, 0.55, 0.95, 1.0))
		else:
			detail_category.text = "[ ASSERVAT & GEGENSTAND ]"
			detail_category.add_theme_color_override("font_color", Color(0.85, 0.75, 0.60, 0.9))
			
		var hint := ""
		match data.id:
			"glider":
				hint = "\n\n➔ EINSATZ: In der Luft [SPACE] halten zum Gleiten."
			"rail_shoe":
				hint = "\n\n➔ EINSATZ: Auf Schienen springen zum Grinden."
			"flashlight", "lamp":
				hint = "\n\n➔ USE: Press [F] to toggle light."
		detail_desc.text = data.description + hint
		if data.category == ItemData.Category.TOOL:
			detail_count.text = "Status: Equipped (%d / %d)" % [count, data.max_stack]
		else:
			detail_count.text = "Archiviert: %d / %d" % [count, data.max_stack]
		
		# 3D Model Instance in preview viewport
		if data.model_scene and preview_pivot:
			var inst := data.model_scene.instantiate() as Node3D
			preview_pivot.add_child(inst)
			_preview_model_instance = inst
			_auto_fit_preview_model(inst)
		else:
			if no_model_label:
				no_model_label.text = "[ %s ]\nKeine 3D-Aufnahme" % _get_item_placeholder_text(data.name)
				no_model_label.visible = true
	else:
		detail_title.text = item_id.capitalize()
		detail_category.text = "[ ASSERVAT ]"
		detail_category.add_theme_color_override("font_color", Color(0.85, 0.75, 0.60, 0.9))
		detail_desc.text = "An item from your inventory."
		detail_count.text = "Archiviert: %d" % count
		if no_model_label:
			no_model_label.text = "[ %s ]\nKeine 3D-Aufnahme" % _get_item_placeholder_text(item_id)
			no_model_label.visible = true

func _auto_fit_preview_model(inst: Node3D) -> void:
	inst.position = Vector3.ZERO
	inst.rotation = Vector3.ZERO
	inst.scale = Vector3.ONE
	
	var aabb := AABB()
	var first := true
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := mi as MeshInstance3D
		if mesh_inst and mesh_inst.mesh and mesh_inst.visible:
			var xf := Transform3D.IDENTITY
			var curr: Node = mesh_inst
			while curr and curr != inst:
				if curr is Node3D:
					xf = (curr as Node3D).transform * xf
				curr = curr.get_parent()
			var sub_aabb := xf * mesh_inst.mesh.get_aabb()
			if first:
				aabb = sub_aabb
				first = false
			else:
				aabb = aabb.merge(sub_aabb)
				
	if first or aabb.size.length_squared() < 0.00001:
		if no_model_label:
			no_model_label.visible = true
		return
		
	var sphere_diam := aabb.size.length()
	var max_dim := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	var effective_dim := maxf(max_dim * 1.15, sphere_diam)
	
	var target_size := 0.25
	var s := target_size / maxf(effective_dim, 0.001)
	inst.scale = Vector3.ONE * s
	
	var center := aabb.get_center()
	inst.position = -center * s + Vector3(0.0, 0.02, 0.0)

func _clear_preview_model() -> void:
	if no_model_label:
		no_model_label.visible = false
	if _preview_model_instance and is_instance_valid(_preview_model_instance):
		_preview_model_instance.queue_free()
		_preview_model_instance = null

func _get_item_placeholder_text(name_str: String) -> String:
	var clean := name_str.strip_edges()
	var words := clean.split(" ", false)
	if words.size() >= 2:
		if words[1].is_valid_int():
			return clean.left(2).to_upper()
		return (words[0].left(1) + words[1].left(1)).to_upper()
	elif clean.length() >= 2:
		return clean.left(2).to_upper()
	elif clean.length() == 1:
		return clean.to_upper()
	return "?"
