extends Control
class_name GunnerReticleOverlay
## Renders an authentic historical tank periscopic gunsight reticle overlay:
## - Circular optical aperture mask with peripheral shading
## - Stadiametric / milliradian deflection scale (ticks at 4, 8, 12, 16, 20 mils)
## - Vertical ballistic drop markings
## - Commanded Line-of-Sight reticle (central chevron / crosshair)
## - Actual physical bore alignment indicator (lagging indicator during traverse/elevation)
## - Faint lead-assist diamond based strictly on estimated contact data
## - Clear tactical telemetry badges (Sight Range, Gun Settling, Ammunition, Acquisition)

const GunnerSightSystem = preload("res://scripts/wego/GunnerSightSystem.gd")
const ContactTrack = preload("res://scripts/wego/ContactTrack.gd")

var sight_system: GunnerSightSystem
var player_vehicle = null
var contact_track: ContactTrack = null

# Colors
var reticle_color: Color = Color(0.92, 0.78, 0.40, 0.85) # Amber optics etching
var bore_color: Color = Color(0.45, 0.85, 0.95, 0.80)    # Cyan physical bore indicator
var lead_color: Color = Color(0.95, 0.55, 0.35, 0.65)    # Orange lead assist
var mask_color: Color = Color(0.04, 0.05, 0.06, 0.94)    # Optical mask blackout

# Reticle geometry constants
const RETICLE_RADIUS: float = 330.0 # Pixels for optical lens circle
const MILS_TO_PIXELS: float = 14.0  # Pixels per milliradian on screen

func _init(p_sight_system: GunnerSightSystem = null) -> void:
	sight_system = p_sight_system
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func set_systems(p_sight: GunnerSightSystem, p_vehicle = null, p_track: ContactTrack = null) -> void:
	sight_system = p_sight
	player_vehicle = p_vehicle
	contact_track = p_track
	queue_redraw()

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	if sight_system == null or not visible: return
	
	var viewport_size = get_viewport_rect().size
	var center = viewport_size * 0.5
	
	# 1. Outer Dark Optical Mask (Circular vignette)
	_draw_optic_mask(center, RETICLE_RADIUS)
	
	# 2. Main Etched Glass Reticle (Central Chevron and Crosshair)
	_draw_etched_reticle(center)
	
	# 3. Horizontal Milliradian Deflection Scale
	_draw_mil_deflection_scale(center)
	
	# 4. Vertical Ballistic Elevation Marks
	_draw_vertical_drop_scale(center)
	
	# 5. Physical Gun Bore Indicator (Turret / Gun Lag)
	_draw_actual_bore_indicator(center)
	
	# 6. Estimated Lead Indicator (No Truth Leaking!)
	_draw_estimated_lead_assist(center)
	
	# 7. Optical Telemetry HUD Cards
	_draw_optical_hud(viewport_size, center)

func _draw_optic_mask(center: Vector2, radius: float) -> void:
	var screen_rect = get_viewport_rect()
	# Draw peripheral blackout borders outside circular optic aperture
	var border_w = screen_rect.size.x
	var border_h = screen_rect.size.y
	
	# Outer border rectangles
	draw_rect(Rect2(0, 0, center.x - radius, border_h), mask_color)
	draw_rect(Rect2(center.x + radius, 0, center.x - radius, border_h), mask_color)
	draw_rect(Rect2(center.x - radius, 0, radius * 2.0, center.y - radius), mask_color)
	draw_rect(Rect2(center.x - radius, center.y + radius, radius * 2.0, center.y - radius), mask_color)
	
	# Etched outer ring
	draw_arc(center, radius, 0, TAU, 64, Color(0.2, 0.22, 0.25, 0.8), 2.5, true)
	draw_arc(center, radius - 4.0, 0, TAU, 64, Color(0.12, 0.14, 0.16, 0.6), 1.0, true)

