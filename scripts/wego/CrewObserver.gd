extends RefCounted
class_name CrewObserver
## Models an individual tank crew member's optical station, look direction,
## field of view (FOV), optical magnification, line-of-sight, and detection progress.

enum Role {
	COMMANDER,
	GUNNER,
	LOADER,
	DRIVER
}

enum MountType {
	INDEPENDENT, # Rotates independently (e.g. CITV / panoramic commander cupola)
	TURRET,      # Slaved to turret / weapon sight
	HULL         # Fixed to hull forward arc (driver periscopes)
}

var role: int = Role.COMMANDER
var role_name: String = "Commander"
var mount_type: int = MountType.INDEPENDENT

# Physical look orientation (in world space)
var world_azimuth: float = 0.0     # Radians (0 = North / -Z, PI/2 = East / +X)
var elevation: float = 0.0         # Radians (pitch)
var azimuth_offset: float = 0.0    # Radians offset relative to mount

# Optical & Field of View capabilities
var horizontal_fov_deg: float = 60.0
var vertical_fov_deg: float = 25.0
var magnification: float = 1.0
var is_magnified: bool = false
var optic_quality: float = 1.0
var max_effective_range: float = 2500.0

# Wide vs Magnified preset values
var wide_fov_deg: float = 60.0
var wide_magnification: float = 1.0
var narrow_fov_deg: float = 15.0
var narrow_magnification: float = 4.0

# Current operational status
var current_task: String = "SCANNING" # SCANNING, TRACKING, DESIGNATING, RELOADING, DRIVING, INCAPACITATED, IDLE
var is_active: bool = true
var los_state: bool = false
var target_contact_id: String = ""

# Progressive detection progress per target: target_id -> float (0.0 to 1.0+)
var detection_progress: Dictionary = {}

func _init(p_role: int = Role.COMMANDER, p_role_name: String = "Commander") -> void:
	role = p_role
	role_name = p_role_name
	_configure_role_defaults()

func _configure_role_defaults() -> void:
	match role:
		Role.COMMANDER:
			mount_type = MountType.INDEPENDENT
			wide_fov_deg = 60.0
			wide_magnification = 1.0
			narrow_fov_deg = 16.0
			narrow_magnification = 4.5
			horizontal_fov_deg = wide_fov_deg
			vertical_fov_deg = 24.0
			magnification = wide_magnification
			max_effective_range = 2800.0
			current_task = "SCANNING"
			
		Role.GUNNER:
			mount_type = MountType.TURRET
			wide_fov_deg = 28.0
			wide_magnification = 2.5
			narrow_fov_deg = 11.0
			narrow_magnification = 8.0
			horizontal_fov_deg = narrow_fov_deg # Gunner defaults to magnified combat sight
			vertical_fov_deg = 12.0
			magnification = narrow_magnification
			is_magnified = true
			max_effective_range = 3200.0
			current_task = "TRACKING"
			
		Role.LOADER:
			mount_type = MountType.TURRET
			azimuth_offset = deg_to_rad(35.0) # Loader periscope offset
			wide_fov_deg = 45.0
			wide_magnification = 1.0
			narrow_fov_deg = 45.0
			narrow_magnification = 1.0
			horizontal_fov_deg = wide_fov_deg
			vertical_fov_deg = 20.0
			magnification = 1.0
			max_effective_range = 800.0
			current_task = "OBSERVING"
			
		Role.DRIVER:
			mount_type = MountType.HULL
			wide_fov_deg = 70.0
			wide_magnification = 1.0
			narrow_fov_deg = 70.0
			narrow_magnification = 1.0
			horizontal_fov_deg = wide_fov_deg
			vertical_fov_deg = 18.0
			magnification = 1.0
			max_effective_range = 500.0
			current_task = "DRIVING"

func set_zoom(magnified: bool) -> void:
	is_magnified = magnified
	if is_magnified:
		horizontal_fov_deg = narrow_fov_deg
		magnification = narrow_magnification
	else:
		horizontal_fov_deg = wide_fov_deg
		magnification = wide_magnification

func update_orientation(hull_yaw: float, turret_yaw: float, independent_bearing: Variant = null) -> void:
	match mount_type:
		MountType.HULL:
			# Driver looks forward with hull
			world_azimuth = hull_yaw + azimuth_offset
		MountType.TURRET:
			# Gunner / loader looks along turret plus offset
			world_azimuth = (hull_yaw + turret_yaw) + azimuth_offset
		MountType.INDEPENDENT:
			# Commander can look independently or follow turret if no independent order
			if independent_bearing != null:
				world_azimuth = independent_bearing
			else:
				world_azimuth = (hull_yaw + turret_yaw) + azimuth_offset

