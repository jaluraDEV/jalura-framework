@tool
class_name JaluraQuestCreatorDialog
extends ConfirmationDialog

## 1-Klick-Assistent zum Erstellen neuer Quests für das Jalura Quest Studio.
## Bietet vorkonfigurierte Vorlagen (Bring-Quest, Botengang, Erkundung, Interaktion, Leer)
## with automatic objectives and dialogue placeholders.

const QuestDataScript = preload("res://scripts/data/quest_data.gd")
const QuestObjectiveScript = preload("res://scripts/data/quest_objective.gd")
const ItemObjectiveScript = preload("res://scripts/data/item_objective.gd")
const TalkObjectiveScript = preload("res://scripts/data/talk_objective.gd")
const LocationObjectiveScript = preload("res://scripts/data/location_objective.gd")
const InteractObjectiveScript = preload("res://scripts/data/interact_objective.gd")

signal quest_created(file_path: String, quest_id: String)

# UI Controls
var edit_title: LineEdit
var edit_id: LineEdit
var opt_category: OptionButton
var opt_template: OptionButton
var template_details_container: VBoxContainer

# Template-spezifische Felder
var opt_target_item: OptionButton
var spin_target_amount: SpinBox
var opt_target_npc: OptionButton
var edit_target_location: LineEdit
var edit_target_interact: LineEdit

# Basisdaten
var opt_giver_npc: OptionButton
var edit_custom_giver: LineEdit
var spin_coins: SpinBox
var spin_energy: SpinBox
var opt_reward_item: OptionButton
var lbl_error: Label

# Daten-Cache
var _items: Array[Dictionary] = []
var _npcs: Array[String] = []


func _init() -> void:
	title = "✨ Create New Quest (Jalura Studio)"
	min_size = Vector2(540, 520)
	ok_button_text = "✨ Create Quest"
	cancel_button_text = "Cancel"


var _ui_setup := false


func _ready() -> void:
	if not confirmed.is_connected(_on_confirmed):
		confirmed.connect(_on_confirmed)
	if not _ui_setup:
		_setup_dialog_ui()


func open_wizard(available_items: Array[Dictionary], known_npcs: Array[String]) -> void:
	if not _ui_setup:
		_setup_dialog_ui()
	_items = available_items
	_npcs = known_npcs
	_populate_dropdowns()
	_reset_fields()
	_on_template_selected(0)
	if is_inside_tree():
		popup_centered()
	if is_inside_tree() and edit_title:
		edit_title.grab_focus()


