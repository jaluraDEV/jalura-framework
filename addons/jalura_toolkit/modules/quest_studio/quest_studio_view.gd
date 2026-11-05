@tool
class_name JaluraQuestStudioView
extends VBoxContainer

## Hauptansicht des Jalura Quest Studios.
## Ermöglicht das Durchsuchen, Analysieren und vollständige visuelle Editieren von Quests
## mit Live-Daten, Dropdowns für Items/NPCs, Drehbuch-Dialogschreiber und 1-Klick-Speichern.

const Scanner = preload("res://addons/jalura_toolkit/modules/quest_studio/quest_scanner.gd")

const QuestDataScript = preload("res://scripts/data/quest_data.gd")
const QuestObjectiveScript = preload("res://scripts/data/quest_objective.gd")
const ItemObjectiveScript = preload("res://scripts/data/item_objective.gd")
const TalkObjectiveScript = preload("res://scripts/data/talk_objective.gd")
const LocationObjectiveScript = preload("res://scripts/data/location_objective.gd")
const InteractObjectiveScript = preload("res://scripts/data/interact_objective.gd")
const CustomEventObjectiveScript = preload("res://scripts/data/custom_event_objective.gd")
const QuestCompletedConditionScript = preload("res://scripts/data/quest_completed_condition.gd")
const CreatorDialogScript = preload("res://addons/jalura_toolkit/modules/quest_studio/quest_creator_dialog.gd")
const QuestGraphViewScript = preload("res://addons/jalura_toolkit/modules/quest_studio/quest_graph_view.gd")

enum StudioMode {
	EDITOR = 0,
	GRAPH = 1
}

signal quest_selected(quest_info: Dictionary)
signal new_quest_requested()

# Studio Mode & Views
var current_mode: StudioMode = StudioMode.EDITOR
var creator_dialog: ConfirmationDialog
var quest_graph_view: Control
var split_container: HSplitContainer
var btn_mode_editor: Button
var btn_mode_graph: Button
var delete_confirm_dialog: ConfirmationDialog
var _quest_to_delete: Dictionary = {}

# UI Controls (Links / Toolbar)
var search_edit: LineEdit
var lbl_quest_count: Label
var cards_container: VBoxContainer
var detail_container: VBoxContainer
var empty_placeholder: Control
var detail_scroll: ScrollContainer
var btn_filter_all: Button
var btn_filter_main: Button
var btn_filter_side: Button
var btn_filter_discovery: Button

# UI Controls (Rechte Editor-Spalte)
var edit_title: LineEdit
var edit_id: LineEdit
var opt_category: OptionButton
var edit_description: TextEdit
var opt_giver_npc: OptionButton
var edit_giver_npc: LineEdit
var opt_turn_in_npc: OptionButton
var edit_turn_in_npc: LineEdit
var spin_priority: SpinBox
var chk_sequential: CheckBox
var chk_auto_start: CheckBox
var chk_consume_items: CheckBox

var objectives_vbox: VBoxContainer
var txt_dialogue_offer: TextEdit
var txt_dialogue_reminder: TextEdit
var txt_dialogue_turn_in: TextEdit
var txt_dialogue_after: TextEdit

var spin_coins: SpinBox
var spin_energy: SpinBox
var opt_reward_item: OptionButton
var spin_reward_count: SpinBox
var spin_dance_duration: SpinBox
var prerequisites_vbox: VBoxContainer
var lbl_save_status: Label

# Daten-Cache
var _all_quests: Array[Dictionary] = []
var _all_items: Array[Dictionary] = []
var _known_npcs: Array[String] = []
var _selected_quest: Dictionary = {}
var _current_filter_cat: int = -1 # -1 = Alle, 0 = MAIN, 1 = SIDE, 2 = DISCOVERY

# Editierbare Zwischenspeicher für die aktive Quest
var _edit_objectives: Array[Dictionary] = []
var _edit_prerequisites: Array[String] = []


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	_setup_ui()
	refresh_all()


