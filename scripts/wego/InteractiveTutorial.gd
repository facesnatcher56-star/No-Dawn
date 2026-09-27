extends CanvasLayer
class_name InteractiveTutorial
## Interactive step-by-step walkthrough tutorial for No Dawn.
## Guides players through camera orientation, WEGO movement planning,
## commander observation sectors, simultaneous execution, optical periscope gunnery,
## mechanical range drum calibration, and ballistic armor engagement.

var game = null

var current_step: int = 0
var is_active: bool = true
var is_minimized: bool = false
var objective_achieved: bool = false
var step_elapsed: float = 0.0

# Camera baseline tracking for Step 0
var baseline_cam_yaw: float = 0.0
var baseline_cam_pitch: float = 0.0
var baseline_cam_dist: float = 0.0

# UI Controls
var root_control: Control
var indicator_canvas: Control
var main_panel: PanelContainer
var reopen_button: Button

var step_badge_label: Label
var step_title_label: Label
var step_text_label: Label
var objective_icon_label: Label
var objective_text_label: Label
var hint_label: Label

var prev_button: Button
var next_button: Button
var skip_button: Button

# Highlight coordinates
var current_target_screen_pos: Vector2 = Vector2.ZERO
var target_has_position: bool = false

# Pulse / animation state
var anim_phase: float = 0.0

# Tutorial Step Definitions
var steps: Array = [
	{
		"id": "camera",
		"badge": "STEP 1 OF 8 • BASIC CONTROLS",
		"title": "TACTICAL CAMERA & PERSPECTIVE",
		"text": "Hold [RMB] to orbit/tilt. Roll [Wheel] to zoom. [WASD] pans camera, [F] re-centers on tank.",
		"objective": "Orbit (RMB) or zoom (Wheel) camera view",
		"hint": "Try holding RMB to rotate or rolling the wheel to zoom out.",
		"target_tag": "player_tank"
	},
	{
		"id": "move",
		"badge": "STEP 2 OF 8 • WEGO MANEUVER",
		"title": "PLOTTING MOVEMENT WAYPOINT",
		"text": "Left-click on the road ahead to plot a movement waypoint, or click [MOVE] on the bottom action bar.",
		"objective": "Plot a movement waypoint along the road",
		"hint": "Left-click on the road ahead of the Mastodon.",
		"target_tag": "action_move"
	},
	{
		"id": "observe",
		"badge": "STEP 3 OF 8 • RECONNAISSANCE",
		"title": "COMMANDER OBSERVATION SECTOR",
		"text": "Click [OBSERVE] on the bottom bar, then click down the avenue to designate Commander's search sector.",
		"objective": "Designate an observation sector down the road",
		"hint": "Click [OBSERVE], then click the distant road.",
		"target_tag": "action_observe"
	},
	{
		"id": "execute",
		"badge": "STEP 4 OF 8 • WEGO EXECUTION",
		"title": "SIMULTANEOUS PULSE EXECUTION",
		"text": "Click the green [EXECUTE] button at top center to begin the simultaneous 8.0-second turn pulse.",
		"objective": "Click [EXECUTE] to start simultaneous turn",
		"hint": "Click the green [EXECUTE] button at the top.",
		"target_tag": "execute_button"
	},
	{
		"id": "contact",
		"badge": "STEP 5 OF 8 • TARGET ACQUISITION",
		"title": "ENEMY DETECTED: CONTACT A",
		"text": "Target spotted ~1,500m down the road! Note estimated range and dynamic contact commands below.",
		"objective": "Review contact report (or wait for pulse to complete)",
		"hint": "Contact detected ~1,500m down the road.",
		"target_tag": "contact_label"
	},
	{
		"id": "gunner_sight",
		"badge": "STEP 6 OF 8 • OPTICAL GUNNERY",
		"title": "ENTER GUNNER SIGHT STATION",
		"text": "Press [G] or click [GUNNER SIGHT] to mount the physical periscope optic beside the 92mm cannon.",
		"objective": "Press [ G ] or click [ GUNNER SIGHT ]",
		"hint": "Press [G] to switch to periscope view.",
		"target_tag": "action_gunner"
	},
	{
		"id": "range_drum",
		"badge": "STEP 7 OF 8 • RANGE & LAYING",
		"title": "CALIBRATE RANGE DRUM & AIM",
		"text": "Use [Wheel] or [ [ ] / [ ] ] to dial range drum to ~1500m. Superelevation adjusts automatically.",
		"objective": "Dial range drum to ~1500m (aim at target)",
		"hint": "Scroll wheel to dial drum. Press [Enter] or [N] to proceed.",
		"target_tag": "range_drum"
	},
	{
		"id": "fire_shot",
		"badge": "STEP 8 OF 8 • BALLISTIC ENGAGEMENT",
		"title": "QUEUE FIRE ORDER & REPLAY",
		"text": "Left-click or press [Space] to queue a fire order. Ballistics & armor replay inspects terminal damage!",
		"objective": "Queue fire order or click Finish Tutorial",
		"hint": "Left-click in sight to fire, then click FINISH TUTORIAL.",
		"target_tag": "reticle_center"
	}
]

