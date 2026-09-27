extends Control
class_name GunnerReticleOverlay
## Renders a period-authentic late-WWII A-47 optical tank telescope:
## - Arched telescope aperture housing with cast-metal vignette and subtle glass tint
## - Fictional A-47 etched glass reticle (central chevron, stadia ring, mil graduations)
## - Horizontal mil deflection scale for manual target lead (5, 10, 15, 20 mils)
## - Vertical ballistic range markings calibrated for 92mm APCBC (4, 8, 12, 16, 20, 24)
## - Mechanical Range Drum instrument window (APCBC [ 0850 ])
## - Authentic crew callout announcements ("TARGET!", "On!", "Up!", "SHORT!", "OVER!")
## - Clean instrument status (no magic lead dots or raw dispersion numbers in normal mode)
## - F3 Technical Debug Telemetry

const GunnerSightSystem = preload("res://scripts/wego/GunnerSightSystem.gd")
const ContactTrack = preload("res://scripts/wego/ContactTrack.gd")

var sight_system: GunnerSightSystem
var player_vehicle = null
var contact_track: ContactTrack = null
var debug_mode: bool = false

# Colors - Late WWII Etched Optical Glass & Cast Metal
var reticle_color: Color = Color(0.92, 0.78, 0.40, 0.88) # Warm etched glass amber
var reticle_dim: Color = Color(0.75, 0.62, 0.32, 0.65)   # Secondary stadia marks
var housing_color: Color = Color(0.04, 0.05, 0.06, 0.96) # Cast metal housing
var glass_tint: Color = Color(0.20, 0.32, 0.22, 0.07)    # Subtle anti-reflective optical glass coating
var drum_bg: Color = Color(0.08, 0.09, 0.10, 0.95)       # Mechanical counter backing
var callout_col: Color = Color(0.98, 0.88, 0.45)        # Intercom text highlight

# Aperture geometry
const APERTURE_WIDTH: float = 680.0
const APERTURE_HEIGHT: float = 540.0
const CORNER_RADIUS: float = 65.0
const MILS_TO_PIXELS: float = 14.0 # 14 pixels per milliradian

# Crew Callout Banner
var active_callout: String = ""
var callout_speaker: String = ""
var callout_timer: float = 0.0

func _init(p_sight_system: GunnerSightSystem = null) -> void:
	sight_system = p_sight_system
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func set_systems(p_sight: GunnerSightSystem, p_vehicle = null, p_track: ContactTrack = null) -> void:
	sight_system = p_sight
	player_vehicle = p_vehicle
	contact_track = p_track
	queue_redraw()

func trigger_callout(speaker: String, text: String, duration: float = 2.5) -> void:
	callout_speaker = speaker
	active_callout = text
	callout_timer = duration
	queue_redraw()

func _process(delta: float) -> void:
	if callout_timer > 0.0:
		callout_timer = maxf(0.0, callout_timer - delta)
		if callout_timer <= 0.0:
			active_callout = ""
		queue_redraw()
	elif visible:
		queue_redraw()

func _draw() -> void:
	if sight_system == null or not visible: return
	
	var viewport_size = get_viewport_rect().size
	var center = viewport_size * 0.5
	
	# 1. Outer Peripheral Vignette & Lens Rim (Full screen, transparent center)
	_draw_telescope_housing(viewport_size)
	
	# 2. Main A-47 Etched Reticle
	_draw_etched_reticle(center)
	
	# 3. Horizontal Mil Lead Scale
	_draw_mil_lead_scale(center)
	
	# 4. Vertical Ballistic Range Markings (92mm APCBC)
	_draw_vertical_ballistic_scale(center)
	
	# 5. Commanded Aim Lay Point (when laying gun)
	_draw_commanded_lay_indicator(center)
	
	# 6. Mechanical Range Drum & Breech Instruments
	_draw_mechanical_instruments(viewport_size, center)
	
	# 7. Crew Intercom / Callout Banner
	_draw_crew_callout(center, viewport_size)
	
	# 8. F3 Debug Telemetry (strictly hidden in normal play)
	if debug_mode:
		_draw_debug_telemetry(viewport_size)

