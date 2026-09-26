extends RefCounted
class_name FiringSolution
## Calculates moving-target lead, separates firing-solution prediction error
## from mechanical weapon dispersion, and computes uncertainty ellipses.

const ArmorModel = preload("res://scripts/wego/ArmorModel.gd")

var predicted_target_position: Vector3 = Vector3.ZERO
var aim_point: Vector3 = Vector3.ZERO
var flight_time: float = 0.0
var solution_quality: String = "POOR" # "POOR", "DEVELOPING", "ACQUIRED", "OPTIMAL"
var target_error_offset: Vector3 = Vector3.ZERO
var dispersion_cone_rad: float = 0.0015
var range_m: float = 75.0
var lead_offset: Vector3 = Vector3.ZERO

# Uncertainty ellipse data (for overlay display)
var ellipse_center: Vector3 = Vector3.ZERO
var ellipse_major_m: float = 20.0
var ellipse_minor_m: float = 5.0
var ellipse_angle_rad: float = 0.0

static func calculate(
	shooter,
	track,
	rng: RandomNumberGenerator,
	muzzle_speed: float = 740.0
) -> RefCounted:
	var sol = (load("res://scripts/wego/FiringSolution.gd") as GDScript).new()
	if shooter == null or track == null:
		return sol

	var origin: Vector3 = shooter.position + Vector3(0, 2.65, 0)
	var est_pos: Vector3 = track.estimated_position
	sol.range_m = maxf(10.0, origin.distance_to(est_pos))
	sol.flight_time = sol.range_m / muzzle_speed
	
	# 1. Moving Target Lead (uses ESTIMATED speed and heading, NOT hidden truth!)
	var heading_rad = deg_to_rad(track.estimated_heading_deg)
	var est_vel = Vector3(sin(heading_rad), 0, -cos(heading_rad)) * track.estimated_speed_mps
	sol.lead_offset = est_vel * sol.flight_time
	sol.predicted_target_position = est_pos + sol.lead_offset
	sol.predicted_target_position.y = 1.45 # Target center of mass
	
	# Determine Solution Quality
	if track.gunner_acquired and track.range_uncertainty <= 8.0:
		sol.solution_quality = "OPTIMAL"
	elif track.gunner_acquired or track.range_uncertainty <= 16.0:
		sol.solution_quality = "ACQUIRED"
	elif track.has_visual_los or track.range_uncertainty <= 35.0:
		sol.solution_quality = "DEVELOPING"
	else:
		sol.solution_quality = "POOR"
		
	# 2. Target / Firing-Solution Error (Uncertainty in knowledge)
	# Range error along line-of-sight
	var los_dir = (sol.predicted_target_position - origin).normalized()
	los_dir.y = 0.0
	los_dir = los_dir.normalized()
	var right_dir = los_dir.cross(Vector3.UP).normalized()
	
	var range_error_std = track.range_uncertainty * 0.45
	var lateral_error_std = maxf(1.0, track.position_uncertainty * 0.4 + track.speed_uncertainty * sol.flight_time * 0.5)
	
	var sample_range_err = rng.randfn(0.0, range_error_std)
	var sample_lat_err = rng.randfn(0.0, lateral_error_std)
	sol.target_error_offset = los_dir * sample_range_err + right_dir * sample_lat_err
	
	# Aim center incorporates knowledge error (where the crew BELIEVES they should aim)
	sol.aim_point = sol.predicted_target_position + sol.target_error_offset
	
	# Gravity drop compensation for flight time
	sol.aim_point.y += 0.5 * 9.81 * sol.flight_time * sol.flight_time
	
	# 3. Weapon Dispersion (Mechanical and situational inaccuracies)
	var cone = 0.0012 # Base high-precision cannon
	if shooter.speed > 0.1:
		cone += 0.0055 # Firing on the move penalty
	if not shooter.model.functional("Gunner sight"):
		cone += 0.006 # Damaged optics
	if not shooter.model.occupied("Gunner"):
		cone += 0.008 # Commander or loader trying to lay gun
	sol.dispersion_cone_rad = cone
	
	# Ellipse parameters for visualization
	sol.ellipse_center = sol.predicted_target_position
	sol.ellipse_major_m = maxf(3.0, track.range_uncertainty)
	sol.ellipse_minor_m = maxf(2.0, lateral_error_std * 2.0)
	sol.ellipse_angle_rad = atan2(los_dir.x, -los_dir.z)
	
	return sol

func compute_shell_direction(origin: Vector3, rng: RandomNumberGenerator) -> Vector3:
	var nominal_dir = (aim_point - origin).normalized()
	var right = nominal_dir.cross(Vector3.UP).normalized()
	var up = right.cross(nominal_dir).normalized()
	var disp_x = rng.randfn(0.0, dispersion_cone_rad)
	var disp_y = rng.randfn(0.0, dispersion_cone_rad)
	return (nominal_dir + right * disp_x + up * disp_y).normalized()