func _init(p_game = null) -> void:
	layer = 15 # Render above regular HUD
	game = p_game

func _ready() -> void:
	_build_tutorial_ui()
	_record_cam_baseline()
	_update_step_ui()

func _record_cam_baseline() -> void:
	if game != null:
		baseline_cam_yaw = game.cam_yaw
		baseline_cam_pitch = game.cam_pitch
		baseline_cam_dist = game.cam_distance

func _build_tutorial_ui() -> void:
	root_control = Control.new()
	root_control.name = "TutorialRoot"
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	# Indicator / Beacon Canvas
	indicator_canvas = TutorialIndicatorCanvas.new(self)
	indicator_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	indicator_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(indicator_canvas)

	# Compact Main Tutorial Card Panel (~112px strip in top-right corner)
	main_panel = PanelContainer.new()
	main_panel.name = "TutorialCard"
	main_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	main_panel.anchor_left = 1.0
	main_panel.anchor_right = 1.0
	main_panel.anchor_top = 0.0
	main_panel.anchor_bottom = 0.0
	main_panel.offset_left = -460.0
	main_panel.offset_right = -16.0
	main_panel.offset_top = 10.0
	main_panel.offset_bottom = 124.0
	main_panel.custom_minimum_size = Vector2(444, 114)
	main_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.11, 0.14, 0.94)
	style.border_color = Color(0.25, 0.65, 0.60, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 10
	style.content_margin_top = 6
	style.content_margin_right = 10
	style.content_margin_bottom = 6
	main_panel.add_theme_stylebox_override("panel", style)
	root_control.add_child(main_panel)

	var v_box = VBoxContainer.new()
	v_box.add_theme_constant_override("separation", 3)
	main_panel.add_child(v_box)

	# Header: Step badge and Skip/Close
	var header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 6)
	v_box.add_child(header_row)

	step_badge_label = Label.new()
	step_badge_label.text = "STEP 1 OF 8 • BASIC CONTROLS"
	step_badge_label.add_theme_font_size_override("font_size", 10)
	step_badge_label.add_theme_color_override("font_color", Color("8cddf0"))
	step_badge_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(step_badge_label)

	skip_button = Button.new()
	skip_button.text = "✕"
	skip_button.tooltip_text = "Close tutorial (reopen anytime with [?] button)"
	skip_button.custom_minimum_size = Vector2(24, 18)
	skip_button.add_theme_font_size_override("font_size", 10)
	var skip_style = StyleBoxFlat.new()
	skip_style.bg_color = Color(0.22, 0.12, 0.12, 0.85)
	skip_style.set_corner_radius_all(3)
	skip_button.add_theme_stylebox_override("normal", skip_style)
	skip_button.pressed.connect(_on_skip_pressed)
	header_row.add_child(skip_button)

	# Step Title
	step_title_label = Label.new()
	step_title_label.text = "TACTICAL CAMERA & PERSPECTIVE"
	step_title_label.add_theme_font_size_override("font_size", 12)
	step_title_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	v_box.add_child(step_title_label)

	# Step Instructions
	step_text_label = Label.new()
	step_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	step_text_label.add_theme_font_size_override("font_size", 10)
	step_text_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	v_box.add_child(step_text_label)

	# Bottom Row: Navigation + Objective Status
	var bottom_row = HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 6)
	v_box.add_child(bottom_row)

	prev_button = Button.new()
	prev_button.text = "◀"
	prev_button.tooltip_text = "Previous step [P]"
	prev_button.custom_minimum_size = Vector2(28, 22)
	prev_button.add_theme_font_size_override("font_size", 10)
	prev_button.pressed.connect(_on_prev_pressed)
	bottom_row.add_child(prev_button)

	objective_icon_label = Label.new()
	objective_icon_label.text = "[ ○ ]"
	objective_icon_label.add_theme_font_size_override("font_size", 10)
	objective_icon_label.add_theme_color_override("font_color", Color("ffd166"))
	bottom_row.add_child(objective_icon_label)

	objective_text_label = Label.new()
	objective_text_label.text = "Objective in progress..."
	objective_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objective_text_label.clip_text = true
	objective_text_label.add_theme_font_size_override("font_size", 10)
	objective_text_label.add_theme_color_override("font_color", Color("ffd166"))
	bottom_row.add_child(objective_text_label)

	next_button = Button.new()
	next_button.text = "NEXT ▶"
	next_button.tooltip_text = "Advance to next step [N] or [Enter]"
	next_button.custom_minimum_size = Vector2(75, 22)
	next_button.add_theme_font_size_override("font_size", 10)
	var next_style = StyleBoxFlat.new()
	next_style.bg_color = Color("285e55")
	next_style.set_corner_radius_all(3)
	next_button.add_theme_stylebox_override("normal", next_style)
	next_button.pressed.connect(_on_next_pressed)
	bottom_row.add_child(next_button)

	# Discrete Reopen Button (visible when tutorial is minimized or finished)
	reopen_button = Button.new()
	reopen_button.name = "TutorialReopenButton"
	reopen_button.text = "? TUTORIAL"
	reopen_button.tooltip_text = "Open step-by-step interactive walkthrough"
	reopen_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	reopen_button.anchor_left = 1.0
	reopen_button.anchor_right = 1.0
	reopen_button.anchor_top = 0.0
	reopen_button.anchor_bottom = 0.0
	reopen_button.offset_left = -105.0
	reopen_button.offset_right = -15.0
	reopen_button.offset_top = 10.0
	reopen_button.offset_bottom = 32.0
	var reopen_style = StyleBoxFlat.new()
	reopen_style.bg_color = Color(0.12, 0.22, 0.20, 0.85)
	reopen_style.border_color = Color(0.3, 0.75, 0.6, 0.8)
	reopen_style.set_border_width_all(1)
	reopen_style.set_corner_radius_all(4)
	reopen_button.add_theme_stylebox_override("normal", reopen_style)
	reopen_button.add_theme_font_size_override("font_size", 11)
	reopen_button.add_theme_color_override("font_color", Color("8cddf0"))
	reopen_button.pressed.connect(_on_reopen_pressed)
	root_control.add_child(reopen_button)
	reopen_button.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not is_active: return
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_N or event.keycode == KEY_ENTER:
			_on_next_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_P:
			_on_prev_pressed()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not is_active: return
	
	step_elapsed += delta
	anim_phase += delta * 4.0
	
	_evaluate_step_objective(delta)
	_update_indicator_target()
	indicator_canvas.queue_redraw()