func _setup_dialog_ui() -> void:
	_ui_setup = true
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)

	# Banner
	var banner := PanelContainer.new()
	var b_box := HBoxContainer.new()
	b_box.add_theme_constant_override("separation", 10)
	var b_icon := Label.new()
	b_icon.text = "📜"
	b_icon.add_theme_font_size_override("font_size", 28)
	b_box.add_child(b_icon)
	var b_text_vbox := VBoxContainer.new()
	var b_title := Label.new()
	b_title.text = "Quest Templates & Quick Creation"
	b_title.add_theme_font_size_override("font_size", 14)
	b_text_vbox.add_child(b_title)
	var b_sub := Label.new()
	b_sub.text = "Choose a gameplay template for automated objectives & dialogues."
	b_sub.modulate = Color(0.7, 0.75, 0.85)
	b_sub.add_theme_font_size_override("font_size", 11)
	b_text_vbox.add_child(b_sub)
	b_box.add_child(b_text_vbox)
	banner.add_child(b_box)
	vbox.add_child(banner)

	# Grid Formular
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)

	# 1. Titel
	grid.add_child(_create_label("Quest Title:*"))
	edit_title = LineEdit.new()
	edit_title.placeholder_text = "e.g. The Lost Compass"
	edit_title.text_changed.connect(_on_title_changed)
	grid.add_child(edit_title)

	# 2. Dateiname / ID
	grid.add_child(_create_label("Quest ID (snake_case):*"))
	var id_box := HBoxContainer.new()
	var prefix_lbl := Label.new()
	prefix_lbl.text = "q_"
	prefix_lbl.modulate = Color(0.5, 0.7, 1.0)
	id_box.add_child(prefix_lbl)
	edit_id = LineEdit.new()
	edit_id.placeholder_text = "lost_compass"
	edit_id.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_box.add_child(edit_id)
	grid.add_child(id_box)

	# 3. Kategorie
	grid.add_child(_create_label("Category:"))
	opt_category = OptionButton.new()
	opt_category.add_item("🏆 Main Quest", 0)
	opt_category.add_item("⚓ Side Quest", 1)
	opt_category.add_item("🔍 Secret / Discovery", 2)
	opt_category.select(1) # Standard: Nebenaufgabe
	grid.add_child(opt_category)

	# 4. Vorlage (Template)
	grid.add_child(_create_label("Quest Template:"))
	opt_template = OptionButton.new()
	opt_template.add_item("🍎 Fetch / Collect Quest (Gather item)", 0)
	opt_template.add_item("🗣️ Messenger & Talk (Visit NPC)", 1)
	opt_template.add_item("📍 Exploration & Discovery (Find Location)", 2)
	opt_template.add_item("🔍 Interaction Quest (Inspect object)", 3)
	opt_template.add_item("📄 Blank Quest (Custom / Empty)", 4)
	opt_template.item_selected.connect(_on_template_selected)
	grid.add_child(opt_template)

	vbox.add_child(grid)

	# Template-spezifische Detail-Box
	template_details_container = VBoxContainer.new()
	template_details_container.add_theme_constant_override("separation", 6)
	vbox.add_child(template_details_container)

	vbox.add_child(HSeparator.new())

	# Auftraggeber & Belohnungen
	var grid_meta := GridContainer.new()
	grid_meta.columns = 2
	grid_meta.add_theme_constant_override("h_separation", 14)
	grid_meta.add_theme_constant_override("v_separation", 8)

	grid_meta.add_child(_create_label("Quest Giver (NPC):"))
	var giver_box := HBoxContainer.new()
	opt_giver_npc = OptionButton.new()
	opt_giver_npc.item_selected.connect(_on_giver_selected)
	giver_box.add_child(opt_giver_npc)
	edit_custom_giver = LineEdit.new()
	edit_custom_giver.placeholder_text = "or new NPC name..."
	edit_custom_giver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	giver_box.add_child(edit_custom_giver)
	grid_meta.add_child(giver_box)

	grid_meta.add_child(_create_label("Coins / Reward:"))
	spin_coins = SpinBox.new()
	spin_coins.max_value = 9999
	spin_coins.value = 25
	spin_coins.prefix = "🪙 "
	grid_meta.add_child(spin_coins)

	grid_meta.add_child(_create_label("Energy / Stamina:"))
	spin_energy = SpinBox.new()
	spin_energy.max_value = 9999
	spin_energy.value = 15
	spin_energy.prefix = "⚡ "
	grid_meta.add_child(spin_energy)

	grid_meta.add_child(_create_label("Reward Item:"))
	opt_reward_item = OptionButton.new()
	grid_meta.add_child(opt_reward_item)

	vbox.add_child(grid_meta)

	# Fehleranzeige
	lbl_error = Label.new()
	lbl_error.modulate = Color(1.0, 0.35, 0.35)
	lbl_error.add_theme_font_size_override("font_size", 12)
	vbox.add_child(lbl_error)

	scroll.add_child(vbox)
	add_child(scroll)


func _create_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.modulate = Color(0.85, 0.9, 0.95)
	l.add_theme_font_size_override("font_size", 12)
	return l