func _draw_telescope_housing(vp_size: Vector2) -> void:
	# Full-screen subtle peripheral vignetting around extreme outer edges
	# Keeps 90%+ of the screen clear and completely open to the 3D battlefield
	var rim_color = Color(0.18, 0.20, 0.22, 0.85)
	var edge_shade = Color(0.02, 0.03, 0.04, 0.75)
	
	# Subtle edge masking strips (16px)
	draw_rect(Rect2(0, 0, vp_size.x, 16), edge_shade)
	draw_rect(Rect2(0, vp_size.y - 16, vp_size.x, 16), edge_shade)
	draw_rect(Rect2(0, 0, 16, vp_size.y), edge_shade)
	draw_rect(Rect2(vp_size.x - 16, 0, 16, vp_size.y), edge_shade)
	
	# Clean inner rim border
	var rim_rect = Rect2(16, 16, vp_size.x - 32, vp_size.y - 32)
	draw_rect(rim_rect, rim_color, false, 2.0)
	
	# Corner lens rounding gussets
	var corner_w = 42.0
	draw_rect(Rect2(16, 16, corner_w, 4), edge_shade)
	draw_rect(Rect2(16, 16, 4, corner_w), edge_shade)
	draw_rect(Rect2(vp_size.x - 16 - corner_w, 16, corner_w, 4), edge_shade)
	draw_rect(Rect2(vp_size.x - 20, 16, 4, corner_w), edge_shade)
	draw_rect(Rect2(16, vp_size.y - 20, corner_w, 4), edge_shade)
	draw_rect(Rect2(16, vp_size.y - 16 - corner_w, 4, corner_w), edge_shade)
	draw_rect(Rect2(vp_size.x - 16 - corner_w, vp_size.y - 20, corner_w, 4), edge_shade)
	draw_rect(Rect2(vp_size.x - 20, vp_size.y - 16 - corner_w, 4, corner_w), edge_shade)

func _draw_optical_glass(_vp_size: Vector2) -> void:
	# Omitted in normal mode for maximum clarity through optics
	pass

func _draw_etched_reticle(center: Vector2) -> void:
	# Central Aiming Chevron (Primary Point of Aim)
	var chev_w = 7.0
	var chev_h = 6.0
	var tip = center
	var left_pt = center + Vector2(-chev_w, chev_h)
	var right_pt = center + Vector2(chev_w, chev_h)
	draw_line(left_pt, tip, reticle_color, 1.8, true)
	draw_line(right_pt, tip, reticle_color, 1.8, true)
	
	# Center aiming pip (zero dot at tip)
	draw_circle(tip, 1.2, reticle_color)
	
	# Central Stadia Ring (8 mils diameter = 4 mils radius) with bottom opening for ballistic line
	var ring_radius = 4.0 * MILS_TO_PIXELS # 56 px
	var gap_angle = deg_to_rad(35.0)
	# Draw arc from gap_angle to PI - gap_angle (upper horseshoe)
	draw_arc(center, ring_radius, PI * 0.5 + gap_angle, PI * 2.5 - gap_angle, 48, reticle_dim, 1.2, true)
	
	# Stadia pips on ring at 3 o'clock and 9 o'clock
	draw_circle(center + Vector2(-ring_radius, 0), 1.8, reticle_color)
	draw_circle(center + Vector2(ring_radius, 0), 1.8, reticle_color)

func _draw_mil_lead_scale(center: Vector2) -> void:
	var font = ThemeDB.fallback_font
	var y = center.y
	
	# Horizontal Crosshairs extending left and right from the central ring
	var inner_gap = 4.5 * MILS_TO_PIXELS # start outside stadia ring
	var max_mil = 22.0
	draw_line(center + Vector2(-max_mil * MILS_TO_PIXELS, 0), center + Vector2(-inner_gap, 0), reticle_color, 1.2, true)
	draw_line(center + Vector2(inner_gap, 0), center + Vector2(max_mil * MILS_TO_PIXELS, 0), reticle_color, 1.2, true)
	
	# Mil graduations: 5, 10, 15, 20 mils
	var major_mils = [5, 10, 15, 20]
	var minor_mils = [2.5, 7.5, 12.5, 17.5]
	
	# Minor ticks
	for m in minor_mils:
		for sign_m in [-1.0, 1.0]:
			var x = center.x + m * sign_m * MILS_TO_PIXELS
			if absf(x - center.x) >= inner_gap:
				draw_line(Vector2(x, y - 3.5), Vector2(x, y + 3.5), reticle_dim, 1.0, true)
				
	# Major ticks with authentic period numerals
	for m in major_mils:
		for sign_m in [-1.0, 1.0]:
			var x = center.x + m * sign_m * MILS_TO_PIXELS
			if absf(x - center.x) >= inner_gap:
				draw_line(Vector2(x, y - 6.5), Vector2(x, y + 6.5), reticle_color, 1.4, true)
				var label_txt = str(m)
				draw_string(font, Vector2(x - 6, y + 18), label_txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, reticle_color)