func _evaluate_step_objective(_delta: float) -> void:
	if objective_achieved:
		return

	if game == null: return
	var step = steps[current_step]
	var completed = false

	match step["id"]:
		"camera":
			var yaw_diff = abs(game.cam_yaw - baseline_cam_yaw)
			var pitch_diff = abs(game.cam_pitch - baseline_cam_pitch)
			var dist_diff = abs(game.cam_distance - baseline_cam_dist)
			if yaw_diff > 0.15 or pitch_diff > 0.15 or dist_diff > 5.0:
				completed = true

		"move":
			if game.travel_target != null:
				completed = true
			elif game.action_queue != null and _queue_has_kind(game.action_queue, "move"):
				completed = true
			elif game.player != null and game.player.orders.get("move", 0.0) != 0.0:
				completed = true

		"observe":
			if game.input_mode == "observe_sector":
				completed = true
			elif game.player != null and game.player.observers.has("Commander"):
				var cmd = game.player.observers["Commander"]
				if cmd.get("is_sector_assigned") == true or cmd.current_task in ["OBSERVING", "TRACKING"]:
					completed = true

		"execute":
			if game.phase == "EXECUTION":
				completed = true

		"contact":
			if game.player_track != null and game.player_track.has_contact():
				completed = true

		"gunner_sight":
			if game.view_mode == "GUNNER":
				completed = true

		"range_drum":
			if game.player != null and game.player.gunner_sight != null:
				var rng = game.player.gunner_sight.sight_range_m
				objective_text_label.text = "Dial range drum to ~1500m (Current: %dm)" % int(rng)
				if abs(rng - 1500.0) <= 200.0:
					completed = true

		"fire_shot":
			if game.action_queue != null and _queue_has_kind(game.action_queue, "fire"):
				completed = true
			elif game.player != null and game.player.orders.get("fire", false):
				completed = true

	if completed:
		_mark_objective_complete()

