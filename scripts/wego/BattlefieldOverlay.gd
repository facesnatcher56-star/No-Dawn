extends Control
## Screen-space tactical symbols, contact tracks, ghost silhouettes,
## predicted movement corridors, and firing solutions.

var game
var font: Font = ThemeDB.fallback_font
var label_rects: Array[Rect2] = []
const BLUE = Color("8cddf0")
const AMBER = Color("efc477")
const RED = Color("ff9b86")
const MAGENTA = Color("ff66cc")
const GREEN = Color("77dd77")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	queue_redraw()

func screen(point: Vector3) -> Vector2:
	if game == null or game.camera == null:
		return Vector2.ZERO
	return game.camera.unproject_position(point)

func _has_valid_poly_area(pts: PackedVector2Array) -> bool:
	if pts.size() < 3: return false
	var indices = Geometry2D.triangulate_polygon(pts)
	return indices.size() >= 3

func _tag(at: Vector2, words: String, tint: Color) -> void:
	var lines = words.split("\n")
	var width = 0.0
	for line in lines: width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x)
	var extent = Vector2(width + 18, lines.size() * 19 + 10)
	var origin = at - Vector2(extent.x / 2, 0)
	origin.x = clampf(origin.x, 14, maxf(14, size.x - extent.x - 14))
	origin.y = clampf(origin.y, 45, maxf(45, size.y - extent.y - 45))
	var initial = origin
	for shift in [0, 1, -1, 2, -2, 3]:
		var candidate = initial + Vector2(0, shift * (extent.y + 10))
		candidate.y = clampf(candidate.y, 45, maxf(45, size.y - extent.y - 45))
		var rect = Rect2(candidate, extent)
		if not label_rects.any(func(other): return other.grow(4).intersects(rect)):
			origin = candidate
			break
	label_rects.append(Rect2(origin, extent))
	draw_style_box(_box_style(tint), Rect2(origin, extent))
	for i in range(lines.size()):
		draw_string(font, origin + Vector2(9, 20 + i * 19), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, tint)