func _draw_vertical_ballistic_scale(center: Vector2) -> void:
	var font = ThemeDB.fallback_font
	var x = center.x
	
	# Central vertical ballistic line descending below the chevron
	var start_y = center.y + 12.0
	var end_y = center.y + 160.0
	draw_line(Vector2(x, start_y), Vector2(x, end_y), reticle_color, 1.2, true)
	
	# Ballistic Range Hash Marks calibrated for 92mm APCBC:
	# 4 (400m), 8 (800m), 12 (1200m), 16 (1600m), 20 (2000m), 24 (2400m)
	var ranges = [
		{"range": 400, "label": "4", "drop_mils": 1.2, "stadia_w": 28.0},
		{"range": 800, "label": "8", "drop_mils": 3.2, "stadia_w": 22.0},
		{"range": 1200, "label": "12", "drop_mils": 5.8, "stadia_w": 16.0},
		{"range": 1600, "label": "16", "drop_mils": 8.9, "stadia_w": 12.0},
		{"range": 2000, "label": "20", "drop_mils": 12.5, "stadia_w": 9.0},
		{"range": 2400, "label": "24", "drop_mils": 16.8, "stadia_w": 7.0}
	]
	
	for entry in ranges:
		var mark_y = center.y + entry.drop_mils * MILS_TO_PIXELS
		var half_w = entry.stadia_w * 0.5
		
		# Horizontal vehicle-width stadia bar
		draw_line(Vector2(x - half_w, mark_y), Vector2(x + half_w, mark_y), reticle_color, 1.2, true)
		# Small center dot on line
		draw_circle(Vector2(x, mark_y), 1.0, reticle_color)
		# Range numeral to the left of the stadia bar
		draw_string(font, Vector2(x - half_w - 18, mark_y + 4), entry.label, HORIZONTAL_ALIGNMENT_RIGHT, -1, 10, reticle_color)

func _draw_commanded_lay_indicator(center: Vector2) -> void:
	if sight_system == null or player_vehicle == null: return
	
	# Calculate difference between commanded aim and physical bore
	var yaw_diff = angle_difference(sight_system.commanded_yaw, sight_system.current_bore_yaw)
	var ammo = player_vehicle.get_active_ammo() if player_vehicle != null else null
	var ballistic_elev = sight_system.get_ballistic_elevation(sight_system.sight_range_m, ammo)
	var goal_bore_pitch = sight_system.commanded_pitch + ballistic_elev
	var pitch_diff = sight_system.current_bore_pitch - goal_bore_pitch
	
	# If there is a commanded lay offset (turret traversing or fine laying queued)
	if absf(yaw_diff) > 0.001 or absf(pitch_diff) > 0.001:
		var x_offset = yaw_diff * 1000.0 * (MILS_TO_PIXELS * 0.058)
		var y_offset = pitch_diff * 1000.0 * (MILS_TO_PIXELS * 0.058)
		var lay_pos = center + Vector2(x_offset, y_offset)
		
		var lay_col = Color(0.4, 0.85, 0.55, 0.75) if sight_system.is_bore_aligned() else Color(0.95, 0.75, 0.35, 0.8)
		# Small dashed commanded lay circle
		draw_arc(lay_pos, 5.0, 0, TAU, 16, lay_col, 1.2, true)
		draw_line(lay_pos + Vector2(-3, 0), lay_pos + Vector2(3, 0), lay_col, 1.0, true)
		draw_line(lay_pos + Vector2(0, -3), lay_pos + Vector2(0, 3), lay_col, 1.0, true)

