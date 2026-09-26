extends RefCounted
class_name GunnerSightSystem
## Manages the dedicated first-person gunner view, sight optics, manual ballistic range setting,
## physical turret/gun mechanical rates, gun settling dynamics, physical dispersion,
## and optical line-of-sight target acquisition.

const AmmunitionData = preload("res://scripts/wego/AmmunitionData.gd")
const VehicleConfig = preload("res://scripts/wego/VehicleConfig.gd")
const ContactTrack = preload("res://scripts/wego/ContactTrack.gd")

# Settling States
enum SettlingState {
	UNSTABLE,
	SETTLING,
	STABLE
}

# Acquisition States
enum AcquisitionState {
	NO_CONTACT,
	SLEWING,
	SEARCHING,
	TARGET_VISIBLE,
	ACQUIRED,
	TRACKING
}

# Fire Policies
enum FirePolicy {
	FIRE_ASAP,        # Fires as soon as bore is aligned and loaded, even if settling/unstable
	FIRE_WHEN_STABLE  # Waits until gun settling has completed before firing
}

var vehicle = null # TacticalVehicle reference
var sight_camera: Camera3D

# Commanded Aim vs Physical Bore (in world radians)
var commanded_yaw: float = 0.0
var commanded_pitch: float = 0.0

# Current physical gun orientation
var current_bore_yaw: float = 0.0
var current_bore_pitch: float = 0.0

# Manual ballistic sight range (meters)
var sight_range_m: float = 800.0
const MIN_SIGHT_RANGE: float = 100.0
const MAX_SIGHT_RANGE: float = 3000.0

# Elevation limits
const MIN_ELEVATION_RAD: float = deg_to_rad(-8.0) # -8 degrees depression
const MAX_ELEVATION_RAD: float = deg_to_rad(20.0) # +20 degrees elevation

# Dynamics and settling
var settling_state: SettlingState = SettlingState.STABLE
var settling_timer: float = 0.0
const SETTLING_DURATION: float = 0.75 # seconds to settle after movement stops
var previous_yaw_command: float = 0.0
var previous_pitch_command: float = 0.0

# Acquisition tracking
var acquisition_state: AcquisitionState = AcquisitionState.NO_CONTACT
var visual_contact_duration: float = 0.0
var target_has_los: bool = false
var tracking_enabled: bool = false

# Fire policy
var fire_policy: FirePolicy = FirePolicy.FIRE_WHEN_STABLE

# Optical configuration
var optic_fov_deg: float = 10.5 # Magnified narrow gunner field of view

func _init(p_vehicle = null) -> void:
	vehicle = p_vehicle
	if vehicle != null:
		commanded_yaw = vehicle.rotation.y
		commanded_pitch = 0.0
		current_bore_yaw = vehicle.rotation.y
		current_bore_pitch = 0.0
		_setup_camera()

func _setup_camera() -> void:
	sight_camera = Camera3D.new()
	sight_camera.name = "GunnerSightCamera"
	sight_camera.fov = optic_fov_deg
	sight_camera.near = 0.5
	sight_camera.far = 4500.0
	sight_camera.current = false
	if vehicle != null:
		vehicle.add_child(sight_camera)
		_update_camera_transform()

func _update_camera_transform() -> void:
	if sight_camera == null or vehicle == null or not vehicle.is_inside_tree(): return
	# Gunner sight optic aperture position relative to vehicle hull/turret:
	# Located on the left cheek of the turret mantlet
	var turret_rot = vehicle.rotation.y + vehicle.model.turret_yaw
	var local_optic_offset = Vector3(-0.62, 2.70, -1.25) # World-height offset on turret
	var quat = Quaternion.from_euler(Vector3(0.0, turret_rot, 0.0))
	sight_camera.global_position = vehicle.position + quat * local_optic_offset
	
	# Look direction reflects current commanded sight line
	var look_quat = Quaternion.from_euler(Vector3(commanded_pitch, commanded_yaw, 0.0))
	var forward = look_quat * Vector3(0, 0, -1)
	sight_camera.look_at(sight_camera.global_position + forward, Vector3.UP)