func _setup_ui() -> void:
	# 1. Top Toolbar
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	add_child(toolbar)

	var title_lbl := Label.new()
	title_lbl.text = "📜 Jalura Quest Studio"
	title_lbl.add_theme_font_size_override("font_size", 14)
	toolbar.add_child(title_lbl)

	lbl_quest_count = Label.new()
	lbl_quest_count.text = "(0 Quests)"
	lbl_quest_count.modulate = Color(0.65, 0.75, 0.9)
	lbl_quest_count.add_theme_font_size_override("font_size", 12)
	toolbar.add_child(lbl_quest_count)

	toolbar.add_child(VSeparator.new())

	# Modus-Umschalter
	var btn_group := ButtonGroup.new()
	btn_mode_editor = Button.new()
	btn_mode_editor.text = "📝 Quest Editor"
	btn_mode_editor.toggle_mode = true
	btn_mode_editor.button_group = btn_group
	btn_mode_editor.button_pressed = (current_mode == StudioMode.EDITOR)
	btn_mode_editor.pressed.connect(func(): switch_to_mode(StudioMode.EDITOR))
	toolbar.add_child(btn_mode_editor)

	btn_mode_graph = Button.new()
	btn_mode_graph.text = "🕸️ Dependency Graph"
	btn_mode_graph.toggle_mode = true
	btn_mode_graph.button_group = btn_group
	btn_mode_graph.button_pressed = (current_mode == StudioMode.GRAPH)
	btn_mode_graph.pressed.connect(func(): switch_to_mode(StudioMode.GRAPH))
	toolbar.add_child(btn_mode_graph)

	toolbar.add_child(VSeparator.new())

	# Suchfeld
	search_edit = LineEdit.new()
	search_edit.placeholder_text = "🔍 Filter quests..."
	search_edit.custom_minimum_size = Vector2(200, 0)
	search_edit.clear_button_enabled = true
	search_edit.text_changed.connect(func(_t): _render_quest_list())
	toolbar.add_child(search_edit)

	# Kategorie-Filter
	btn_filter_all = Button.new()
	btn_filter_all.text = "All"
	btn_filter_all.pressed.connect(func(): _set_category_filter(-1))
	toolbar.add_child(btn_filter_all)

	btn_filter_main = Button.new()
	btn_filter_main.text = "🏆 Main Quests"
	btn_filter_main.pressed.connect(func(): _set_category_filter(0))
	toolbar.add_child(btn_filter_main)

	btn_filter_side = Button.new()
	btn_filter_side.text = "⚓ Side Quests"
	btn_filter_side.pressed.connect(func(): _set_category_filter(1))
	toolbar.add_child(btn_filter_side)

	btn_filter_discovery = Button.new()
	btn_filter_discovery.text = "🔍 Secrets"
	btn_filter_discovery.pressed.connect(func(): _set_category_filter(2))
	toolbar.add_child(btn_filter_discovery)

	toolbar.add_child(VSeparator.new())

	# Buttons
	var btn_reload := Button.new()
	btn_reload.text = "🔄 Reload"
	btn_reload.tooltip_text = "Rescans all quests from res://resources/quests/"
	btn_reload.pressed.connect(refresh_all)
	toolbar.add_child(btn_reload)

	var btn_new := Button.new()
	btn_new.text = "➕ New Quest"
	btn_new.modulate = Color(0.4, 1.2, 0.6)
	btn_new.pressed.connect(open_new_quest_wizard)
	toolbar.add_child(btn_new)

	add_child(HSeparator.new())

	# 2. Haupt-Inhalt: 2-Spalten Split
	var split := HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 360
	split_container = split
	add_child(split)

	# Linke Spalte: Quest-Explorer
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(320, 0)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 6)

	var list_header := Label.new()
	list_header.text = "QUEST EXPLORER"
	list_header.modulate = Color(0.5, 0.7, 1.0)
	list_header.add_theme_font_size_override("font_size", 11)
	left_vbox.add_child(list_header)

	var scroll_left := ScrollContainer.new()
	scroll_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_left.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	cards_container = VBoxContainer.new()
	cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_container.add_theme_constant_override("separation", 6)
	scroll_left.add_child(cards_container)
	left_vbox.add_child(scroll_left)

	left_panel.add_child(left_vbox)
	split.add_child(left_panel)

	# Rechte Spalte: Detail-Ansicht / Editor
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	detail_scroll = ScrollContainer.new()
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	detail_container = VBoxContainer.new()
	detail_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_container.add_theme_constant_override("separation", 14)
	detail_scroll.add_child(detail_container)
	right_panel.add_child(detail_scroll)

	# Leerer Zustand (Placeholder)
	empty_placeholder = _build_empty_placeholder()
	right_panel.add_child(empty_placeholder)

	split.add_child(right_panel)

	# 3. Quest-Abhängigkeitsgraph
	quest_graph_view = QuestGraphViewScript.new()
	quest_graph_view.open_quest_requested.connect(_on_graph_open_quest_requested)
	if quest_graph_view.has_signal("delete_quest_requested"):
		quest_graph_view.connect("delete_quest_requested", _prompt_delete_quest)
	add_child(quest_graph_view)

	# 4. 1-Klick Creator Dialog
	creator_dialog = CreatorDialogScript.new()
	creator_dialog.quest_created.connect(_on_quest_created)
	add_child(creator_dialog)

	# 5. Lösch-Bestätigungs-Dialog
	delete_confirm_dialog = ConfirmationDialog.new()
	delete_confirm_dialog.title = "⚠️ Delete Quest?"
	delete_confirm_dialog.ok_button_text = "🗑️ Yes, permanently delete quest"
	delete_confirm_dialog.cancel_button_text = "Cancel"
	delete_confirm_dialog.confirmed.connect(_on_delete_quest_confirmed)
	add_child(delete_confirm_dialog)

	# Initialen Modus aktivieren
	switch_to_mode(current_mode)


func switch_to_mode(mode: StudioMode) -> void:
	current_mode = mode
	if btn_mode_editor:
		btn_mode_editor.button_pressed = (mode == StudioMode.EDITOR)
	if btn_mode_graph:
		btn_mode_graph.button_pressed = (mode == StudioMode.GRAPH)

	if split_container:
		split_container.visible = (mode == StudioMode.EDITOR)
	if quest_graph_view:
		quest_graph_view.visible = (mode == StudioMode.GRAPH)
		if quest_graph_view.visible:
			quest_graph_view.load_and_build_graph()


func open_new_quest_wizard() -> void:
	if creator_dialog:
		creator_dialog.open_wizard(_all_items, _known_npcs)


func _on_quest_created(file_path: String, q_id: String) -> void:
	refresh_all()
	switch_to_mode(StudioMode.EDITOR)
	for q in _all_quests:
		if q["id"] == q_id or q["file_path"] == file_path:
			select_quest(q)
			break


func _on_graph_open_quest_requested(q_info: Dictionary) -> void:
	switch_to_mode(StudioMode.EDITOR)
	select_quest(q_info)


func _prompt_delete_quest(info: Dictionary) -> void:
	if info.is_empty():
		return
	_quest_to_delete = info
	var title_str: String = info.get("title", "Untitled")
	var file_name: String = info.get("file_path", "").get_file()
	delete_confirm_dialog.dialog_text = "Are you sure you want to permanently delete quest '%s' (%s)?\n\nThe associated .tres file will be deleted from disk." % [title_str, file_name]
	if delete_confirm_dialog.is_inside_tree():
		delete_confirm_dialog.popup_centered()


func _on_delete_quest_confirmed() -> void:
	if _quest_to_delete.is_empty():
		return

	var file_path: String = _quest_to_delete.get("file_path", "")
	var q_id: String = _quest_to_delete.get("id", "")

	if not file_path.is_empty():
		var global_p := ProjectSettings.globalize_path(file_path)
		if FileAccess.file_exists(file_path) or FileAccess.file_exists(global_p):
			DirAccess.remove_absolute(global_p)
			DirAccess.remove_absolute(file_path)

		var uid_path := file_path + ".uid"
		var global_uid := ProjectSettings.globalize_path(uid_path)
		if FileAccess.file_exists(uid_path) or FileAccess.file_exists(global_uid):
			DirAccess.remove_absolute(global_uid)
			DirAccess.remove_absolute(uid_path)

		print_rich("[color=yellow][b]🗑️ [Jalura Studio][/b][/color] Quest deleted: [b]%s[/b] -> [u]%s[/u]" % [q_id, file_path])

	_quest_to_delete = {}
	_selected_quest = {}
	refresh_all()
	if _all_quests.is_empty():
		_show_placeholder()