func _draw_etched_reticle(center: Vector2) -> void:
	# Central Inverted Chevron (Primary Aim Point)
	var chevron_w = 9.0
	var chevron_h = 8.0
	var tip = center
	var left_pt = center + Vector2(-chevron_w, chevron_h)
	var right_pt = center + Vector2(chevron_w, chevron_h)
	
	draw_line(left_pt, tip, reticle_color, 2.0, true)
	draw_line(right_pt, tip, reticle_color, 2.0, true)
	
	# Tiny center dot below chevron
	draw_circle(center + Vector2(0, 3), 1.2, reticle_color)

func _draw_mil_deflection_scale(center: Vector2) -> void:
	# Horizontal mils: -20, -16, -12, -8, -4, 0, 4, 8, 12, 16, 20
	var y = center.y
	var mils = [-20, -16, -12, -8, -4, 4, 8, 12, 16, 20]
	
	# Main horizontal baseline
	draw_line(center + Vector2(-22.0 * MILS_TO_PIXELS, 0), center + Vector2(-1.5 * MILS_TO_PIXELS, 0), reticle_color, 1.2, true)
	draw_line(center + Vector2(1.5 * MILS_TO_PIXELS, 0), center + Vector2(22.0 * MILS_TO_PIXELS, 0), reticle_color, 1.2, true)
	
	var font = ThemeDB.fallback_font
	for m in mils:
		var x = center.x + m * MILS_TO_PIXELS
		var tick_len = 8.0 if absi(m) % 8 == 0 else 5.0
		draw_line(Vector2(x, y - tick_len), Vector2(x, y + tick_len), reticle_color, 1.2, true)
		
		# Stadiametric mil numbers on major 8 and 16 mil ticks
		if absi(m) in [8, 16]:
			var txt = str(absi(m))
			draw_string(font, Vector2(x - 5, y + 20), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, reticle_color)

func _draw_vertical_drop_scale(center: Vector2) -> void:
	# Vertical drop marks below center (2, 4, 6, 8, 10, 12 mils)
	var x = center.x
	for mil in [2, 4, 6, 8, 10, 12]:
		var y = center.y + mil * MILS_TO_PIXELS
		var half_w = 6.0 if mil % 4 == 0 else 3.5
		draw_line(Vector2(x - half_w, y), Vector2(x + half_w, y), reticle_color, 1.2, true)

func _draw_actual_bore_indicator(center: Vector2) -> void:
	if sight_system == null or player_vehicle == null: return
	
	# Difference between physical bore yaw/pitch and commanded line-of-sight
	var yaw_diff = angle_difference(sight_system.commanded_yaw, sight_system.current_bore_yaw)
	var ballistic_elev = sight_system.get_ballistic_elevation(sight_system.sight_range_m, player_vehicle.get_active_ammo())
	var goal_bore_pitch = sight_system.commanded_pitch + ballistic_elev
	var pitch_diff = sight_system.current_bore_pitch - goal_bore_pitch
	
	# Convert angular difference (radians) to screen pixel offset
	# If bore is to the left of aim, yaw_diff is positive, so -yaw_diff correctly renders on the left of screen (-X)
	var x_offset = -yaw_diff * 1000.0 * (MILS_TO_PIXELS * 0.058)
	var y_offset = -pitch_diff * 1000.0 * (MILS_TO_PIXELS * 0.058)
	var bore_pos = center + Vector2(x_offset, y_offset)
	
	var is_aligned = sight_system.is_bore_aligned()
	var col = Color(0.2, 0.85, 0.45, 0.85) if is_aligned else bore_color
	
	# Draw small physical bore circle
	draw_arc(bore_pos, 7.0, 0, TAU, 24, col, 1.5, true)
	draw_line(bore_pos + Vector2(-10, 0), bore_pos + Vector2(-3, 0), col, 1.2, true)
	draw_line(bore_pos + Vector2(3, 0), bore_pos + Vector2(10, 0), col, 1.2, true)
	draw_line(bore_pos + Vector2(0, -10), bore_pos + Vector2(0, -3), col, 1.2, true)
	draw_line(bore_pos + Vector2(0, 3), bore_pos + Vector2(0, 10), col, 1.2, true)

