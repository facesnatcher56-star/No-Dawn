extends RefCounted
class_name MastodonAnimationController
## Controls animation, pivots, recoil, hatches, and wheel rotation for A-47 Mastodon.

var root_node: Node3D
var turret_pivot: Node3D
var gun_elev_pivot: Node3D
var gun_assembly: Node3D

var cmd_hatch_pivot: Node3D
var loader_hatch_pivot: Node3D
var driver_hatch_pivot: Node3D

var commander_crew: Node3D
var road_wheels: Array[Node3D] = []
var sprockets: Array[Node3D] = []

# Animation States
var turret_yaw: float = 0.0 # Radians
var gun_pitch: float = 0.0 # Radians
var is_recoiling: bool = false
var recoil_progress: float = 0.0
var recoil_distance: float = 0.35 # 350mm recoil stroke

var cmd_hatch_open: bool = false
var loader_hatch_open: bool = false
var driver_hatch_open: bool = false
var commander_exposed: bool = false

var wheel_speed: float = 0.0
var wheel_angle: float = 0.0

var cmd_initial_pos: Vector3
var gun_assembly_initial_pos: Vector3

func _init(tank_root: Node3D) -> void:
	root_node = tank_root
	_bind_nodes(tank_root)

func _bind_nodes(node: Node) -> void:
	turret_pivot = node.find_child("TurretPivot", true, false)
	gun_elev_pivot = node.find_child("GunElevationPivot", true, false)
	gun_assembly = node.find_child("GunAssembly", true, false)
	if gun_assembly:
		gun_assembly_initial_pos = gun_assembly.position
		
	cmd_hatch_pivot = node.find_child("CommanderHatchPivot", true, false)
	loader_hatch_pivot = node.find_child("LoaderHatchPivot", true, false)
	driver_hatch_pivot = node.find_child("DriverHatchPivot", true, false)
	commander_crew = node.find_child("CREW_Commander", true, false)
	if commander_crew:
		cmd_initial_pos = commander_crew.position
		
	# Find wheels and sprockets
	for child in node.find_children("CMP_Wheel_*", "Node3D", true, false):
		road_wheels.append(child)
	for child in node.find_children("CMP_DriveSprocket_*", "Node3D", true, false):
		sprockets.append(child)
	for child in node.find_children("CMP_Idler_*", "Node3D", true, false):
		road_wheels.append(child)

func set_turret_yaw(radians: float) -> void:
	turret_yaw = radians
	if turret_pivot:
		turret_pivot.rotation.y = turret_yaw

func set_gun_pitch(radians: float) -> void:
	# Clamp between -8 deg (-0.14 rad) and +20 deg (+0.35 rad)
	gun_pitch = clampf(radians, deg_to_rad(-8.0), deg_to_rad(20.0))
	if gun_elev_pivot:
		gun_elev_pivot.rotation.x = gun_pitch

func trigger_recoil() -> void:
	if not is_recoiling:
		is_recoiling = true
		recoil_progress = 0.0

func toggle_commander_hatch() -> void:
	set_commander_hatch(not cmd_hatch_open)

func set_commander_hatch(open: bool) -> void:
	cmd_hatch_open = open
	if cmd_hatch_pivot:
		cmd_hatch_pivot.rotation.x = deg_to_rad(-85.0) if cmd_hatch_open else 0.0

func toggle_loader_hatch() -> void:
	set_loader_hatch(not loader_hatch_open)

func set_loader_hatch(open: bool) -> void:
	loader_hatch_open = open
	if loader_hatch_pivot:
		loader_hatch_pivot.rotation.x = deg_to_rad(-80.0) if loader_hatch_open else 0.0

func toggle_driver_hatch() -> void:
	set_driver_hatch(not driver_hatch_open)

func set_driver_hatch(open: bool) -> void:
	driver_hatch_open = open
	if driver_hatch_pivot:
		driver_hatch_pivot.rotation.x = deg_to_rad(-75.0) if driver_hatch_open else 0.0

func toggle_commander_posture() -> void:
	set_commander_posture(not commander_exposed)

func set_commander_posture(exposed: bool) -> void:
	commander_exposed = exposed
	if commander_exposed and not cmd_hatch_open:
		set_commander_hatch(true)
		
	if commander_crew:
		if commander_exposed:
			commander_crew.visible = true
			commander_crew.position = cmd_initial_pos + Vector3(0, 1.15, 0)
		else:
			commander_crew.position = cmd_initial_pos

func update(delta: float) -> void:
	# Recoil Animation
	if is_recoiling and gun_assembly:
		recoil_progress += delta * 6.0 # Quick recoil cycle ~0.35s
		var offset = 0.0
		if recoil_progress < 0.2:
			# Fast recoil stroke backward
			offset = (recoil_progress / 0.2) * recoil_distance
		elif recoil_progress < 1.0:
			# Smooth recuperator return to battery
			var return_t = (recoil_progress - 0.2) / 0.8
			offset = (1.0 - return_t) * recoil_distance
		else:
			is_recoiling = false
			offset = 0.0
		# Recoil moves backward along local Z (Godot forward is -Z, so recoil is +Z)
		gun_assembly.position = gun_assembly_initial_pos + Vector3(0, 0, offset)

	# Wheel Rotation
	if absf(wheel_speed) > 0.001:
		wheel_angle += wheel_speed * delta
		for wheel in road_wheels:
			wheel.rotation.x = wheel_angle
		for sprock in sprockets:
			sprock.rotation.x = wheel_angle