func can_observe(vehicle) -> bool:
	if vehicle == null or vehicle.model == null:
		return false
		
	# 1. Crew Member Incapacitation Check
	var crew_member = null
	for c in vehicle.model.crew:
		if c.name == role_name or c.station == role_name:
			crew_member = c
			break
			
	if crew_member == null:
		current_task = "INCAPACITATED"
		is_active = false
		return false
		
	if crew_member.state in ["Unconscious", "Seriously wounded"]:
		current_task = "INCAPACITATED"
		is_active = false
		return false
		
	# 2. Module / Optical Functional Check
	match role:
		Role.COMMANDER:
			if not vehicle.model.functional("Commander optics"):
				current_task = "OPTICS_DAMAGED"
				is_active = false
				return false
		Role.GUNNER:
			if not vehicle.model.functional("Gunsight"):
				current_task = "SIGHT_DAMAGED"
				is_active = false
				return false
				
	# 3. Workload / Task Interference Check
	match role:
		Role.LOADER:
			# If loader is actively loading or fighting fires, observation is suspended
			var is_reloading = vehicle.model.reload > 0.0
			var is_extinguishing = vehicle.orders.get("extinguish", false)
			if is_reloading or is_extinguishing:
				current_task = "RELOADING" if is_reloading else "FIGHTING_FIRE"
				is_active = false
				return false
			else:
				current_task = "OBSERVING"
				is_active = true
		Role.DRIVER:
			current_task = "DRIVING"
			is_active = true
		Role.GUNNER:
			is_active = true
		Role.COMMANDER:
			is_active = true
			
	return is_active

func is_point_in_fov(target_pos: Vector3, eye_pos: Vector3) -> bool:
	var delta: Vector3 = target_pos - eye_pos
	var dist_xz = Vector2(delta.x, delta.z).length()
	if dist_xz < 0.001:
		return true # Directly above/below
		
	# Bearing in radians from eye to target (Godot coords: -Z is 0, +X is PI/2)
	var target_bearing = atan2(delta.x, -delta.z)
	var angle_diff = absf(angle_difference(world_azimuth, target_bearing))
	var half_fov_rad = deg_to_rad(horizontal_fov_deg * 0.5)
	
	if angle_diff > half_fov_rad:
		return false
		
	# Vertical elevation check
	var target_elevation = atan2(delta.y, dist_xz)
	var elev_diff = absf(angle_difference(elevation, target_elevation))
	var half_vert_fov_rad = deg_to_rad(vertical_fov_deg * 0.5)
	
	return elev_diff <= half_vert_fov_rad

func accumulate_detection(target_id: String, base_rate: float, delta_time: float) -> float:
	var current: float = detection_progress.get(target_id, 0.0)
	var gain = base_rate * delta_time
	var new_val = clampf(current + gain, 0.0, 1.0)
	detection_progress[target_id] = new_val
	return new_val

func get_detection_stage(target_id: String) -> String:
	var score: float = detection_progress.get(target_id, 0.0)
	if score < 0.20:
		return "UNKNOWN"
	elif score < 0.45:
		return "POSSIBLE CONTACT"
	elif score < 0.70:
		return "VEHICLE"
	elif score < 0.90:
		return "ARMORED VEHICLE"
	else:
		return "EXACT_ID"

func get_bearing_cardinal() -> String:
	var deg = fposmod(rad_to_deg(world_azimuth), 360.0)
	if deg >= 337.5 or deg < 22.5: return "N"
	elif deg < 67.5: return "NE"
	elif deg < 112.5: return "E"
	elif deg < 157.5: return "SE"
	elif deg < 202.5: return "S"
	elif deg < 247.5: return "SW"
	elif deg < 292.5: return "W"
	else: return "NW"

func get_status_text() -> String:
	var card = get_bearing_cardinal()
	match role:
		Role.COMMANDER:
			if not is_active:
				return "COMMANDER: %s" % current_task
			var zoom_str = "MAG %dx" % int(magnification) if is_magnified else "WIDE"
			return "COMMANDER: %s %s • %d° FOV (%s)" % [current_task, card, int(horizontal_fov_deg), zoom_str]
		Role.GUNNER:
			if not is_active:
				return "GUNNER: %s" % current_task
			var zoom_str = "%.1fx" % magnification
			return "GUNNER: %s %s • %d° FOV (%s)" % [current_task, card, int(horizontal_fov_deg), zoom_str]
		Role.DRIVER:
			if not is_active:
				return "DRIVER: %s" % current_task
			return "DRIVER: %s • %d° FOV" % [current_task, int(horizontal_fov_deg)]
		Role.LOADER:
			if not is_active:
				return "LOADER: %s" % current_task
			return "LOADER: %s %s • %d° FOV" % [current_task, card, int(horizontal_fov_deg)]
	return "%s: %s" % [role_name.to_upper(), current_task]