func _queue_has_kind(queue, kind: String) -> bool:
	if queue == null or not ("actions" in queue): return false
	for a in queue.actions:
		if a.get("kind", "") == kind:
			return true
	return false

func _mark_objective_complete() -> void:
	if objective_achieved: return
	objective_achieved = true
	objective_icon_label.text = "[ ✔ ]"
	objective_icon_label.add_theme_color_override("font_color", Color("77dd77"))
	objective_text_label.add_theme_color_override("font_color", Color("77dd77"))
	objective_text_label.text = "Objective Complete! [Click NEXT or press Enter]"
	next_button.add_theme_color_override("font_color", Color("77dd77"))
	var glow_style = StyleBoxFlat.new()
	glow_style.bg_color = Color(0.16, 0.44, 0.32, 0.95)
	glow_style.border_color = Color(0.4, 0.95, 0.65, 0.95)
	glow_style.set_border_width_all(2)
	glow_style.set_corner_radius_all(4)
	next_button.add_theme_stylebox_override("normal", glow_style)

func _update_indicator_target() -> void:
	target_has_position = false
	if game == null: return
	var step = steps[current_step]
	var tag = step.get("target_tag", "")
	var vp_size = root_control.get_viewport_rect().size

	match tag:
		"action_move":
			if game.contextual_buttons.size() > 0:
				var btn = game.contextual_buttons[0]
				if btn.is_visible_in_tree():
					current_target_screen_pos = btn.global_position + btn.size * 0.5
					target_has_position = true

		"action_observe":
			if game.contextual_buttons.size() > 1:
				var btn = game.contextual_buttons[1]
				if btn.is_visible_in_tree():
					current_target_screen_pos = btn.global_position + btn.size * 0.5
					target_has_position = true

		"execute_button":
			if game.execute_button != null and game.execute_button.is_visible_in_tree():
				current_target_screen_pos = game.execute_button.global_position + game.execute_button.size * 0.5
				target_has_position = true

		"action_gunner":
			if game.view_mode == "TACTICAL" and game.contextual_buttons.size() > 0:
				for btn in game.contextual_buttons:
					if btn.text.contains("GUNNER"):
						current_target_screen_pos = btn.global_position + btn.size * 0.5
						target_has_position = true
						break

		"range_drum":
			if game.view_mode == "GUNNER":
				current_target_screen_pos = Vector2(vp_size.x - 90.0, vp_size.y - 35.0)
				target_has_position = true

		"reticle_center":
			if game.view_mode == "GUNNER":
				current_target_screen_pos = vp_size * 0.5
				target_has_position = true

		"player_tank":
			if game.camera != null and is_instance_valid(game.player):
				if not game.camera.is_position_behind(game.player.position):
					current_target_screen_pos = game.camera.unproject_position(game.player.position + Vector3(0, 1.5, 0))
					target_has_position = true