func _draw_estimated_lead_assist(center: Vector2) -> void:
	if contact_track == null or not contact_track.has_contact(): return
	var ammo = player_vehicle.get_active_ammo() if player_vehicle != null else null
	var lead_mils = sight_system.get_estimated_lead_mils(contact_track, ammo)
	
	if absf(lead_mils) > 0.5:
		var lead_x = center.x + lead_mils * MILS_TO_PIXELS
		var lead_y = center.y
		
		# Draw faint bracket indicator
		var bracket_sz = 6.0
		draw_line(Vector2(lead_x - bracket_sz, lead_y - bracket_sz), Vector2(lead_x, lead_y - bracket_sz), lead_color, 1.5, true)
		draw_line(Vector2(lead_x - bracket_sz, lead_y - bracket_sz), Vector2(lead_x - bracket_sz, lead_y + bracket_sz), lead_color, 1.5, true)
		draw_line(Vector2(lead_x - bracket_sz, lead_y + bracket_sz), Vector2(lead_x, lead_y + bracket_sz), lead_color, 1.5, true)
		
		draw_line(Vector2(lead_x + bracket_sz, lead_y - bracket_sz), Vector2(lead_x, lead_y - bracket_sz), lead_color, 1.5, true)
		draw_line(Vector2(lead_x + bracket_sz, lead_y - bracket_sz), Vector2(lead_x + bracket_sz, lead_y + bracket_sz), lead_color, 1.5, true)
		draw_line(Vector2(lead_x + bracket_sz, lead_y + bracket_sz), Vector2(lead_x, lead_y + bracket_sz), lead_color, 1.5, true)
		
		var font = ThemeDB.fallback_font
		draw_string(font, Vector2(lead_x - 18, lead_y - 12), "LEAD", HORIZONTAL_ALIGNMENT_CENTER, -1, 9, lead_color)

