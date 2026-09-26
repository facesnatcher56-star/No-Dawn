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
	
	# 1. Player Vehicle Status (Non-intrusive activity tag during execution only)
	if game.phase == "EXECUTION":
		var tank = screen(game.player.position + Vector3.UP * 1.8)
		var activity = ""
		if game.player.speed > 0.1: activity = "MOVING"
		elif game.travel_target != null: activity = "TURNING"
		elif game.player.shot_pending: activity = "FIRING"
		if not activity.is_empty():
			_tag(tank + Vector2(0, -32), activity, BLUE)
			
	# 2. Contact Track, Ghost Silhouette & Predicted Corridor
	var track = game.player_track
	var confirmed: bool = game.contact_is_visible()
	
	if track != null and (track.has_silhouette or not game.display_contact.is_empty()):
		# A. Predicted Movement Corridor (if target was moving when lost)
		if track.has_silhouette and not confirmed and track.estimated_speed_mps > 0.4:
			var corridor = track.get_predicted_corridor(5.5)
			var left_scr = PackedVector2Array()
			var right_scr = PackedVector2Array()
			var valid_corridor = true
			for pt in corridor.left_edge:
				if game.camera != null and game.camera.is_position_behind(pt):
					valid_corridor = false
					break
				left_scr.append(screen(pt + Vector3.UP * 0.2))
			if valid_corridor:
				for pt in corridor.right_edge:
					if game.camera != null and game.camera.is_position_behind(pt):
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
			for c in corners: scr_corners.append(screen(c))
			scr_corners.append(scr_corners[0])
			
			draw_polyline(scr_corners, Color(AMBER.r, AMBER.g, AMBER.b, 0.65), 2.0, true)
			var ghost_center = screen(ghost_pos + Vector3.UP * 0.5)
			var ghost_heading_pt = screen(ghost_pos - ghost_basis.z * 5.0 + Vector3.UP * 0.5)
			draw_dashed_line(ghost_center, ghost_heading_pt, Color(AMBER, 0.7), 2.0, 5.0, true)
			
			var age = maxf(0.0, game.sim_time - track.silhouette_time)
			var spd_kmh = track.silhouette_speed_mps * 3.6
			var ghost_txt = "LAST SEEN %.1fs AGO\nHDG: %03d° ±%d°\nSPD: %.0f km/h" % [
				age,
				int(track.silhouette_heading_deg),
				int(track.heading_uncertainty),
				spd_kmh
			]
			_tag(ghost_center + Vector2(0, 30), ghost_txt, AMBER)
			
		# C. Current Estimated Position Area
		var center: Vector3 = game.contact_visual_position
		var radius: float = game.contact_visual_radius
		var ring = PackedVector2Array()
		for i in range(32):
			var angle = i * TAU / 32.0
			ring.append(screen(center + Vector3(cos(angle) * radius, 0.35, sin(angle) * radius)))
			
		var tint = RED if confirmed else AMBER
		if _has_valid_poly_area(ring):
			draw_colored_polygon(ring, Color(tint, 0.10))
		for i in range(ring.size()):
			var p1 = ring[i]
			var p2 = ring[(i + 1) % ring.size()]
			if confirmed or i % 4 < 2: draw_line(p1, p2, Color(tint, 0.85), 2, true)
			
		var middle = screen(center + Vector3.UP)
		label_rects.append(Rect2(middle - Vector2(14, 14), Vector2(28, 28)))
		draw_circle(middle, 11, Color(0.05, 0.07, 0.08, 0.95))
		draw_arc(middle, 11, 0, TAU, 32, tint, 2, true)
		draw_string(font, middle + Vector2(-4, 5), "!" if confirmed else "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, tint)
		
		var top = middle.y
		for point in ring: top = minf(top, point.y)
		var label_lines: Array[String] = []
		if confirmed:
			label_lines.append("CONTACT A • SIGHTED")
		elif track != null and track.has_silhouette:
			label_lines.append("CONTACT A • LAST KNOWN")
		else:
			label_lines.append("CONTACT A • ESTIMATE")
			
		if track != null:
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
		else:
			label_lines.append("%.0f m" % game.player.position.distance_to(center))
			
		_tag(Vector2(middle.x, top - 24), "\n".join(label_lines), tint)

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
		var aim = screen(Vector3(point.x, 0.5, point.z))
		label_rects.append(Rect2(aim - Vector2(19, 19), Vector2(38, 38)))
		var fired: bool = game.phase == "EXECUTION" and game.fields.fire.button_pressed and not game.player.shot_pending
		var firing: bool = game.fields.fire.button_pressed and not fired
		var tint = RED if firing else BLUE
		var tank_pt = screen(game.player.position + Vector3.UP * 0.4)
		if not fired: draw_dashed_line(tank_pt, aim, Color(tint, 0.7), 1.5, 6, true)
		for offset in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			draw_line(aim + offset * 6, aim + offset * 15, tint, 2, true)
			
		# Aim Uncertainty / Dispersion Ellipse
		var sol = game.player_firing_solution
		if sol != null:
			var ellipse_pts = PackedVector2Array()
			var center_pt = sol.ellipse_center
			var major_dir = Vector3(sin(sol.ellipse_angle_rad), 0, -cos(sol.ellipse_angle_rad))
			var minor_dir = major_dir.cross(Vector3.UP)
			for i in range(49):
				var ang = TAU * i / 48.0
				var p3d = center_pt + major_dir * (cos(ang) * sol.ellipse_major_m) + minor_dir * (sin(ang) * sol.ellipse_minor_m)
				ellipse_pts.append(screen(p3d + Vector3.UP * 0.4))
			draw_polyline(ellipse_pts, Color(tint, 0.75), 1.5, true)
			if firing:
				_tag(aim + Vector2(0, 20), "AIM POINT • " + sol.solution_quality, tint)
		else:
			var spread: float = maxf(0.3, game.player.position.distance_to(point) * game._dispersion(game.player) * 2)
			var ellipse = PackedVector2Array()
			for i in range(49):
				var angle = TAU * i / 48.0
				ellipse.append(screen(Vector3(point.x, 0.5, point.z) + Vector3(cos(angle) * spread, 0, sin(angle) * spread)))
			draw_polyline(ellipse, tint, 1, true)
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