func refresh_all() -> void:
	if not lbl_quest_count or not cards_container:
		return

	_all_quests = Scanner.scan_all_quests()
	_all_items = Scanner.scan_all_items()
	_known_npcs = Scanner.get_known_npcs()

	lbl_quest_count.text = "(%d Quests)" % _all_quests.size()
	_render_quest_list()

	if quest_graph_view and quest_graph_view.visible:
		quest_graph_view.load_and_build_graph()

	# Wenn eine Quest aktiv war, wiederherstellen oder erste wählen
	if not _selected_quest.is_empty():
		var found := false
		for q in _all_quests:
			if q["id"] == _selected_quest["id"]:
				select_quest(q)
				found = true
				break
		if not found:
			_show_placeholder()
	elif not _all_quests.is_empty():
		select_quest(_all_quests[0])
	else:
		_show_placeholder()


func _set_category_filter(cat: int) -> void:
	_current_filter_cat = cat
	_render_quest_list()


func _render_quest_list() -> void:
	if not cards_container:
		return

	for child in cards_container.get_children():
		cards_container.remove_child(child)
		child.queue_free()

	var q := search_edit.text.strip_edges().to_lower()

	for info in _all_quests:
		# Kategorie-Filter
		if _current_filter_cat != -1 and info["category"] != _current_filter_cat:
			continue

		# Text-Suche
		if not q.is_empty():
			var title_str: String = info["title"].to_lower()
			var id_str: String = info["id"].to_lower()
			var giver_str: String = info["giver_npc_id"].to_lower()
			var desc_str: String = info["description"].to_lower()
			if not (title_str.contains(q) or id_str.contains(q) or giver_str.contains(q) or desc_str.contains(q)):
				continue

		var card := _create_quest_card(info)
		cards_container.add_child(card)


func _create_quest_card(info: Dictionary) -> Button:
	var btn := Button.new()
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 54)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var is_active: bool = (_selected_quest.get("id", "") == info["id"])
	if is_active:
		btn.modulate = Color(0.7, 1.1, 1.3)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 8
	hbox.offset_right = -8
	hbox.offset_top = 4
	hbox.offset_bottom = -4
	hbox.add_theme_constant_override("separation", 10)

	# Icon
	var cat_icon := Label.new()
	cat_icon.text = info["category_icon"]
	cat_icon.add_theme_font_size_override("font_size", 18)
	hbox.add_child(cat_icon)

	# Text-Spalte
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)

	var title_lbl := Label.new()
	title_lbl.text = info["title"]
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vbox.add_child(title_lbl)

	var sub_lbl := Label.new()
	var giver_text: String = info["giver_npc_id"] if not info["giver_npc_id"].is_empty() else "Unknown"
	sub_lbl.text = "%s • NPC: %s" % [info["id"], giver_text.capitalize()]
	sub_lbl.modulate = Color(0.6, 0.7, 0.8)
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vbox.add_child(sub_lbl)

	# Badges Zeile
	var badge_row := HBoxContainer.new()
	badge_row.add_theme_constant_override("separation", 6)

	var obj_badge := Label.new()
	obj_badge.text = "🎯 %d Objective%s" % [info["objectives_count"], "" if info["objectives_count"] == 1 else "s"]
	obj_badge.modulate = Color(0.4, 0.9, 0.6)
	obj_badge.add_theme_font_size_override("font_size", 10)
	badge_row.add_child(obj_badge)

	if info["prerequisites_count"] > 0:
		var pre_badge := Label.new()
		pre_badge.text = "🔗 %d Prereq." % info["prerequisites_count"]
		pre_badge.modulate = Color(1.0, 0.8, 0.3)
		pre_badge.add_theme_font_size_override("font_size", 10)
		badge_row.add_child(pre_badge)

	var rew_badge := Label.new()
	rew_badge.text = info["reward_summary"]
	rew_badge.modulate = Color(0.7, 0.8, 1.0)
	rew_badge.add_theme_font_size_override("font_size", 10)
	rew_badge.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	badge_row.add_child(rew_badge)

	vbox.add_child(badge_row)
	hbox.add_child(vbox)
	btn.add_child(hbox)

	btn.pressed.connect(func(): select_quest(info))
	return btn


## Wählt eine Quest aus und initialisiert den visuellen Editor
func select_quest(info: Dictionary) -> void:
	_selected_quest = info
	empty_placeholder.hide()
	detail_scroll.show()

	# Zwischenspeicher für Objectives und Voraussetzungen entpacken
	_unpack_quest_for_editing(info["quest_data"])

	# Liste auffrischen (aktiven Button highlighten)
	_render_quest_list()

	# Details & Editor aufbauen
	_render_quest_editor(info)
	quest_selected.emit(info)


func _show_placeholder() -> void:
	_selected_quest = {}
	empty_placeholder.show()
	detail_scroll.hide()


func _build_empty_placeholder() -> Control:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)

	var icon := Label.new()
	icon.text = "📜"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 48)
	vbox.add_child(icon)

	var lbl := Label.new()
	lbl.text = "Select a quest on the left or create a new one."
	lbl.modulate = Color(0.6, 0.7, 0.8)
	lbl.add_theme_font_size_override("font_size", 14)
	vbox.add_child(lbl)

	var btn := Button.new()
	btn.text = "➕ Create New Quest"
	btn.custom_minimum_size = Vector2(180, 36)
	btn.pressed.connect(open_new_quest_wizard)
	vbox.add_child(btn)

	center.add_child(vbox)
	return center


## Entpackt die Quest-Ressource in eine editierbare Zwischenstruktur
func _unpack_quest_for_editing(qd: QuestData) -> void:
	_edit_objectives.clear()
	for obj in qd.objectives:
		var type_key := "item"
		var target_val := ""
		if obj is ItemObjective or obj.get_script() == ItemObjectiveScript:
			type_key = "item"
			var i_id = obj.get("item_id")
			target_val = str(i_id) if i_id != null else ""
			if target_val.is_empty() and not qd.target_item_id.is_empty():
				target_val = qd.target_item_id
		elif obj is TalkObjective or obj.get_script() == TalkObjectiveScript:
			type_key = "talk"
			var n_id = obj.get("npc_id")
			target_val = str(n_id) if n_id != null else ""
		elif obj is LocationObjective or obj.get_script() == LocationObjectiveScript:
			type_key = "location"
			var l_id = obj.get("location_id")
			target_val = str(l_id) if l_id != null else ""
		elif obj is InteractObjective or obj.get_script() == InteractObjectiveScript:
			type_key = "interact"
			var a_id = obj.get("interactable_id")
			target_val = str(a_id) if a_id != null else ""
		elif obj is CustomEventObjective or obj.get_script() == CustomEventObjectiveScript:
			type_key = "custom"
			var e_id = obj.get("event_name")
			target_val = str(e_id) if e_id != null else ""

		var consume_val: bool = true
		if obj.get("consume_on_turn_in") != null:
			consume_val = bool(obj.get("consume_on_turn_in"))

		_edit_objectives.append({
			"type": type_key,
			"description": obj.description,
			"target_amount": obj.target_amount,
			"target_value": target_val,
			"optional": obj.optional,
			"hidden": obj.hidden_until_active,
			"consume": consume_val
		})

	_edit_prerequisites.clear()
	for pr in qd.prerequisites:
		if pr is QuestCompletedCondition:
			_edit_prerequisites.append((pr as QuestCompletedCondition).quest_id)