func _draw_optical_hud(viewport_size: Vector2, center: Vector2) -> void:
	var font = ThemeDB.fallback_font
	
	# Top Right: Exit and Fire control hint
	var header_txt = "[ESC / G] EXIT TO TACTICAL  •  [SPACE / CLICK] QUEUE FIRE  •  [T] TRACK"
	draw_string(font, Vector2(viewport_size.x - 480, 32), header_txt, HORIZONTAL_ALIGNMENT_RIGHT, -1, 11, Color(0.7, 0.75, 0.8))
	
	# Top Center: Ammunition status
	var ammo_name = player_vehicle.get_active_ammo().name.to_upper() if (player_vehicle != null and player_vehicle.get_active_ammo() != null) else "92MM APCBC"
	var reload_left = player_vehicle.model.reload if player_vehicle != null else 0.0
	var ammo_txt = "%s  •  %s" % [ammo_name, "READY TO FIRE" if reload_left <= 0.05 else ("RELOADING (%.1fs)" % reload_left)]
	var ammo_col = Color(0.2, 0.85, 0.45) if reload_left <= 0.05 else Color(0.95, 0.65, 0.25)
	draw_string(font, Vector2(center.x - 140, center.y - RETICLE_RADIUS + 35), ammo_txt, HORIZONTAL_ALIGNMENT_CENTER, 280, 13, ammo_col)
	
	# Center Bottom: SIGHT RANGE (Big, clear, adjustable)
	var range_str = "SIGHT RANGE: %.0f M" % sight_system.sight_range_m
	draw_string(font, Vector2(center.x - 120, center.y + RETICLE_RADIUS - 45), range_str, HORIZONTAL_ALIGNMENT_CENTER, 240, 16, reticle_color)
	var hint_range = "[MOUSE WHEEL: ±50M  •  SHIFT+WHEEL: ±10M]"
	draw_string(font, Vector2(center.x - 140, center.y + RETICLE_RADIUS - 26), hint_range, HORIZONTAL_ALIGNMENT_CENTER, 280, 10, Color(0.65, 0.70, 0.75))
	
	# Left Badge: Gun Settling & Dispersion
	var settle_str = "GUN: STABLE"
	var settle_col = Color(0.25, 0.85, 0.45)
	match sight_system.settling_state:
		GunnerSightSystem.SettlingState.UNSTABLE:
			settle_str = "GUN: UNSTABLE (TRAVERSING)"
			settle_col = Color(0.95, 0.45, 0.35)
		GunnerSightSystem.SettlingState.SETTLING:
			settle_str = "GUN: SETTLING (%.1fs)" % sight_system.settling_timer
			settle_col = Color(0.95, 0.75, 0.30)
	draw_string(font, Vector2(center.x - RETICLE_RADIUS + 25, center.y - 45), settle_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, settle_col)
	
	var trav_time = sight_system.get_traverse_time_est()
	if trav_time > 0.05:
		draw_string(font, Vector2(center.x - RETICLE_RADIUS + 25, center.y - 28), "TRAVERSE: ~%.1f s" % trav_time, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.8, 0.8, 0.8))
	
	var disp_mils = sight_system.calculate_dispersion(player_vehicle.get_active_ammo() if player_vehicle != null else null) * 1000.0
	draw_string(font, Vector2(center.x - RETICLE_RADIUS + 25, center.y - 12), "DISPERSION: ±%.1f MILS" % disp_mils, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.7, 0.75))
	
	# Right Badge: Optical Target Acquisition
	var acq_str = "SEARCHING SECTOR"
	var acq_col = Color(0.5, 0.75, 0.85)
	match sight_system.acquisition_state:
		GunnerSightSystem.AcquisitionState.NO_CONTACT:
			acq_str = "OPTICS: NO CONTACT"
			acq_col = Color(0.6, 0.65, 0.70)
		GunnerSightSystem.AcquisitionState.SLEWING:
			acq_str = "OPTICS: SLEWING TO BEARING"
			acq_col = Color(0.90, 0.75, 0.35)
		GunnerSightSystem.AcquisitionState.SEARCHING:
			acq_str = "OPTICS: SEARCHING"
			acq_col = Color(0.45, 0.80, 0.90)
		GunnerSightSystem.AcquisitionState.TARGET_VISIBLE:
			acq_str = "OPTICS: TARGET VISIBLE!"
			acq_col = Color(0.95, 0.85, 0.30)
		GunnerSightSystem.AcquisitionState.ACQUIRED:
			acq_str = "OPTICS: TARGET ACQUIRED"
			acq_col = Color(0.25, 0.85, 0.45)
		GunnerSightSystem.AcquisitionState.TRACKING:
			acq_str = "OPTICS: TRACKING TARGET"
			acq_col = Color(0.25, 0.90, 0.55)
	draw_string(font, Vector2(center.x + RETICLE_RADIUS - 190, center.y - 45), acq_str, HORIZONTAL_ALIGNMENT_RIGHT, -1, 11, acq_col)
	
	# Bottom Advisory Banner: Commander's reported contact intel
	if contact_track != null and contact_track.has_contact():
		var cmd_text = "COMMANDER: %s • BEARING %03d° • EST RANGE %.0f M (±%.0f M) • HEADING %03d°" % [
			contact_track.classification.to_upper(),
			int(contact_track.estimated_bearing_deg),
			contact_track.estimated_range,
			contact_track.range_uncertainty,
			int(contact_track.estimated_heading_deg)
		]
		draw_string(font, Vector2(center.x - 300, viewport_size.y - 45), cmd_text, HORIZONTAL_ALIGNMENT_CENTER, 600, 11, Color(0.92, 0.75, 0.35))