func set_active(active: bool) -> void:
	if sight_camera != null:
		sight_camera.current = active

func is_active() -> bool:
	return sight_camera != null and sight_camera.current

# Adjust sight range manually (mouse wheel)
func adjust_sight_range(delta_m: float) -> void:
	sight_range_m = clampf(sight_range_m + delta_m, MIN_SIGHT_RANGE, MAX_SIGHT_RANGE)

# Calculates required ballistic superelevation angle for chosen sight range
func get_ballistic_elevation(range_m: float = -1.0, ammo: AmmunitionData = null) -> float:
	var r = sight_range_m if range_m < 0.0 else range_m
	var v0 = ammo.muzzle_velocity if ammo != null else 880.0
	var k = ammo.drag_coeff if ammo != null else 0.00032
	var g = 9.81
	
	# Aerodynamic time of flight integration
	var t_flight = (exp(k * r) - 1.0) / maxf(0.001, (k * v0))
	var drop = 0.5 * g * t_flight * t_flight
	# Superelevation angle in radians to cancel gravity drop at dialled range
	return atan2(drop, maxf(1.0, r))

# Computes estimated deflection/lead in milliradians using ONLY estimated track data (no truth leaking!)
func get_estimated_lead_mils(track: ContactTrack, ammo: AmmunitionData = null) -> float:
	if track == null or track.estimated_range <= 0.0 or track.estimated_speed_mps < 0.5:
		return 0.0
	
	var r = track.estimated_range
	var v0 = ammo.muzzle_velocity if ammo != null else 880.0
	var k = ammo.drag_coeff if ammo != null else 0.00032
	var t_flight = (exp(k * r) - 1.0) / maxf(0.001, (k * v0))
	
	# Angle between target velocity vector and line of sight
	var sight_bearing = fposmod(rad_to_deg(-commanded_yaw), 360.0)
	var rel_heading = fposmod(track.estimated_heading_deg - sight_bearing, 360.0)
	var tangential_speed = track.estimated_speed_mps * sin(deg_to_rad(rel_heading))
	
	var lateral_offset_m = tangential_speed * t_flight
	# Convert lateral offset to milliradians (1 mil ≈ 1m at 1000m)
	return (lateral_offset_m / maxf(1.0, r)) * 1000.0

# Slew turret to contact estimate
func slew_to_contact(track: ContactTrack) -> void:
	if track == null or track.estimated_range <= 0.0: return
	var bearing_rad = deg_to_rad(-track.estimated_bearing_deg)
	commanded_yaw = bearing_rad
	# Estimate approximate pitch to target
	var dy = (track.estimated_position.y + 1.4) - (vehicle.position.y + 2.5) if vehicle != null else 0.0
	commanded_pitch = clampf(atan2(dy, maxf(10.0, track.estimated_range)), MIN_ELEVATION_RAD, MAX_ELEVATION_RAD)
	sight_range_m = clampf(roundf(track.estimated_range / 50.0) * 50.0, MIN_SIGHT_RANGE, MAX_SIGHT_RANGE)
	settling_timer = SETTLING_DURATION
	settling_state = SettlingState.UNSTABLE

# Add mouse delta to commanded sight direction
func apply_mouse_input(delta_mouse: Vector2, sensitivity: float = 0.0018) -> void:
	var yaw_delta = -delta_mouse.x * sensitivity
	var pitch_delta = -delta_mouse.y * sensitivity
	
	commanded_yaw += yaw_delta
	commanded_pitch = clampf(commanded_pitch + pitch_delta, MIN_ELEVATION_RAD, MAX_ELEVATION_RAD)
	
	if absf(yaw_delta) > 0.001 or absf(pitch_delta) > 0.001:
		settling_timer = SETTLING_DURATION
		settling_state = SettlingState.UNSTABLE