# ==========================================================
# VISUELLER QUEST-EDITOR (FORMULAR)
# ==========================================================

func _render_quest_editor(info: Dictionary) -> void:
	for child in detail_container.get_children():
		detail_container.remove_child(child)
		child.queue_free()

	var qd: QuestData = info["quest_data"]

	# 1. Action-Toolbar (Speichern, Verwerfen, Status)
	var action_bar := PanelContainer.new()
	var act_hbox := HBoxContainer.new()
	act_hbox.add_theme_constant_override("separation", 10)

	var icon_lbl := Label.new()
	icon_lbl.text = "%s %s" % [info["category_icon"], info["file_path"].get_file()]
	icon_lbl.add_theme_font_size_override("font_size", 13)
	icon_lbl.modulate = Color(0.4, 0.8, 1.0)
	act_hbox.add_child(icon_lbl)

	lbl_save_status = Label.new()
	lbl_save_status.text = ""
	lbl_save_status.modulate = Color(0.4, 1.2, 0.5)
	lbl_save_status.add_theme_font_size_override("font_size", 12)
	act_hbox.add_child(lbl_save_status)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	act_hbox.add_child(spacer)

	var btn_delete := Button.new()
	btn_delete.text = "🗑️ Delete Quest"
	btn_delete.modulate = Color(1.2, 0.45, 0.45)
	btn_delete.tooltip_text = "Permanently deletes this quest and its .tres file from the project"
	btn_delete.pressed.connect(func(): _prompt_delete_quest(info))
	act_hbox.add_child(btn_delete)

	var btn_revert := Button.new()
	btn_revert.text = "↩️ Revert"
	btn_revert.tooltip_text = "Reverts unsaved changes and reloads the quest"
	btn_revert.pressed.connect(func(): select_quest(info))
	act_hbox.add_child(btn_revert)

	var btn_save := Button.new()
	btn_save.text = "💾 Save Quest"
	btn_save.modulate = Color(0.3, 1.3, 0.5)
	btn_save.custom_minimum_size = Vector2(160, 32)
	btn_save.pressed.connect(save_current_quest)
	act_hbox.add_child(btn_save)

	action_bar.add_child(act_hbox)
	detail_container.add_child(action_bar)

	# 2. Sektion: Basisdaten & Beteiligte NPCs
	var sec_base := _create_section_card("📋 Basic Info & Involved NPCs")
	var grid_base := GridContainer.new()
	grid_base.columns = 2
	grid_base.add_theme_constant_override("h_separation", 16)
	grid_base.add_theme_constant_override("v_separation", 8)

	# Titel
	grid_base.add_child(_create_field_label("Quest Title:"))
	edit_title = LineEdit.new()
	edit_title.text = qd.title
	edit_title.placeholder_text = "e.g. A Coin for Mara"
	grid_base.add_child(edit_title)

	# Quest-ID
	grid_base.add_child(_create_field_label("Quest ID (Code/Save):"))
	edit_id = LineEdit.new()
	edit_id.text = qd.id if not qd.id.is_empty() else info["id"]
	edit_id.placeholder_text = "e.g. demo_bring_coin"
	grid_base.add_child(edit_id)

	# Kategorie
	grid_base.add_child(_create_field_label("Category:"))
	opt_category = OptionButton.new()
	opt_category.add_item("🏆 Main Quest (MAIN)", 0)
	opt_category.add_item("⚓ Side Quest (SIDE)", 1)
	opt_category.add_item("🔍 Discovery / Secret (DISCOVERY)", 2)
	opt_category.select(qd.category)
	grid_base.add_child(opt_category)

	# Geber-NPC
	grid_base.add_child(_create_field_label("Quest Giver NPC:"))
	var giver_box := HBoxContainer.new()
	opt_giver_npc = OptionButton.new()
	_populate_npc_dropdown(opt_giver_npc, qd.giver_npc_id)
	giver_box.add_child(opt_giver_npc)

	edit_giver_npc = LineEdit.new()
	edit_giver_npc.text = qd.giver_npc_id
	edit_giver_npc.placeholder_text = "Custom NPC ID..."
	edit_giver_npc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	giver_box.add_child(edit_giver_npc)
	opt_giver_npc.item_selected.connect(func(idx):
		var text_val = opt_giver_npc.get_item_metadata(idx)
		if text_val != null and not str(text_val).is_empty():
			edit_giver_npc.text = str(text_val)
	)
	grid_base.add_child(giver_box)

	# Abgabe-NPC
	grid_base.add_child(_create_field_label("Turn-in NPC:"))
	var turn_box := HBoxContainer.new()
	opt_turn_in_npc = OptionButton.new()
	_populate_npc_dropdown(opt_turn_in_npc, qd.turn_in_npc_id, true)
	turn_box.add_child(opt_turn_in_npc)

	edit_turn_in_npc = LineEdit.new()
	edit_turn_in_npc.text = qd.turn_in_npc_id
	edit_turn_in_npc.placeholder_text = "Empty = same as giver"
	edit_turn_in_npc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	turn_box.add_child(edit_turn_in_npc)
	opt_turn_in_npc.item_selected.connect(func(idx):
		var text_val = opt_turn_in_npc.get_item_metadata(idx)
		if text_val != null:
			edit_turn_in_npc.text = str(text_val)
	)
	grid_base.add_child(turn_box)

	# Priorität
	grid_base.add_child(_create_field_label("Priority for NPC:"))
	spin_priority = SpinBox.new()
	spin_priority.min_value = 0
	spin_priority.max_value = 99
	spin_priority.value = qd.priority
	spin_priority.tooltip_text = "Lower number = offered first by NPC"
	grid_base.add_child(spin_priority)

	sec_base.add_child(grid_base)

	# Beschreibung
	sec_base.add_child(_create_field_label("Description (Journal / Overview):"))
	edit_description = TextEdit.new()
	edit_description.custom_minimum_size = Vector2(0, 54)
	edit_description.text = qd.description
	edit_description.placeholder_text = "Short summary for the journal..."
	sec_base.add_child(edit_description)

	# Checkboxen
	var chk_box := HBoxContainer.new()
	chk_box.add_theme_constant_override("separation", 16)

	chk_sequential = CheckBox.new()
	chk_sequential.text = "Sequential Objectives"
	chk_sequential.tooltip_text = "When enabled, objective 2 unlocks only after objective 1 is complete."
	chk_sequential.button_pressed = qd.sequential_objectives
	chk_box.add_child(chk_sequential)

	chk_auto_start = CheckBox.new()
	chk_auto_start.text = "Auto-Start when conditions met"
	chk_auto_start.tooltip_text = "Starts automatically once all prerequisites are met."
	chk_auto_start.button_pressed = qd.auto_start
	chk_box.add_child(chk_auto_start)

	chk_consume_items = CheckBox.new()
	chk_consume_items.text = "Consume items on turn-in"
	chk_consume_items.tooltip_text = "Deducts required items from player inventory automatically."
	chk_consume_items.button_pressed = qd.consume_items_on_turn_in
	chk_box.add_child(chk_consume_items)

	sec_base.add_child(chk_box)
	detail_container.add_child(sec_base)

	# 3. Sektion: Ziele (Objectives) Baukasten
	var sec_obj := _create_section_card("🎯 Tasks & Objectives")

	# Buttons zum Hinzufügen von Zielen
	var add_obj_bar := HBoxContainer.new()
	add_obj_bar.add_theme_constant_override("separation", 8)

	var btn_add_item := Button.new()
	btn_add_item.text = "🍎 + Collect Item"
	btn_add_item.pressed.connect(func(): _add_new_objective("item"))
	add_obj_bar.add_child(btn_add_item)

	var btn_add_talk := Button.new()
	btn_add_talk.text = "🗣️ + Talk to NPC"
	btn_add_talk.pressed.connect(func(): _add_new_objective("talk"))
	add_obj_bar.add_child(btn_add_talk)

	var btn_add_loc := Button.new()
	btn_add_loc.text = "📍 + Reach Location"
	btn_add_loc.pressed.connect(func(): _add_new_objective("location"))
	add_obj_bar.add_child(btn_add_loc)

	var btn_add_act := Button.new()
	btn_add_act.text = "🔍 + Interact"
	btn_add_act.pressed.connect(func(): _add_new_objective("interact"))
	add_obj_bar.add_child(btn_add_act)

	var btn_add_cust := Button.new()
	btn_add_cust.text = "⚡ + Custom Event"
	btn_add_cust.pressed.connect(func(): _add_new_objective("custom"))
	add_obj_bar.add_child(btn_add_cust)

	sec_obj.add_child(add_obj_bar)

	objectives_vbox = VBoxContainer.new()
	objectives_vbox.add_theme_constant_override("separation", 8)
	sec_obj.add_child(objectives_vbox)

	_render_objectives_list()
	detail_container.add_child(sec_obj)

	# 4. Sektion: Drehbuch-Dialoge
	var sec_dia := _create_section_card("💬 Dialogues & Conversations (Script Format)")
	var hint_dia := Label.new()
	hint_dia.text = "💡 Tip: Each new line in the text field corresponds to one dialogue bubble in-game."
	hint_dia.modulate = Color(0.7, 0.8, 0.9)
	hint_dia.add_theme_font_size_override("font_size", 11)
	sec_dia.add_child(hint_dia)

	# 1. Angebot
	sec_dia.add_child(_create_field_label("📜 1. Offer (When NPC offers quest):"))
	txt_dialogue_offer = TextEdit.new()
	txt_dialogue_offer.custom_minimum_size = Vector2(0, 68)
	txt_dialogue_offer.text = "\n".join(qd.offer_dialogue)
	txt_dialogue_offer.placeholder_text = "First dialogue bubble...\nSecond dialogue bubble..."
	sec_dia.add_child(txt_dialogue_offer)

	# 2. Erinnerung
	sec_dia.add_child(_create_field_label("⏳ 2. Reminder (While quest is active):"))
	txt_dialogue_reminder = TextEdit.new()
	txt_dialogue_reminder.custom_minimum_size = Vector2(0, 54)
	txt_dialogue_reminder.text = "\n".join(qd.reminder_dialogue)
	txt_dialogue_reminder.placeholder_text = "What the NPC says while searching..."
	sec_dia.add_child(txt_dialogue_reminder)

	# 3. Abgabe
	sec_dia.add_child(_create_field_label("🎁 3. Turn-in (When all objectives are met):"))
	txt_dialogue_turn_in = TextEdit.new()
	txt_dialogue_turn_in.custom_minimum_size = Vector2(0, 68)
	txt_dialogue_turn_in.text = "\n".join(qd.turn_in_dialogue)
	txt_dialogue_turn_in.placeholder_text = "Big thank you and giving the reward..."
	sec_dia.add_child(txt_dialogue_turn_in)

	# 4. Danach
	sec_dia.add_child(_create_field_label("💭 4. Afterwards (Future conversations after completion):"))
	txt_dialogue_after = TextEdit.new()
	txt_dialogue_after.custom_minimum_size = Vector2(0, 54)
	txt_dialogue_after.text = "\n".join(qd.after_dialogue)
	txt_dialogue_after.placeholder_text = "Default phrase when speaking to them later..."
	sec_dia.add_child(txt_dialogue_after)

	detail_container.add_child(sec_dia)

	# 5. Sektion: Belohnungen & Voraussetzungen
	var sec_rew := _create_section_card("🎁 Rewards & Prerequisites")
	var grid_rew := GridContainer.new()
	grid_rew.columns = 2
	grid_rew.add_theme_constant_override("h_separation", 16)
	grid_rew.add_theme_constant_override("v_separation", 8)

	# Münzen
	grid_rew.add_child(_create_field_label("Coins / Reward Money:"))
	spin_coins = SpinBox.new()
	spin_coins.min_value = 0
	spin_coins.max_value = 9999
	spin_coins.value = qd.coin_reward
	grid_rew.add_child(spin_coins)

	# Energie
	grid_rew.add_child(_create_field_label("Energy / Stamina:"))
	spin_energy = SpinBox.new()
	spin_energy.min_value = 0
	spin_energy.max_value = 9999
	spin_energy.value = qd.energy_reward
	grid_rew.add_child(spin_energy)

	# Belohnungs-Item
	grid_rew.add_child(_create_field_label("Reward Item:"))
	var rew_item_box := HBoxContainer.new()
	opt_reward_item = OptionButton.new()
	opt_reward_item.add_item("(No Item)", 0)
	opt_reward_item.set_item_metadata(0, "")

	var selected_rew_idx := 0
	for i in range(_all_items.size()):
		var it: Dictionary = _all_items[i]
		var idx = opt_reward_item.item_count
		opt_reward_item.add_item("%s (%s)" % [it["name"], it["id"]], idx)
		opt_reward_item.set_item_metadata(idx, it["id"])
		if it["id"] == qd.reward_item_id:
			selected_rew_idx = idx

	if selected_rew_idx == 0 and not qd.reward_item_id.is_empty():
		var extra_idx = opt_reward_item.item_count
		opt_reward_item.add_item("%s (%s)" % [qd.reward_item_id.capitalize(), qd.reward_item_id], extra_idx)
		opt_reward_item.set_item_metadata(extra_idx, qd.reward_item_id)
		selected_rew_idx = extra_idx

	opt_reward_item.select(selected_rew_idx)
	rew_item_box.add_child(opt_reward_item)

	spin_reward_count = SpinBox.new()
	spin_reward_count.min_value = 1
	spin_reward_count.max_value = 99
	spin_reward_count.value = qd.reward_item_count if qd.reward_item_count > 0 else 1
	spin_reward_count.prefix = "x"
	rew_item_box.add_child(spin_reward_count)
	grid_rew.add_child(rew_item_box)

	# Tanz-Dauer
	grid_rew.add_child(_create_field_label("Victory Dance Duration (sec):"))
	spin_dance_duration = SpinBox.new()
	spin_dance_duration.min_value = 0.0
	spin_dance_duration.max_value = 10.0
	spin_dance_duration.step = 0.5
	spin_dance_duration.value = qd.completion_dance_duration
	grid_rew.add_child(spin_dance_duration)

	sec_rew.add_child(grid_rew)

	# Voraussetzungen
	sec_rew.add_child(HSeparator.new())
	sec_rew.add_child(_create_field_label("🔗 Quest Prerequisites (Must be completed first):"))

	prerequisites_vbox = VBoxContainer.new()
	prerequisites_vbox.add_theme_constant_override("separation", 6)
	sec_rew.add_child(prerequisites_vbox)

	var btn_add_prereq := Button.new()
	btn_add_prereq.text = "🔗 + Add Quest Prerequisite"
	btn_add_prereq.pressed.connect(_add_prerequisite_row)
	sec_rew.add_child(btn_add_prereq)

	_render_prerequisites_list()
	detail_container.add_child(sec_rew)


