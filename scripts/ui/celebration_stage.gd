extends Node3D

@onready var anim_player: AnimationPlayer = $Dancer/AnimationPlayer
@onready var camera: Camera3D = $Camera3D
@onready var dancer: Node3D = $Dancer

func _get_dance_anim() -> String:
	for a in ["dance", "Spin", "Backflip"]:
		if anim_player and anim_player.has_animation(a):
			return a
	return "Idle"

func _ready() -> void:
	if not anim_player:
		anim_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
		
	var dance_name := _get_dance_anim()
	if anim_player and anim_player.has_animation(dance_name):
		var anim := anim_player.get_animation(dance_name)
		anim.loop_mode = Animation.LOOP_LINEAR
		anim_player.play(dance_name)
		anim_player.speed_scale = 1.05
		
	_setup_headlamp()

func _setup_headlamp() -> void:
	var skel := find_child("Skeleton3D", true, false) as Skeleton3D
	if not skel:
		return
	var head_idx := skel.find_bone("mixamorig_Head")
	if head_idx < 0:
		return
	var bone_attach := BoneAttachment3D.new()
	bone_attach.bone_name = "mixamorig_Head"
	bone_attach.bone_idx = head_idx
	skel.add_child(bone_attach)
	

func restart_dance() -> void:
	var dance_name := _get_dance_anim()
	if anim_player and anim_player.has_animation(dance_name):
		anim_player.seek(0.0, true)
		anim_player.play(dance_name)