# Estimates physical traverse time to align with current commanded yaw
func get_traverse_time_est() -> float:
	if vehicle == null: return 0.0
	var cfg = vehicle.config
	var trav_rate = deg_to_rad(cfg.turret_traverse_speed_deg) if cfg != null else 0.5
	var cur_world_yaw = vehicle.rotation.y + vehicle.model.turret_yaw
	var diff = absf(angle_difference(cur_world_yaw, commanded_yaw))
	return diff / maxf(0.01, trav_rate)

func get_commanded_aim_vector() -> Vector3:
	var look_quat = Quaternion.from_euler(Vector3(commanded_pitch, commanded_yaw, 0.0))
	return look_quat * Vector3(0, 0, -1)

func get_bore_vector() -> Vector3:
	var bore_quat = Quaternion.from_euler(Vector3(current_bore_pitch, current_bore_yaw, 0.0))
	return bore_quat * Vector3(0, 0, -1)

# Physical weapon dispersion calculation (in radians)
func calculate_dispersion(ammo: AmmunitionData = null) -> float:
	var base_cone = 0.00030 # ~0.3 mils baseline accuracy for 92mm high-velocity rifled cannon
	
	match settling_state:
		SettlingState.UNSTABLE:
			base_cone += 0.0028 # 2.8 mils unstable platform penalty
		SettlingState.SETTLING:
			base_cone += 0.0009 # 0.9 mils settling penalty
		SettlingState.STABLE:
			pass
			
	if vehicle != null:
		if vehicle.speed > 0.3:
			base_cone += vehicle.speed * 0.0006
		if absf(vehicle.yaw_rate) > 0.1:
			base_cone += absf(vehicle.yaw_rate) * 0.02
		if not vehicle.model.functional("Gunsight"):
			base_cone += 0.0065
		for c in vehicle.model.crew:
			if c.station == "Gunner":
				if c.state == "Wounded": base_cone += 0.003
				elif c.state == "Seriously wounded": base_cone += 0.007
				
	return base_cone

# Step the physical orientation and settling dynamics during simulation frame
func update_step(delta: float, target_vehicle = null, world_3d: World3D = null) -> void:
	if vehicle == null: return
	
	var cfg = vehicle.config
	var trav_rate = deg_to_rad(cfg.turret_traverse_speed_deg) if cfg != null else 0.5
	var elev_rate = deg_to_rad(cfg.gun_elevation_speed_deg) if cfg != null else 0.25
	
	# Current world orientations
	var current_turret_world_yaw = vehicle.rotation.y + vehicle.model.turret_yaw
	
	# Traverse turret physically toward commanded aim yaw
	var new_world_yaw = rotate_toward(current_turret_world_yaw, commanded_yaw, delta * trav_rate)
	vehicle.model.turret_yaw = new_world_yaw - vehicle.rotation.y
	if vehicle.turret != null:
		vehicle.turret.rotation.y = vehicle.model.turret_yaw
	if vehicle.visual_tank != null:
		vehicle.visual_tank.rotate_turret(vehicle.model.turret_yaw)
		
	# Goal pitch accounts for commanded sight pitch + ballistic superelevation
	var ballistic_elev = get_ballistic_elevation(sight_range_m, vehicle.get_active_ammo())
	var goal_bore_pitch = clampf(commanded_pitch + ballistic_elev, MIN_ELEVATION_RAD, MAX_ELEVATION_RAD)
	
	# Elevate gun physically toward goal bore pitch
	current_bore_pitch = rotate_toward(current_bore_pitch, goal_bore_pitch, delta * elev_rate)
	if vehicle.visual_tank != null:
		vehicle.visual_tank.elevate_gun(current_bore_pitch)
		
	current_bore_yaw = vehicle.rotation.y + vehicle.model.turret_yaw
	
	# Settling timer update
	var yaw_moving = absf(angle_difference(current_bore_yaw, commanded_yaw)) > 0.015
	var pitch_moving = absf(current_bore_pitch - goal_bore_pitch) > 0.01
	var hull_moving = vehicle.speed > 0.2 or absf(vehicle.yaw_rate) > 0.05
	
	if yaw_moving or pitch_moving or hull_moving:
		settling_timer = SETTLING_DURATION
		settling_state = SettlingState.UNSTABLE
	else:
		if settling_timer > 0.0:
			settling_timer = maxf(0.0, settling_timer - delta)
			settling_state = SettlingState.SETTLING if settling_timer > 0.0 else SettlingState.STABLE
		else:
			settling_state = SettlingState.STABLE
			
	# Update Camera position
	_update_camera_transform()
	
	# Optical Line of Sight & Acquisition Check
	_update_acquisition(delta, target_vehicle, world_3d)