func _populate_dropdowns() -> void:
	# 1. Items
	if opt_reward_item:
		opt_reward_item.clear()
		opt_reward_item.add_item("(No Item)", 0)
		opt_reward_item.set_item_metadata(0, "")
		for it in _items:
			var idx = opt_reward_item.item_count
			opt_reward_item.add_item("%s (%s)" % [it["name"], it["id"]], idx)
			opt_reward_item.set_item_metadata(idx, it["id"])
		opt_reward_item.select(0)

	# 2. NPCs
	if opt_giver_npc:
		opt_giver_npc.clear()
		for i in range(_npcs.size()):
			var n := _npcs[i]
			opt_giver_npc.add_item(n.capitalize(), i)
			opt_giver_npc.set_item_metadata(i, n)
		if opt_giver_npc.item_count > 0:
			opt_giver_npc.select(0)


func _reset_fields() -> void:
	if edit_title:
		edit_title.text = ""
	if edit_id:
		edit_id.text = ""
	if opt_category:
		opt_category.select(1)
	if opt_template:
		opt_template.select(0)
	if spin_coins:
		spin_coins.value = 25
	if spin_energy:
		spin_energy.value = 15
	if edit_custom_giver:
		edit_custom_giver.text = ""
	if lbl_error:
		lbl_error.text = ""


func _on_title_changed(new_title: String) -> void:
	# Automatische ID-Generierung, falls User nicht manuell editiert hat
	var auto_id := new_title.strip_edges().to_snake_case()
	# Umlaute bereinigen
	auto_id = auto_id.replace("ä", "ae").replace("ö", "oe").replace("ü", "ue").replace("ß", "ss")
	if edit_id:
		edit_id.text = auto_id


func _on_giver_selected(idx: int) -> void:
	if edit_custom_giver:
		edit_custom_giver.text = ""


func _on_template_selected(idx: int) -> void:
	for c in template_details_container.get_children():
		template_details_container.remove_child(c)
		c.queue_free()

	var card := PanelContainer.new()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	match idx:
		0: # Bring-Quest
			var h := Label.new()
			h.text = "🎯 Template Target: Obtain & turn in item"
			h.modulate = Color(0.4, 1.0, 0.7)
			vbox.add_child(h)

			var r := HBoxContainer.new()
			r.add_child(_create_label("Target Item:"))
			opt_target_item = OptionButton.new()
			for it in _items:
				var i_idx = opt_target_item.item_count
				opt_target_item.add_item("%s (%s)" % [it["name"], it["id"]], i_idx)
				opt_target_item.set_item_metadata(i_idx, it["id"])
			if opt_target_item.item_count > 0:
				opt_target_item.select(0)
			r.add_child(opt_target_item)

			r.add_child(_create_label("Amount:"))
			spin_target_amount = SpinBox.new()
			spin_target_amount.min_value = 1
			spin_target_amount.max_value = 99
			spin_target_amount.value = 1
			r.add_child(spin_target_amount)
			vbox.add_child(r)

		1: # Botengang / Talk
			var h := Label.new()
			h.text = "🎯 Template Target: Visit specific NPC"
			h.modulate = Color(0.4, 0.8, 1.0)
			vbox.add_child(h)

			var r := HBoxContainer.new()
			r.add_child(_create_label("Target NPC:"))
			opt_target_npc = OptionButton.new()
			for n_i in range(_npcs.size()):
				var n := _npcs[n_i]
				opt_target_npc.add_item(n.capitalize(), n_i)
				opt_target_npc.set_item_metadata(n_i, n)
			if opt_target_npc.item_count > 0:
				opt_target_npc.select(0)
			r.add_child(opt_target_npc)
			vbox.add_child(r)

		2: # Location
			var h := Label.new()
			h.text = "🎯 Template Target: Discover location or scene"
			h.modulate = Color(1.0, 0.8, 0.3)
			vbox.add_child(h)

			var r := HBoxContainer.new()
			r.add_child(_create_label("Location ID:"))
			edit_target_location = LineEdit.new()
			edit_target_location.placeholder_text = "e.g. pump_house or pier_docks"
			edit_target_location.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r.add_child(edit_target_location)
			vbox.add_child(r)

		3: # Interact
			var h := Label.new()
			h.text = "🎯 Template Target: Interact with world object"
			h.modulate = Color(0.9, 0.5, 1.0)
			vbox.add_child(h)

			var r := HBoxContainer.new()
			r.add_child(_create_label("Object ID:"))
			edit_target_interact = LineEdit.new()
			edit_target_interact.placeholder_text = "e.g. lever_gate or generator"
			edit_target_interact.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r.add_child(edit_target_interact)
			vbox.add_child(r)

		4: # Blank
			var h := Label.new()
			h.text = "📄 Blank Template: You can add objectives freely in the editor afterwards."
			h.modulate = Color(0.7, 0.7, 0.7)
			vbox.add_child(h)

	card.add_child(vbox)
	template_details_container.add_child(card)