# ==========================================================
# OBJECTIVES BAUKASTEN
# ==========================================================

func _render_objectives_list() -> void:
	if not objectives_vbox:
		return

	for child in objectives_vbox.get_children():
		objectives_vbox.remove_child(child)
		child.queue_free()

	if _edit_objectives.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No objectives defined. Click a button above to add an objective."
		empty_lbl.modulate = Color(0.6, 0.6, 0.6)
		empty_lbl.add_theme_font_size_override("font_size", 12)
		objectives_vbox.add_child(empty_lbl)
		return

	for i in range(_edit_objectives.size()):
		var obj_data: Dictionary = _edit_objectives[i]
		var card := _build_objective_editor_card(i, obj_data)
		objectives_vbox.add_child(card)


func _build_objective_editor_card(index: int, data: Dictionary) -> PanelContainer:
	var p := PanelContainer.new()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	# Header-Zeile mit Icon, Typ, Reorder & Delete
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)

	var icon_name := "🎯"
	var type_label := "Objective"
	match data["type"]:
		"item":
			icon_name = "🍎"
			type_label = "Collect Item"
		"talk":
			icon_name = "🗣️"
			type_label = "Talk to NPC"
		"location":
			icon_name = "📍"
			type_label = "Reach Location"
		"interact":
			icon_name = "🔍"
			type_label = "Interact with Object"
		"custom":
			icon_name = "⚡"
			type_label = "Custom Event"

	var type_badge := Label.new()
	type_badge.text = "#%d  %s %s" % [index + 1, icon_name, type_label]
	type_badge.modulate = Color(0.4, 0.9, 1.0)
	type_badge.add_theme_font_size_override("font_size", 12)
	top_row.add_child(type_badge)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)

	if index > 0:
		var btn_up := Button.new()
		btn_up.text = "▲"
		btn_up.tooltip_text = "Move Up"
		btn_up.pressed.connect(func(): _move_objective(index, -1))
		top_row.add_child(btn_up)

	if index < _edit_objectives.size() - 1:
		var btn_down := Button.new()
		btn_down.text = "▼"
		btn_down.tooltip_text = "Move Down"
		btn_down.pressed.connect(func(): _move_objective(index, 1))
		top_row.add_child(btn_down)

	var btn_del := Button.new()
	btn_del.text = "🗑️"
	btn_del.modulate = Color(1.0, 0.4, 0.4)
	btn_del.tooltip_text = "Remove Objective"
	btn_del.pressed.connect(func(): _delete_objective(index))
	top_row.add_child(btn_del)

	vbox.add_child(top_row)

	# Parameter-Grid
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)

	# Beschreibung
	grid.add_child(_create_field_label("Description:"))
	var line_desc := LineEdit.new()
	line_desc.text = data["description"]
	line_desc.placeholder_text = "e.g. Find 1 Coin in harbor"
	line_desc.text_changed.connect(func(t): data["description"] = t)
	grid.add_child(line_desc)

	# Typ-spezifisches Feld
	match data["type"]:
		"item":
			grid.add_child(_create_field_label("Target Item:"))
			var item_row := HBoxContainer.new()
			var opt_item := OptionButton.new()

			var target_id: String = data.get("target_value", "")
			var cur_item_idx := -1
			for it_i in range(_all_items.size()):
				var it: Dictionary = _all_items[it_i]
				var opt_idx = opt_item.item_count
				opt_item.add_item("%s (%s)" % [it["name"], it["id"]], opt_idx)
				opt_item.set_item_metadata(opt_idx, it["id"])
				if it["id"] == target_id:
					cur_item_idx = opt_idx

			if cur_item_idx == -1 and not target_id.is_empty():
				var extra_idx = opt_item.item_count
				opt_item.add_item("%s (%s)" % [target_id.capitalize(), target_id], extra_idx)
				opt_item.set_item_metadata(extra_idx, target_id)
				cur_item_idx = extra_idx

			if cur_item_idx >= 0:
				opt_item.select(cur_item_idx)
			elif opt_item.item_count > 0:
				opt_item.select(0)
				data["target_value"] = opt_item.get_item_metadata(0)

			opt_item.item_selected.connect(func(i): data["target_value"] = opt_item.get_item_metadata(i))
			item_row.add_child(opt_item)

			var spin_amount := SpinBox.new()
			spin_amount.min_value = 1
			spin_amount.max_value = 999
			spin_amount.value = data["target_amount"]
			spin_amount.prefix = "Amount: "
			spin_amount.value_changed.connect(func(v): data["target_amount"] = int(v))
			item_row.add_child(spin_amount)
			grid.add_child(item_row)

		"talk":
			grid.add_child(_create_field_label("Target NPC:"))
			var opt_npc := OptionButton.new()
			var cur_npc_idx := 0
			for npc_i in range(_known_npcs.size()):
				var n: String = _known_npcs[npc_i]
				opt_npc.add_item(n.capitalize(), npc_i)
				opt_npc.set_item_metadata(npc_i, n)
				if n == data["target_value"]:
					cur_npc_idx = npc_i
			opt_npc.select(cur_npc_idx)
			opt_npc.item_selected.connect(func(i): data["target_value"] = opt_npc.get_item_metadata(i))
			grid.add_child(opt_npc)

		"location":
			grid.add_child(_create_field_label("Location ID:"))
			var line_loc := LineEdit.new()
			line_loc.text = data["target_value"]
			line_loc.placeholder_text = "e.g. harbor_pier or lighthouse"
			line_loc.text_changed.connect(func(t): data["target_value"] = t)
			grid.add_child(line_loc)

		"interact":
			grid.add_child(_create_field_label("Interaction ID:"))
			var line_act := LineEdit.new()
			line_act.text = data["target_value"]
			line_act.placeholder_text = "e.g. lever_gate or chest_old"
			line_act.text_changed.connect(func(t): data["target_value"] = t)
			grid.add_child(line_act)

		"custom":
			grid.add_child(_create_field_label("Event Name:"))
			var line_ev := LineEdit.new()
			line_ev.text = data["target_value"]
			line_ev.placeholder_text = "e.g. mini_game_won"
			line_ev.text_changed.connect(func(t): data["target_value"] = t)
			grid.add_child(line_ev)

	vbox.add_child(grid)

	# Optionen (Optional, Hidden)
	var opt_row := HBoxContainer.new()
	opt_row.add_theme_constant_override("separation", 16)

	var chk_opt := CheckBox.new()
	chk_opt.text = "Optional (Bonus Objective)"
	chk_opt.button_pressed = data.get("optional", false)
	chk_opt.toggled.connect(func(val): data["optional"] = val)
	opt_row.add_child(chk_opt)

	var chk_hid := CheckBox.new()
	chk_hid.text = "Hidden until active"
	chk_hid.button_pressed = data.get("hidden", false)
	chk_hid.toggled.connect(func(val): data["hidden"] = val)
	opt_row.add_child(chk_hid)

	vbox.add_child(opt_row)
	p.add_child(vbox)
	return p