func _update_step_ui() -> void:
	if current_step < 0 or current_step >= steps.size():
		_finish_tutorial()
		return

	var step = steps[current_step]
	step_badge_label.text = step["badge"]
	step_title_label.text = step["title"]
	step_text_label.text = step["text"]
	objective_text_label.text = step["objective"]

	objective_achieved = false
	objective_icon_label.text = "[ ○ ]"
	objective_icon_label.add_theme_color_override("font_color", Color("ffd166"))
	objective_text_label.add_theme_color_override("font_color", Color("ffd166"))
	next_button.add_theme_color_override("font_color", Color.WHITE)
	var default_style = StyleBoxFlat.new()
	default_style.bg_color = Color("285e55")
	default_style.set_corner_radius_all(4)
	next_button.add_theme_stylebox_override("normal", default_style)

	prev_button.visible = current_step > 0
	if current_step == steps.size() - 1:
		next_button.text = "FINISH TUTORIAL ✔"
	else:
		next_button.text = "NEXT ▶"

	step_elapsed = 0.0

func _on_next_pressed() -> void:
	if current_step >= steps.size() - 1:
		_finish_tutorial()
	else:
		current_step += 1
		_update_step_ui()

func _on_prev_pressed() -> void:
	if current_step > 0:
		current_step -= 1
		_update_step_ui()

func _on_skip_pressed() -> void:
	is_active = false
	main_panel.visible = false
	reopen_button.visible = true
	indicator_canvas.queue_redraw()
	if game != null:
		game._event("Interactive tutorial minimized. Click [? TUTORIAL] in top right to reopen.")

func _on_reopen_pressed() -> void:
	is_active = true
	main_panel.visible = true
	reopen_button.visible = false
	if current_step >= steps.size() - 1:
		current_step = 0
	_record_cam_baseline()
	_update_step_ui()

func restart_tutorial() -> void:
	current_step = 0
	is_active = true
	main_panel.visible = true
	reopen_button.visible = false
	_record_cam_baseline()
	_update_step_ui()

func _finish_tutorial() -> void:
	is_active = false
	main_panel.visible = false
	reopen_button.visible = true
	indicator_canvas.queue_redraw()
	if game != null:
		game._event("Tutorial complete! You are cleared for tactical combat. Good hunting.")

## Internal helper class for drawing animated beacon/arrow indicators
class TutorialIndicatorCanvas extends Control:
	var tut: InteractiveTutorial
	
	func _init(p_tut: InteractiveTutorial) -> void:
		tut = p_tut
		
	func _draw() -> void:
		if tut == null or not tut.is_active or not tut.target_has_position:
			return
		
		var pos = tut.current_target_screen_pos
		var pulse = sin(tut.anim_phase) * 0.5 + 0.5
		var ring_radius = 24.0 + pulse * 10.0
		var ring_color = Color(0.2, 0.95, 0.65, 0.45 + pulse * 0.45)
		
		# Pulsing glow rings around target
		draw_arc(pos, ring_radius, 0, TAU, 32, ring_color, 2.5, true)
		draw_arc(pos, ring_radius * 0.6, 0, TAU, 24, Color(1.0, 0.85, 0.3, 0.7), 1.5, true)
		
		# Directional pointing chevron
		var arrow_offset = 38.0 + pulse * 6.0
		var arrow_tip = pos + Vector2(0, -arrow_offset)
		var left_fin = arrow_tip + Vector2(-9, -12)
		var right_fin = arrow_tip + Vector2(9, -12)
		draw_line(left_fin, arrow_tip, Color("ffd166"), 3.0, true)
		draw_line(right_fin, arrow_tip, Color("ffd166"), 3.0, true)
