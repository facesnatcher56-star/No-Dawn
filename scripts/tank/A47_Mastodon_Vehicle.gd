extends Node3D
class_name A47_Mastodon_Vehicle
## Main controller for the A-47 Mastodon Heavy Cruiser tank asset in Godot.

const MastodonMetadata = preload("res://scripts/tank/MastodonMetadata.gd")
const MastodonVisualController = preload("res://scripts/tank/MastodonVisualController.gd")
const MastodonAnimationController = preload("res://scripts/tank/MastodonAnimationController.gd")

var metadata: MastodonMetadata
var visual: MastodonVisualController
var anim: MastodonAnimationController

func _ready() -> void:
	metadata = MastodonMetadata.new()
	visual = MastodonVisualController.new(self)
	anim = MastodonAnimationController.new(self)

func _init() -> void:
	# Ensure subsystems are initialized for tests or script instantiate
	if not metadata:
		metadata = MastodonMetadata.new()
	if not visual:
		visual = MastodonVisualController.new(self)
	if not anim:
		anim = MastodonAnimationController.new(self)

func _process(delta: float) -> void:
	if anim:
		anim.update(delta)

# Pass-through API for animations and state
func rotate_turret(radians: float) -> void:
	if anim: anim.set_turret_yaw(radians)

func elevate_gun(radians: float) -> void:
	if anim: anim.set_gun_pitch(radians)

func fire_recoil() -> void:
	if anim: anim.trigger_recoil()

func set_commander_hatch(open: bool) -> void:
	if anim: anim.set_commander_hatch(open)

func set_loader_hatch(open: bool) -> void:
	if anim: anim.set_loader_hatch(open)

func set_driver_hatch(open: bool) -> void:
	if anim: anim.set_driver_hatch(open)

func set_commander_exposed(exposed: bool) -> void:
	if anim: anim.set_commander_posture(exposed)

func set_wheel_speed(speed: float) -> void:
	if anim: anim.wheel_speed = speed

func set_display_mode(mode: MastodonVisualController.DisplayMode) -> void:
	if visual: visual.set_display_mode(mode)

func highlight_component(comp_name: String) -> void:
	if visual: visual.highlight_node(comp_name)

func get_component_info(comp_name: String) -> Dictionary:
	if not metadata: return {}
	if comp_name.begins_with("ARM_"):
		return metadata.get_armor(comp_name)
	elif comp_name.begins_with("CMP_"):
		return metadata.get_component(comp_name)
	elif comp_name.begins_with("CREW_"):
		return metadata.get_crew(comp_name)
	elif comp_name.begins_with("AMMO_"):
		return metadata.get_ammo_rack(comp_name)
	return {}

func get_approximate_dimensions() -> AABB:
	var total_aabb = AABB()
	var first = true
	var meshes = find_children("*", "MeshInstance3D", true, false)
	for mesh_node in meshes:
		var mi := mesh_node as MeshInstance3D
		if mi and mi.mesh:
			var local_aabb = mi.mesh.get_aabb()
			var local_trans = transform.affine_inverse() * mi.transform
			var transformed_aabb = local_trans * local_aabb
			if first:
				total_aabb = transformed_aabb
				first = false
			else:
				total_aabb = total_aabb.merge(transformed_aabb)
	return total_aabb