func _add_new_objective(type_key: String) -> void:
	var def_desc := "Complete task"
	var def_target := ""
	match type_key:
		"item":
			def_desc = "Collect 1 Item"
			if not _all_items.is_empty():
				def_target = _all_items[0]["id"]
		"talk":
			def_desc = "Talk to NPC"
			if not _known_npcs.is_empty():
				def_target = _known_npcs[0]
		"location":
			def_desc = "Reach destination"
		"interact":
			def_desc = "Activate switch"
		"custom":
			def_desc = "Complete minigame"

	_edit_objectives.append({
		"type": type_key,
		"description": def_desc,
		"target_amount": 1,
		"target_value": def_target,
		"optional": false,
		"hidden": false,
		"consume": true
	})
	_render_objectives_list()


func _delete_objective(index: int) -> void:
	if index >= 0 and index < _edit_objectives.size():
		_edit_objectives.remove_at(index)
		_render_objectives_list()


func _move_objective(index: int, delta: int) -> void:
	var target_idx = index + delta
	if target_idx >= 0 and target_idx < _edit_objectives.size():
		var item = _edit_objectives[index]
		_edit_objectives.remove_at(index)
		_edit_objectives.insert(target_idx, item)
		_render_objectives_list()


# ==========================================================
# PREREQUISITES
# ==========================================================