func _update_acquisition(delta: float, target_vehicle, world_3d: World3D) -> void:
	if target_vehicle == null or vehicle == null:
		acquisition_state = AcquisitionState.NO_CONTACT
		target_has_los = false
		return
		
	var target_eye = target_vehicle.position + Vector3(0, 1.85, 0)
	var sight_pos = sight_camera.global_position if (sight_camera != null and sight_camera.is_inside_tree()) else (vehicle.position + Vector3(0, 2.7, 0))
	var offset = target_eye - sight_pos
	var dist = offset.length()
	var to_target_dir = offset.normalized()
	
	# Sight forward direction reflects commanded angles
	var sight_forward: Vector3
	if sight_camera != null and sight_camera.is_inside_tree():
		sight_forward = sight_camera.global_transform.basis * Vector3(0, 0, -1)
	else:
		var look_quat = Quaternion.from_euler(Vector3(commanded_pitch, commanded_yaw, 0.0))
		sight_forward = look_quat * Vector3(0, 0, -1)
		
	var angle_to_target = rad_to_deg(sight_forward.angle_to(to_target_dir))
	
	# Raycast check for true physical obstruction (terrain, buildings, berms)
	target_has_los = false
	if world_3d != null:
		var space = world_3d.direct_space_state
		if space != null:
			var query = PhysicsRayQueryParameters3D.create(sight_pos, target_eye, 1) # Layer 1 obstacles
			var hit = space.intersect_ray(query)
			target_has_los = hit.is_empty()
	else:
		target_has_los = true
		
	var in_fov = angle_to_target <= (optic_fov_deg * 0.5)
	
	if in_fov and target_has_los:
		visual_contact_duration += delta
		if visual_contact_duration > 0.5:
			acquisition_state = AcquisitionState.TRACKING if tracking_enabled else AcquisitionState.ACQUIRED
		else:
			acquisition_state = AcquisitionState.TARGET_VISIBLE
	else:
		visual_contact_duration = maxf(0.0, visual_contact_duration - delta * 2.0)
		if absf(angle_difference(current_bore_yaw, commanded_yaw)) > 0.1:
			acquisition_state = AcquisitionState.SLEWING
		else:
			acquisition_state = AcquisitionState.SEARCHING

# Check if gun is aligned within firing window
func is_bore_aligned() -> bool:
	var ballistic_elev = get_ballistic_elevation(sight_range_m, vehicle.get_active_ammo() if vehicle != null else null)
	var goal_bore_pitch = clampf(commanded_pitch + ballistic_elev, MIN_ELEVATION_RAD, MAX_ELEVATION_RAD)
	var yaw_aligned = absf(angle_difference(current_bore_yaw, commanded_yaw)) < 0.035
	var pitch_aligned = absf(current_bore_pitch - goal_bore_pitch) < 0.025
	return yaw_aligned and pitch_aligned

func can_fire_now() -> bool:
	if not is_bore_aligned(): return false
	if fire_policy == FirePolicy.FIRE_WHEN_STABLE and settling_state != SettlingState.STABLE:
		return false
	return true