func _draw_mechanical_instruments(vp_size: Vector2, center: Vector2) -> void:
	var font = ThemeDB.fallback_font
	
	# --- Top Plate Stamping ---
	draw_string(font, Vector2(32, 32), "TELESCOPE No. 47 Mk. II", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.65, 0.68, 0.72, 0.65))
	draw_string(font, Vector2(vp_size.x - 170, 32), "92mm CANNON M3A1", HORIZONTAL_ALIGNMENT_RIGHT, -1, 10, Color(0.65, 0.68, 0.72, 0.65))
	
	# --- Bottom Left: Gun Breech & Ammunition Status ---
	var ammo_name = player_vehicle.get_active_ammo().name.to_upper() if (player_vehicle != null and player_vehicle.get_active_ammo() != null) else "92MM APCBC"
	var reload_left = player_vehicle.model.reload if player_vehicle != null else 0.0
	var is_loaded = reload_left <= 0.05
	
	var breech_box = Rect2(32, vp_size.y - 56, 172, 34)
	draw_rect(breech_box, drum_bg)
	draw_rect(breech_box, Color(0.28, 0.30, 0.32, 0.8), false, 1.2)
	
	var breech_status = "LOADED" if is_loaded else ("RAMMING (%.1fs)" % reload_left)
	var status_col = Color(0.3, 0.9, 0.5) if is_loaded else Color(0.95, 0.65, 0.25)
	draw_string(font, Vector2(breech_box.position.x + 8, breech_box.position.y + 14), ammo_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.7, 0.75, 0.8))
	draw_string(font, Vector2(breech_box.position.x + 8, breech_box.position.y + 27), breech_status, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, status_col)
	
	# --- Bottom Right: Mechanical Range Drum Instrument ---
	var drum_box = Rect2(vp_size.x - 204, vp_size.y - 56, 172, 34)
	draw_rect(drum_box, drum_bg)
	draw_rect(drum_box, Color(0.28, 0.30, 0.32, 0.8), false, 1.2)
	
	draw_string(font, Vector2(drum_box.position.x + 8, drum_box.position.y + 14), "RANGE DRUM [WHEEL]", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.7, 0.75, 0.8))
	var range_val = int(round(sight_system.sight_range_m))
	var range_str = "%04d m" % range_val
	var drum_wheel_rect = Rect2(drum_box.position.x + 88, drum_box.position.y + 6, 76, 22)
	draw_rect(drum_wheel_rect, Color(0.04, 0.05, 0.05))
	draw_rect(drum_wheel_rect, Color(0.4, 0.42, 0.45), false, 1.0)
	draw_string(font, Vector2(drum_wheel_rect.position.x + 8, drum_wheel_rect.position.y + 16), range_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, reticle_color)
	
	# --- Settling Indicator (subtle, only when settling) ---
	if sight_system.settling_state != GunnerSightSystem.SettlingState.STABLE:
		var settle_col = Color(0.95, 0.75, 0.35, 0.85)
		draw_string(font, Vector2(center.x - 60, vp_size.y - 38), "GUN SETTLING", HORIZONTAL_ALIGNMENT_CENTER, 120, 11, settle_col)

func _draw_crew_callout(center: Vector2, vp_size: Vector2) -> void:
	if active_callout.is_empty() or callout_timer <= 0.0: return
	var font = ThemeDB.fallback_font
	
	var callout_box = Rect2(center.x - 220, 20, 440, 32)
	var alpha = clampf(callout_timer * 1.5, 0.0, 1.0)
	var bg_col = Color(0.08, 0.10, 0.12, 0.92 * alpha)
	var border_col = Color(0.85, 0.75, 0.35, 0.85 * alpha)
	
	draw_rect(callout_box, bg_col)
	draw_rect(callout_box, border_col, false, 1.2)
	
	var full_text = "%s: \"%s\"" % [callout_speaker.to_upper(), active_callout]
	draw_string(font, Vector2(callout_box.position.x + 10, callout_box.position.y + 21), full_text, HORIZONTAL_ALIGNMENT_CENTER, 420, 12, Color(callout_col.r, callout_col.g, callout_col.b, alpha))

func _draw_debug_telemetry(vp_size: Vector2) -> void:
	var font = ThemeDB.fallback_font
	var deb_box = Rect2(32, 60, 260, 140)
	draw_rect(deb_box, Color(0.05, 0.06, 0.08, 0.90))
	draw_rect(deb_box, Color(0.3, 0.6, 0.8), false, 1.0)
	
	var y = deb_box.position.y + 18
	draw_string(font, Vector2(deb_box.position.x + 8, y), "DEBUG TELEMETRY [F3]", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.4, 0.8, 1.0))
	y += 18
	
	var disp_mils = sight_system.calculate_dispersion(player_vehicle.get_active_ammo() if player_vehicle != null else null) * 1000.0
	draw_string(font, Vector2(deb_box.position.x + 8, y), "Dispersion: ±%.2f mils" % disp_mils, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	y += 16
	
	var settle_str = "STABLE" if sight_system.settling_state == GunnerSightSystem.SettlingState.STABLE else ("SETTLING (%.2fs)" % sight_system.settling_timer)
	draw_string(font, Vector2(deb_box.position.x + 8, y), "Settling: %s" % settle_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	y += 16
	
	var trav_time = sight_system.get_traverse_time_est()
	draw_string(font, Vector2(deb_box.position.x + 8, y), "Traverse Remaining: ~%.2fs" % trav_time, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	y += 16
	
	var acq_name = ["NO_CONTACT", "SLEWING", "SEARCHING", "TARGET_VISIBLE", "ACQUIRED", "TRACKING"][sight_system.acquisition_state]
	draw_string(font, Vector2(deb_box.position.x + 8, y), "Acquisition: %s (LOS: %s)" % [acq_name, str(sight_system.target_has_los)], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	y += 16
	
	if contact_track != null and contact_track.has_contact():
		draw_string(font, Vector2(deb_box.position.x + 8, y), "Est Range: %.0fm (±%.0fm)" % [contact_track.estimated_range, contact_track.range_uncertainty], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