func _render_prerequisites_list() -> void:
	if not prerequisites_vbox:
		return

	for child in prerequisites_vbox.get_children():
		prerequisites_vbox.remove_child(child)
		child.queue_free()

	if _edit_prerequisites.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No prerequisites. The quest can be started immediately."
		empty_lbl.modulate = Color(0.6, 0.6, 0.6)
		empty_lbl.add_theme_font_size_override("font_size", 12)
		prerequisites_vbox.add_child(empty_lbl)
		return

	for i in range(_edit_prerequisites.size()):
		var target_id = _edit_prerequisites[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var lbl := Label.new()
		lbl.text = "Must be completed:"
		lbl.modulate = Color(0.8, 0.85, 0.9)
		lbl.add_theme_font_size_override("font_size", 12)
		row.add_child(lbl)

		var opt_quest := OptionButton.new()
		var selected_idx := 0
		var opt_i := 0
		for q in _all_quests:
			if q["id"] != _selected_quest.get("id", ""):
				opt_quest.add_item("%s (%s)" % [q["title"], q["id"]], opt_i)
				opt_quest.set_item_metadata(opt_i, q["id"])
				if q["id"] == target_id:
					selected_idx = opt_i
				opt_i += 1

		if opt_quest.item_count > 0:
			opt_quest.select(selected_idx)
			var row_idx := i
			opt_quest.item_selected.connect(func(sel):
				_edit_prerequisites[row_idx] = opt_quest.get_item_metadata(sel)
			)
			row.add_child(opt_quest)
		else:
			var no_other := Label.new()
			no_other.text = target_id
			row.add_child(no_other)

		var btn_del := Button.new()
		btn_del.text = "🗑️"
		btn_del.modulate = Color(1.0, 0.4, 0.4)
		var del_idx := i
		btn_del.pressed.connect(func():
			_edit_prerequisites.remove_at(del_idx)
			_render_prerequisites_list()
		)
		row.add_child(btn_del)

		prerequisites_vbox.add_child(row)


func _add_prerequisite_row() -> void:
	# Erste andere Quest als Standard wählen
	var default_id := ""
	for q in _all_quests:
		if q["id"] != _selected_quest.get("id", ""):
			default_id = q["id"]
			break

	if not default_id.is_empty():
		_edit_prerequisites.append(default_id)
		_render_prerequisites_list()


# ==========================================================
# SPEICHERN DER QUEST
# ==========================================================

func save_current_quest() -> void:
	if _selected_quest.is_empty():
		return

	var qd: QuestData = _selected_quest["quest_data"]
	var file_path: String = _selected_quest["file_path"]

	# 1. Basisdaten & Einstellungen übertragen
	qd.title = edit_title.text.strip_edges()
	qd.id = edit_id.text.strip_edges().to_snake_case()
	qd.category = opt_category.selected
	qd.description = edit_description.text.strip_edges()

	qd.giver_npc_id = edit_giver_npc.text.strip_edges().to_snake_case()
	qd.turn_in_npc_id = edit_turn_in_npc.text.strip_edges().to_snake_case()
	qd.priority = int(spin_priority.value)

	qd.sequential_objectives = chk_sequential.button_pressed
	qd.auto_start = chk_auto_start.button_pressed
	qd.consume_items_on_turn_in = chk_consume_items.button_pressed

	# 2. Drehbuch-Dialoge übertragen
	qd.offer_dialogue = _text_to_lines(txt_dialogue_offer.text)
	qd.reminder_dialogue = _text_to_lines(txt_dialogue_reminder.text)
	qd.turn_in_dialogue = _text_to_lines(txt_dialogue_turn_in.text)
	qd.after_dialogue = _text_to_lines(txt_dialogue_after.text)

	# 3. Objectives neu zusammenbauen
	qd.objectives.clear()
	for obj_data in _edit_objectives:
		var new_obj: QuestObjective = null
		match obj_data["type"]:
			"item":
				var io = ItemObjectiveScript.new()
				io.item_id = obj_data["target_value"]
				io.consume_on_turn_in = obj_data.get("consume", true)
				qd.target_item_id = io.item_id
				new_obj = io
			"talk":
				var to = TalkObjectiveScript.new()
				to.npc_id = obj_data["target_value"]
				new_obj = to
			"location":
				var lo = LocationObjectiveScript.new()
				lo.location_id = obj_data["target_value"]
				new_obj = lo
			"interact":
				var ino = InteractObjectiveScript.new()
				ino.interactable_id = obj_data["target_value"]
				new_obj = ino
			"custom":
				var ceo = CustomEventObjectiveScript.new()
				ceo.event_name = obj_data["target_value"]
				new_obj = ceo

		if new_obj:
			new_obj.description = obj_data["description"]
			new_obj.target_amount = obj_data["target_amount"]
			new_obj.optional = obj_data.get("optional", false)
			new_obj.hidden_until_active = obj_data.get("hidden", false)
			qd.objectives.append(new_obj)

	# 4. Voraussetzungen übertragen
	qd.prerequisites.clear()
	for prereq_id in _edit_prerequisites:
		if not prereq_id.is_empty():
			var cond = QuestCompletedConditionScript.new()
			cond.quest_id = prereq_id
			qd.prerequisites.append(cond)

	# 5. Belohnungen übertragen
	qd.coin_reward = int(spin_coins.value)
	qd.energy_reward = int(spin_energy.value)

	var rew_item_idx = opt_reward_item.selected
	var rew_item_val = opt_reward_item.get_item_metadata(rew_item_idx)
	qd.reward_item_id = str(rew_item_val) if rew_item_val != null else ""
	qd.reward_item_count = int(spin_reward_count.value)
	qd.completion_dance_duration = spin_dance_duration.value

	# 6. Auf Festplatte speichern
	var save_res := ResourceSaver.save(qd, file_path)
	if save_res == OK:
		lbl_save_status.text = "✅ Saved successfully!"
		print_rich("[color=green][b]✔ [Jalura Quest Studio][/b][/color] Quest saved: [b]%s[/b] -> [u]%s[/u]" % [qd.title, file_path])

		# Timer zum Ausblenden des Status-Texts
		if is_inside_tree() and get_tree():
			var timer := get_tree().create_timer(3.0)
			timer.timeout.connect(func():
				if is_instance_valid(lbl_save_status):
					lbl_save_status.text = ""
			)

		# Cache & Liste links in-place auffrischen
		_selected_quest = Scanner._create_quest_info(qd, file_path)
		for i in range(_all_quests.size()):
			if _all_quests[i]["file_path"] == file_path:
				_all_quests[i] = _selected_quest
				break
		_render_quest_list()
		if quest_graph_view and is_instance_valid(quest_graph_view):
			quest_graph_view._refresh_internal_data()
	else:
		lbl_save_status.text = "❌ Error saving (Code %d)" % save_res
		push_error("[Jalura Quest Studio] Save failed: %d" % save_res)


func _text_to_lines(text: String) -> Array[String]:
	var lines: Array[String] = []
	for raw_line in text.split("\n"):
		var l := raw_line.strip_edges()
		if not l.is_empty():
			lines.append(l)
	return lines


func _create_section_card(title_text: String) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var lbl := Label.new()
	lbl.text = title_text
	lbl.modulate = Color(0.4, 0.8, 1.0)
	lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(lbl)
	vbox.add_child(HSeparator.new())
	return vbox


func _create_field_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.modulate = Color(0.7, 0.8, 0.9)
	l.add_theme_font_size_override("font_size", 12)
	return l


func _populate_npc_dropdown(opt: OptionButton, current_val: String, allow_same: bool = false) -> void:
	opt.clear()
	var select_idx := 0

	if allow_same:
		opt.add_item("(Same as giver)", 0)
		opt.set_item_metadata(0, "")
		if current_val.is_empty():
			select_idx = 0

	for i in range(_known_npcs.size()):
		var npc_name := _known_npcs[i]
		var idx = opt.item_count
		opt.add_item(npc_name.capitalize(), idx)
		opt.set_item_metadata(idx, npc_name)
		if npc_name == current_val:
			select_idx = idx

	opt.select(select_idx)
