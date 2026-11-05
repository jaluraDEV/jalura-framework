class_name PlayerInteraction
extends Node

## PlayerInteraction
## Modular interaction controller for Barnaby.
## Handles proximity scanning for Interactables, HUD prompts,
## BUMP-based pushable block interactions, and Quest Celebration hooks.

var player: CharacterBody3D
var hud: Node
var current_interactable: Interactable
var is_celebrating: bool = false

@export_group("Interaction Settings")
@export var interaction_range: float = 2.8

# BUMP Pushable tracking state
var _bump_target_pb: PushableBehavior = null
var _bump_timer: float = 0.0

# ==============================================================================
# SETUP
# ==============================================================================

func setup(p_player: CharacterBody3D) -> void:
	player = p_player

	if player and player.is_inside_tree():
		hud = player.get_tree().root.find_child("HUD", true, false)

	var qm = get_node_or_null("/root/QuestManager")
	if qm:
		if qm.has_signal("quest_celebration_started") and not qm.quest_celebration_started.is_connected(on_quest_celebration_started):
			qm.quest_celebration_started.connect(on_quest_celebration_started)
		if qm.has_signal("quest_celebration_ended") and not qm.quest_celebration_ended.is_connected(on_quest_celebration_ended):
			qm.quest_celebration_ended.connect(on_quest_celebration_ended)

# ==============================================================================
# PROXIMITY SCANNING & HUD PROMPTS
# ==============================================================================

func update_interactions() -> void:
	if current_interactable and not is_instance_valid(current_interactable):
		current_interactable = null
		if player:
			player.set("current_interactable", null)

	if not hud and player and player.is_inside_tree():
		hud = player.get_tree().root.find_child("HUD", true, false)

	if is_celebrating or (hud and hud.get("is_dialogue_active") == true):
		if hud and hud.has_method("hide_prompt"):
			hud.hide_prompt()
		if current_interactable and is_instance_valid(current_interactable):
			if current_interactable.has_method("on_focus_lost"):
				current_interactable.on_focus_lost()
		current_interactable = null
		if player:
			player.set("current_interactable", null)
		return

	var best_interactable: Interactable = null
	var best_dist := interaction_range

	if player and player.is_inside_tree():
		var interactables := player.get_tree().get_nodes_in_group("interactables")
		for node in interactables:
			if is_instance_valid(node) and node is Interactable and node.can_interact(player):
				var dist := player.global_position.distance_to(node.global_position)
				if dist < best_dist:
					best_dist = dist
					best_interactable = node

	if best_interactable != current_interactable:
		if current_interactable and is_instance_valid(current_interactable):
			if current_interactable.has_method("on_focus_lost"):
				current_interactable.on_focus_lost()
		if best_interactable and is_instance_valid(best_interactable):
			if best_interactable.has_method("on_focus_gained"):
				best_interactable.on_focus_gained()
		current_interactable = best_interactable
		if player:
			player.set("current_interactable", current_interactable)

	if hud:
		if current_interactable and is_instance_valid(current_interactable):
			if hud.has_method("show_prompt"):
				hud.show_prompt(current_interactable.prompt_text, current_interactable.action_key)
		else:
			if hud.has_method("hide_prompt"):
				hud.hide_prompt()

# ==============================================================================
# INTERACTION INPUT TRIGGER
# ==============================================================================

func interact() -> bool:
	if current_interactable and not is_celebrating and is_instance_valid(current_interactable):
		current_interactable.interact(player)
		return true
	return false

# ==============================================================================
# BUMP PUSHABLE BLOCKS (Continuous collision against blocks)
# ==============================================================================

func handle_bump_pushables(delta: float) -> void:
	if not player:
		return

	var active_pb: PushableBehavior = null
	var collision_normal := Vector3.ZERO

	var count := player.get_slide_collision_count()
	for i in range(count):
		var col := player.get_slide_collision(i)
		var collider := col.get_collider()
		if not collider:
			continue
		var normal := col.get_normal()
		# Only horizontal collisions (ignore floors / ceilings)
		if abs(normal.y) > 0.5:
			continue

		var pb: PushableBehavior = null
		if collider.has_method("get_behaviors"):
			for b in collider.get_behaviors():
				if b is PushableBehavior:
					pb = b
					break
		if not pb and collider.get_parent():
			var p = collider.get_parent()
			if p.has_method("get_behaviors"):
				for b in p.get_behaviors():
					if b is PushableBehavior:
						pb = b
						break
			if not pb and p.has_node("PushableBehavior"):
				pb = p.get_node("PushableBehavior") as PushableBehavior
		if not pb and collider.has_node("PushableBehavior"):
			pb = collider.get_node("PushableBehavior") as PushableBehavior

		if pb and pb.push_trigger != PushableBehavior.PushTrigger.INTERACT and not pb.is_moving:
			active_pb = pb
			collision_normal = normal
			break

	if active_pb:
		if _bump_target_pb == active_pb:
			_bump_timer += delta
			if _bump_timer >= active_pb.bump_hold_time:
				_bump_timer = 0.0
				active_pb.bump(player, -collision_normal)
		else:
			_bump_target_pb = active_pb
			_bump_timer = delta
	else:
		_bump_target_pb = null
		_bump_timer = 0.0

# ==============================================================================
# QUEST CELEBRATION HOOKS
# ==============================================================================

func on_quest_celebration_started(_quest: QuestData = null) -> void:
	is_celebrating = true
	if player:
		player.set("is_celebrating", true)
		if player.has_method("_play_anim") and player.has_method("_get_celebration_anim"):
			player._play_anim(player._get_celebration_anim(), 0.15)
		if player.get("anim_player"):
			player.anim_player.speed_scale = 1.0

func on_quest_celebration_ended(_quest: QuestData = null) -> void:
	is_celebrating = false
	if player:
		player.set("is_celebrating", false)
		if player.has_method("_play_anim") and player.has_method("_get_idle_anim"):
			player._play_anim(player._get_idle_anim(), 0.2)

func handle_celebration_movement(delta: float, deceleration: float, gravity: float) -> bool:
	if not is_celebrating or not player:
		return false

	player.velocity.x = lerp(player.velocity.x, 0.0, 1.0 - exp(-deceleration * delta))
	player.velocity.z = lerp(player.velocity.z, 0.0, 1.0 - exp(-deceleration * delta))
	if not player.is_on_floor():
		player.velocity.y -= gravity * delta
	else:
		player.velocity.y = 0.0

	player.move_and_slide()
	if player.has_method("_play_anim") and player.has_method("_get_celebration_anim"):
		player._play_anim(player._get_celebration_anim(), 0.15)

	return true