func _box_style(tint: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.055, 0.07, 0.85)
	style.border_color = Color(tint, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style

func _draw() -> void:
	label_rects.clear()
	if game == null or not is_instance_valid(game.player): return
	
	# 1. Crew Field-of-View Observation Arcs (Restrained tactical wedges)
	_draw_crew_fov_overlay()

	# 2. Player Vehicle Status (Non-intrusive activity tag during execution only)
	if game.phase == "EXECUTION":
		var tank = screen(game.player.position + Vector3.UP * 1.8)
		var activity = ""
		if game.player.speed > 0.1: activity = "MOVING"
		elif game.travel_target != null: activity = "TURNING"
		elif game.player.shot_pending: activity = "FIRING"
		if not activity.is_empty():
			_tag(tank + Vector2(0, -32), activity, BLUE)
			
	# 3. Contact Track, Ghost Silhouette & Predicted Corridor
	var track = game.player_track
	var confirmed: bool = game.contact_is_visible()
	var cam = game.camera
	
	if track != null and track.has_contact() and not game.display_contact.is_empty():
		# A. Predicted Movement Corridor (if target was moving when lost)
		if track.has_silhouette and not confirmed and track.estimated_speed_mps > 0.4:
			var corridor = track.get_predicted_corridor(5.5)
			var left_scr = PackedVector2Array()
			var right_scr = PackedVector2Array()
			var valid_corridor = true
			for pt in corridor.left_edge:
				if cam != null and cam.is_position_behind(pt):
					valid_corridor = false
					break
				left_scr.append(screen(pt + Vector3.UP * 0.2))
			if valid_corridor:
				for pt in corridor.right_edge:
					if cam != null and cam.is_position_behind(pt):
						valid_corridor = false
						break
					right_scr.append(screen(pt + Vector3.UP * 0.2))
			
			if valid_corridor and left_scr.size() >= 2 and right_scr.size() >= 2:
				var poly = PackedVector2Array()
				for pt in left_scr: poly.append(pt)
				for i in range(right_scr.size() - 1, -1, -1): poly.append(right_scr[i])
				if _has_valid_poly_area(poly):
					draw_colored_polygon(poly, Color(AMBER.r, AMBER.g, AMBER.b, 0.08))
				for i in range(left_scr.size() - 1):
					draw_dashed_line(left_scr[i], left_scr[i + 1], Color(AMBER, 0.35), 1.5, 6, true)
					draw_dashed_line(right_scr[i], right_scr[i + 1], Color(AMBER, 0.35), 1.5, 6, true)
				
		# B. Last-Known Silhouette (Ghost)
		if track.has_silhouette and not confirmed:
			var ghost_pos = track.silhouette_position
			var ghost_yaw = track.silhouette_yaw
			var ghost_basis = Basis(Vector3.UP, ghost_yaw)
			
			if cam == null or not cam.is_position_behind(ghost_pos):
				# Draw ghost tank hull box outline
				var hl = 3.5 # half length
				var hw = 1.7 # half width
				var corners = [
					ghost_pos + ghost_basis * Vector3(-hw, 0.3, -hl),
					ghost_pos + ghost_basis * Vector3(hw, 0.3, -hl),
					ghost_pos + ghost_basis * Vector3(hw, 0.3, hl),
					ghost_pos + ghost_basis * Vector3(-hw, 0.3, hl)
				]
				var scr_corners = PackedVector2Array()
				var valid_ghost = true
				for c in corners:
					if cam != null and cam.is_position_behind(c):
						valid_ghost = false
						break
					scr_corners.append(screen(c))
				if valid_ghost:
					scr_corners.append(scr_corners[0])
					draw_polyline(scr_corners, Color(AMBER.r, AMBER.g, AMBER.b, 0.65), 1.5, true)
					var ghost_center = screen(ghost_pos + Vector3.UP * 0.5)
					var ghost_h_pt = ghost_pos - ghost_basis.z * 4.0 + Vector3.UP * 0.5
					if cam == null or not cam.is_position_behind(ghost_h_pt):
						var ghost_heading_pt = screen(ghost_h_pt)
						draw_dashed_line(ghost_center, ghost_heading_pt, Color(AMBER, 0.7), 1.5, 5.0, true)
					
					var age = maxf(0.0, game.sim_time - track.silhouette_time)
					var spd_kmh = track.silhouette_speed_mps * 3.6
					var ghost_txt = "LAST SEEN %.1fs AGO\nHDG: %03d° ±%d°\nSPD: %.0f km/h" % [
						age,
						int(track.silhouette_heading_deg),
						int(track.heading_uncertainty),
						spd_kmh
					]
					_tag(ghost_center + Vector2(0, 30), ghost_txt, AMBER)
			
		# C. Current Estimated Position Area (Restrained, localized, clamped footprint)
		var center: Vector3 = game.contact_visual_position
		if cam == null or not cam.is_position_behind(center):
			var visual_r: float = 1.8 if confirmed else clampf(game.contact_visual_radius, 2.2, 5.5)
			var ring_scr = PackedVector2Array()
			var all_pts_valid = true
			for i in range(24):
				var angle = i * TAU / 24.0
				var p3d = center + Vector3(cos(angle) * visual_r, 0.25, sin(angle) * visual_r)
				if cam != null and cam.is_position_behind(p3d):
					all_pts_valid = false
					break
				ring_scr.append(screen(p3d))
				
			var tint = RED if confirmed else AMBER
			if all_pts_valid and ring_scr.size() >= 3:
				if _has_valid_poly_area(ring_scr):
					draw_colored_polygon(ring_scr, Color(tint.r, tint.g, tint.b, 0.08 if not confirmed else 0.14))
				for i in range(ring_scr.size()):
					var p1 = ring_scr[i]
					var p2 = ring_scr[(i + 1) % ring_scr.size()]
					if confirmed or i % 3 < 2:
						draw_line(p1, p2, Color(tint.r, tint.g, tint.b, 0.60 if not confirmed else 0.90), 1.5, true)
				
			var badge_3d = center + Vector3(0, 1.2, 0)
			if cam == null or not cam.is_position_behind(badge_3d):
				var middle = screen(badge_3d)
				label_rects.append(Rect2(middle - Vector2(12, 12), Vector2(24, 24)))
				draw_circle(middle, 11, Color(0.04, 0.06, 0.08, 0.92))
				draw_arc(middle, 11, 0, TAU, 32, tint, 1.5, true)
				draw_string(font, middle + Vector2(-4, 5), "!" if confirmed else "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, tint)
				
				var label_lines: Array[String] = []
				if confirmed:
					label_lines.append("CONTACT A • SIGHTED")
				elif track.has_silhouette:
					label_lines.append("CONTACT A • LAST KNOWN")
				else:
					label_lines.append("CONTACT A • ESTIMATE")
					
				var hdg_deg = int(track.estimated_heading_deg)
				var arrow_str = "↑ N"
				if hdg_deg >= 338 or hdg_deg < 23: arrow_str = "↑ N"
				elif hdg_deg < 68: arrow_str = "↗ NE"
				elif hdg_deg < 113: arrow_str = "→ E"
				elif hdg_deg < 158: arrow_str = "↘ SE"
				elif hdg_deg < 203: arrow_str = "↓ S"
				elif hdg_deg < 248: arrow_str = "↙ SW"
				elif hdg_deg < 293: arrow_str = "← W"
				else: arrow_str = "↖ NW"
				
				if track.estimated_speed_mps > 0.3:
					label_lines.append("%s (%.0f km/h)" % [arrow_str, track.estimated_speed_mps * 3.6])
				else:
					label_lines.append("STATIONARY")
					
				label_lines.append("%.0f m ±%.0f m" % [track.estimated_range, track.range_uncertainty])
				var conf_pct = int(track.identification_confidence * 100)
				var sol_str = game.player_firing_solution.solution_quality if game.player_firing_solution else "DEVELOPING"
				label_lines.append("CONFIDENCE: %d%% · %s" % [conf_pct, sol_str])
				
				_tag(middle + Vector2(0, -32), "\n".join(label_lines), tint)

	# 3. Destination Route
	if game.travel_target != null:
		var tank_screen = screen(game.player.position + Vector3.UP * 0.4)
		var destination = screen(game.travel_target + Vector3.UP * 0.4)
		label_rects.append(Rect2(destination - Vector2(14, 14), Vector2(28, 28)))
		draw_dashed_line(tank_screen, destination, BLUE, 2, 7, true)
		draw_arc(destination, 10, 0, TAU, 32, BLUE, 2, true)
		draw_line(destination + Vector2(-6, 0), destination + Vector2(6, 0), BLUE, 2)
		draw_line(destination + Vector2(0, -6), destination + Vector2(0, 6), BLUE, 2)
		_tag(destination + Vector2(0, 16), "%.0f m" % game.player.position.distance_to(game.travel_target), BLUE)

	# 4. Firing Solution & Aim Point
	if game.aim_selected or game.fields.fire.button_pressed:
		var point: Vector3 = game._planned_aim()
		var aim_3d = Vector3(point.x, 0.5, point.z)
		if cam != null and cam.is_position_behind(aim_3d):
			return
			
		var aim = screen(aim_3d)
		label_rects.append(Rect2(aim - Vector2(19, 19), Vector2(38, 38)))
		var fired: bool = game.phase == "EXECUTION" and game.fields.fire.button_pressed and not game.player.shot_pending
		var firing: bool = game.fields.fire.button_pressed and not fired
		var tint = RED if firing else BLUE
		var tank_3d = game.player.position + Vector3.UP * 0.4
		if not fired and (cam == null or not cam.is_position_behind(tank_3d)):
			var tank_pt = screen(tank_3d)
			draw_dashed_line(tank_pt, aim, Color(tint, 0.7), 1.5, 6, true)
		for offset in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			draw_line(aim + offset * 6, aim + offset * 15, tint, 2, true)
			
		# Aim Uncertainty / Dispersion Ellipse
		var sol = game.player_firing_solution
		if sol != null:
			var ellipse_pts = PackedVector2Array()
			var center_pt = sol.ellipse_center
			var major_dir = Vector3(sin(sol.ellipse_angle_rad), 0, -cos(sol.ellipse_angle_rad))
			var minor_dir = major_dir.cross(Vector3.UP)
			var visual_major = clampf(sol.ellipse_major_m, 1.8, 6.0)
			var visual_minor = clampf(sol.ellipse_minor_m, 1.0, 4.0)
			var valid_ellipse = true
			for i in range(33):
				var ang = TAU * i / 32.0
				var p3d = center_pt + major_dir * (cos(ang) * visual_major) + minor_dir * (sin(ang) * visual_minor)
				if cam != null and cam.is_position_behind(p3d):
					valid_ellipse = false
					break
				ellipse_pts.append(screen(p3d + Vector3.UP * 0.2))
			if valid_ellipse and ellipse_pts.size() >= 3:
				draw_polyline(ellipse_pts, Color(tint.r, tint.g, tint.b, 0.75), 1.5, true)
			if firing:
				_tag(aim + Vector2(0, 20), "AIM POINT • " + sol.solution_quality, tint)
		else:
			var spread: float = clampf(game.player.position.distance_to(point) * game._dispersion(game.player) * 2, 0.3, 5.0)
			var ellipse = PackedVector2Array()
			var valid_ellipse = true
			for i in range(33):
				var angle = TAU * i / 32.0
				var p3d = Vector3(point.x, 0.3, point.z) + Vector3(cos(angle) * spread, 0, sin(angle) * spread)
				if cam != null and cam.is_position_behind(p3d):
					valid_ellipse = false
					break
				ellipse.append(screen(p3d))
			if valid_ellipse and ellipse.size() >= 3:
				draw_polyline(ellipse, Color(tint.r, tint.g, tint.b, 0.75), 1.5, true)
			if firing:
				_tag(aim + Vector2(0, 20), "FIRE TARGET", tint)

	# 5. Shot Tracers & Results
	for event in game.shot_events:
		var focused: bool = not game.playback.active.is_empty() and game.playback.active.shot_id == event.id
		if game.shot_clock > event.until and not focused: continue
		var tint = BLUE if event.shooter == "Your tank" else RED
		var start = screen(event.from)
		var end = screen(event.to)
		var direction = (end - start).normalized()
		var lane = direction.orthogonal() * 3
		if event.known_origin: draw_line(start + lane, end + lane, tint, 3, true)
		else: draw_dashed_line(start + lane, end + lane, tint, 2, 7, true)
		if start.distance_to(end) > 16.0 and not direction.is_zero_approx():
			var arrow_tip = start.lerp(end, 0.65) + lane
			var poly = PackedVector2Array([
				arrow_tip + direction * 8.0,
				arrow_tip - direction.rotated(0.45) * 8.0,
				arrow_tip - direction.rotated(-0.45) * 8.0
			])
			if _has_valid_poly_area(poly):
				draw_colored_polygon(poly, tint)
		var age: float = game.shot_clock - event.fired
		if age < 1.5: draw_arc(start, 12 + age * 12, 0, TAU, 32, Color(tint, 1 - age / 1.5), 3, true)
		if event.result != "IN FLIGHT":
			draw_arc(end, 13, 0, TAU, 32, tint, 3, true)
			draw_line(end + Vector2(-5, -5), end + Vector2(5, 5), tint, 2)
			draw_line(end + Vector2(5, -5), end + Vector2(-5, 5), tint, 2)
		var shooter = "YOU" if event.shooter == "Your tank" else "CONTACT A"
		var caption = "SHOT #%02d • %s FIRED" % [event.id, shooter]
		if not event.known_origin: caption += "\nOrigin estimated from report"
		if event.result != "IN FLIGHT":
			caption = "SHOT #%02d • %s → %s\n%s" % [event.id, shooter, "YOUR TANK" if event.target == "Your tank" else event.target.to_upper(), event.result]
		_tag(end + Vector2(0, -85), caption, tint)

	# 6. Debug Overlay (F3 Toggle)
	if game.debug_overlay_enabled:
		_draw_debug_overlay()

func _draw_debug_overlay() -> void:
	if not is_instance_valid(game.enemy): return
	var real_enemy_scr = screen(game.enemy.position + Vector3.UP * 1.5)
	var believed_scr = screen(game.contact_visual_position + Vector3.UP * 1.5)
	
	# Real enemy position marker (Magenta)
	draw_circle(real_enemy_scr, 7, MAGENTA)
	draw_arc(real_enemy_scr, 14, 0, TAU, 24, MAGENTA, 2.0)
	
	# Error line from belief to truth
	draw_dashed_line(believed_scr, real_enemy_scr, MAGENTA, 2.0, 5.0)
	var error_dist = game.contact_visual_position.distance_to(game.enemy.position)
	_tag(real_enemy_scr + Vector2(0, -35), "TRUE ENEMY POSITION\nError: %.1fm" % error_dist, MAGENTA)
	
	# AI Belief Marker (Green)
	if game.enemy_track != null:
		var ai_belief_scr = screen(game.enemy_track.estimated_position + Vector3.UP * 1.0)
		draw_circle(ai_belief_scr, 5, GREEN)
		draw_arc(ai_belief_scr, 10, 0, TAU, 16, GREEN, 1.5)
		_tag(ai_belief_scr + Vector2(0, 15), "AI BELIEF OF PLAYER", GREEN)

	# Developer Observer Debug Visualization (C, G, L, D full simulation rays)
	_draw_debug_crew_observers()
		
	# Debug Info Panel in Top-Right
	var dbg_lines = [
		"DEBUG (F3): SIMULTANEOUS WEGO ACTIVE",
		"Sim Time: %.2fs • Pulse: #%d (%s, %.1fs left)" % [
			game.sim_time,
			game.timeline.pulse_number,
			"COMBAT (3s)" if game.timeline.current_mode == 1 else "MANEUVER (8s)",
			game.timeline.pulse_time_left
		],
		"Visual LOS: %s • Gunner Acquired: %s" % [
			"YES" if game.contact_is_visible() else "NO",
			"YES" if (game.player_track and game.player_track.gunner_acquired) else "NO"
		],
		"Track: Rng=%.1f±%.1fm • Spd=%.1f±%.1fm/s • Hdg=%03d°±%d°" % [
			game.player_track.estimated_range if game.player_track else 0.0,
			game.player_track.range_uncertainty if game.player_track else 0.0,
			game.player_track.estimated_speed_mps if game.player_track else 0.0,
			game.player_track.speed_uncertainty if game.player_track else 0.0,
			int(game.player_track.estimated_heading_deg) if game.player_track else 0,
			int(game.player_track.heading_uncertainty) if game.player_track else 0
		]
	]
	_tag(Vector2(size.x - 220, 50), "\n".join(dbg_lines), MAGENTA)

func _draw_crew_fov_overlay() -> void:
	if game == null or not is_instance_valid(game.player): return
	if "show_crew_fov_overlay" in game and not game.show_crew_fov_overlay: return
	var cam = game.camera
	var tank = game.player
	var tank_pos = tank.position + Vector3(0, 0.15, 0)
	if cam != null and cam.is_position_behind(tank_pos): return
	if not ("observers" in tank) or tank.observers.is_empty(): return
	
	var center_scr = screen(tank_pos)
	
	# Restrained, bounded observation sectors
	# Order: Driver (10m) -> Loader (8.5m) -> Gunner (16m) -> Commander (22m, most prominent)
	var ordered_roles = ["Driver", "Loader", "Gunner", "Commander"]
	for r_name in ordered_roles:
		var obs = tank.observers.get(r_name, null)
		if obs == null or not obs.is_active: continue
		
		var max_r = 10.0
		var fill_color = Color(0.3, 0.6, 0.8, 0.05)
		var border_color = Color(0.3, 0.6, 0.8, 0.25)
		
		match obs.role:
			0: # COMMANDER - Primary Situational Awareness Sensor
				max_r = 22.0
				fill_color = Color(0.15, 0.55, 0.90, 0.12)
				border_color = Color(0.28, 0.72, 0.98, 0.55)
			1: # GUNNER
				max_r = 16.0
				fill_color = Color(0.92, 0.70, 0.25, 0.08)
				border_color = Color(0.92, 0.70, 0.25, 0.40)
			2: # LOADER
				max_r = 8.5
				fill_color = Color(0.65, 0.65, 0.65, 0.04)
				border_color = Color(0.65, 0.65, 0.65, 0.20)
			3: # DRIVER
				max_r = 10.0
				fill_color = Color(0.35, 0.75, 0.55, 0.05)
				border_color = Color(0.35, 0.75, 0.55, 0.22)
				
		var center_azimuth = obs.world_azimuth
		var half_fov = deg_to_rad(obs.horizontal_fov_deg * 0.5)
		var steps = 16
		var arc_pts = PackedVector2Array()
		var all_pts_valid = true
		
		for i in range(steps + 1):
			var a = center_azimuth - half_fov + (2.0 * half_fov * float(i) / float(steps))
			var p3d = tank_pos + Vector3(sin(a) * max_r, 0, -cos(a) * max_r)
			if cam != null and cam.is_position_behind(p3d):
				all_pts_valid = false
				break
			arc_pts.append(screen(p3d))
			
		if all_pts_valid and arc_pts.size() >= 3:
			var poly = PackedVector2Array()
			poly.append(center_scr)
			for p in arc_pts: poly.append(p)
			if _has_valid_poly_area(poly):
				draw_colored_polygon(poly, fill_color)
			draw_polyline(arc_pts, border_color, 1.5, true)
			draw_dashed_line(center_scr, arc_pts[0], Color(border_color, 0.4), 1.0, 4.0, true)
			draw_dashed_line(center_scr, arc_pts[arc_pts.size() - 1], Color(border_color, 0.4), 1.0, 4.0, true)
			var mid_idx = steps / 2
			draw_line(center_scr, arc_pts[mid_idx], border_color, 1.2, true)

func _draw_debug_crew_observers() -> void:
	if game == null or not is_instance_valid(game.player) or not ("observers" in game.player): return
	var cam = game.camera
	var eye = game.player.position + Vector3(0, 2.75, 0)
	if cam != null and cam.is_position_behind(eye): return
	var scr_eye = screen(eye)
	
	for r_name in ["Commander", "Gunner", "Loader", "Driver"]:
		var obs = game.player.observers.get(r_name, null)
		if obs == null: continue
		var lbl = r_name[0] # C, G, L, D
		var a = obs.world_azimuth
		var ray_len = minf(obs.max_effective_range, 75.0)
		var p3d_end = eye + Vector3(sin(a) * ray_len, 0, -cos(a) * ray_len)
		if cam != null and cam.is_position_behind(p3d_end): continue
		var scr_end = screen(p3d_end)
		var ray_color = GREEN if obs.is_active else RED
		draw_line(scr_eye, scr_end, ray_color, 1.5, true)
		draw_circle(scr_end, 9, Color(0.04, 0.05, 0.07, 0.92))
		draw_arc(scr_end, 9, 0, TAU, 16, ray_color, 1.5)
		draw_string(font, scr_end + Vector2(-4, 4), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ray_color)
		
		# Show target detection progress if target is tracked
		if is_instance_valid(game.enemy):
			var score = obs.detection_progress.get(game.enemy.name, 0.0)
			if score > 0.0:
				var stage = obs.get_detection_stage(game.enemy.name)
				_tag(scr_end + Vector2(0, 16), "%s: %d%% [%s]" % [lbl, int(score * 100), stage], ray_color)