func _on_confirmed() -> void:
	var q_title := edit_title.text.strip_edges()
	if q_title.is_empty():
		lbl_error.text = "⚠️ Please enter a quest title!"
		popup()
		return

	var raw_id := edit_id.text.strip_edges().to_snake_case()
	if raw_id.is_empty():
		raw_id = q_title.to_snake_case()
	raw_id = raw_id.replace("ä", "ae").replace("ö", "oe").replace("ü", "ue").replace("ß", "ss")

	var full_id := "q_" + raw_id if not raw_id.begins_with("q_") else raw_id
	var save_path := "res://resources/quests/%s.tres" % full_id

	# Prüfen, ob Datei bereits existiert
	if FileAccess.file_exists(save_path):
		lbl_error.text = "⚠️ A quest with filename '%s.tres' already exists!" % full_id
		popup()
		return

	# Auftraggeber ermitteln
	var giver_id := ""
	if edit_custom_giver and not edit_custom_giver.text.strip_edges().is_empty():
		giver_id = edit_custom_giver.text.strip_edges().to_snake_case()
	elif opt_giver_npc and opt_giver_npc.selected >= 0:
		giver_id = str(opt_giver_npc.get_item_metadata(opt_giver_npc.selected))

	# Belohnungs-Item ermitteln
	var rew_item_id := ""
	if opt_reward_item and opt_reward_item.selected > 0:
		rew_item_id = str(opt_reward_item.get_item_metadata(opt_reward_item.selected))

	# 1. Neue QuestData Instanz bauen
	var qd := QuestDataScript.new()
	qd.id = raw_id.trim_prefix("q_")
	qd.title = q_title
	qd.category = opt_category.selected
	qd.giver_npc_id = giver_id
	qd.turn_in_npc_id = giver_id
	qd.coin_reward = int(spin_coins.value)
	qd.energy_reward = int(spin_energy.value)
	qd.reward_item_id = rew_item_id
	qd.reward_item_count = 1 if not rew_item_id.is_empty() else 0
	qd.completion_dance_duration = 3.5

	# 2. Template-Logik (Objectives & Dialoge)
	var t_idx := opt_template.selected
	match t_idx:
		0: # Bring-Quest
			var it_id := ""
			var it_name := "Item"
			if opt_target_item and opt_target_item.selected >= 0:
				it_id = str(opt_target_item.get_item_metadata(opt_target_item.selected))
				it_name = opt_target_item.get_item_text(opt_target_item.selected).split(" (")[0]
			var amount: int = int(spin_target_amount.value) if spin_target_amount else 1

			var io = ItemObjectiveScript.new()
			io.item_id = it_id
			io.target_amount = amount
			io.description = "Gather %d %s" % [amount, it_name]
			io.consume_on_turn_in = true
			qd.objectives.append(io)
			qd.target_item_id = it_id

			qd.description = "%s urgently needs %d %s. Search the surrounding area!" % [giver_id.capitalize(), amount, it_name]
			qd.offer_dialogue = [
				"Hello Jalura! Great to see you.",
				"I could really use your help: Could you gather %d %s for me?" % [amount, it_name],
				"Take a look around the area, you should find something there!"
			]
			qd.reminder_dialogue = [
				"Any luck searching for %s yet?" % it_name,
				"Take your time, but don't forget my request!"
			]
			qd.turn_in_dialogue = [
				"Wonderful! You actually found %s!" % it_name,
				"Thank you so much for your effort! Here is your well-earned reward."
			]
			qd.after_dialogue = [
				"Thanks again for your help with %s! You are a true friend." % it_name
			]

		1: # Botengang / Talk
			var target_npc := ""
			if opt_target_npc and opt_target_npc.selected >= 0:
				target_npc = str(opt_target_npc.get_item_metadata(opt_target_npc.selected))
			var to = TalkObjectiveScript.new()
			to.npc_id = target_npc
			to.description = "Talk to %s" % target_npc.capitalize()
			qd.objectives.append(to)

			qd.description = "Go to %s and deliver a message." % target_npc.capitalize()
			qd.offer_dialogue = [
				"Jalura, could you run over to %s?" % target_npc.capitalize(),
				"There is important news to discuss!"
			]
			qd.reminder_dialogue = [
				"Have you spoken with %s yet?" % target_npc.capitalize()
			]
			qd.turn_in_dialogue = [
				"Wonderful, thanks for reporting back! You're great!"
			]
			qd.after_dialogue = [
				"Everything sorted with %s! Have a nice day!" % target_npc.capitalize()
			]

		2: # Location
			var loc_id := edit_target_location.text.strip_edges() if edit_target_location else "hafen"
			var lo = LocationObjectiveScript.new()
			lo.location_id = loc_id
			lo.description = "Explore the area: %s" % loc_id.capitalize()
			qd.objectives.append(lo)

			qd.description = "Explore the mysterious location '%s'." % loc_id
			qd.offer_dialogue = [
				"I heard something strange is going on over at '%s'..." % loc_id,
				"Go take a closer look around there!"
			]
			qd.reminder_dialogue = [
				"Have you visited '%s' yet?" % loc_id
			]
			qd.turn_in_dialogue = [
				"Ha! You found it! Fascinating what was happening there!"
			]
			qd.after_dialogue = [
				"A true adventure at '%s'!" % loc_id
			]

		3: # Interact
			var int_id := edit_target_interact.text.strip_edges() if edit_target_interact else "lever_gate"
			var ino = InteractObjectiveScript.new()
			ino.interactable_id = int_id
			ino.description = "Inspect object: %s" % int_id
			qd.objectives.append(ino)

			qd.description = "Find and activate '%s'." % int_id
			qd.offer_dialogue = [
				"Over there is '%s'... could you inspect it?" % int_id
			]
			qd.reminder_dialogue = [
				"Have you inspected '%s' yet?" % int_id
			]
			qd.turn_in_dialogue = [
				"It worked! Well done!"
			]
			qd.after_dialogue = [
				"Everything is running smoothly again!"
			]

		4: # Blank
			qd.description = "New Quest"
			qd.offer_dialogue = ["Hello Jalura!"]
			qd.reminder_dialogue = ["How is it going?"]
			qd.turn_in_dialogue = ["Thank you very much!"]
			qd.after_dialogue = ["Safe travels!"]

	# 3. Auf Festplatte speichern
	var save_err := ResourceSaver.save(qd, save_path)
	if save_err == OK:
		print_rich("[color=green][b]✔ [Jalura Studio][/b][/color] New quest created successfully: [b]%s[/b] -> [u]%s[/u]" % [qd.title, save_path])
		quest_created.emit(save_path, qd.id)
	else:
		lbl_error.text = "❌ Error saving quest file (%d)!" % save_err
		popup()
