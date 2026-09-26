extends Node3D
const Vehicle = preload("res://scripts/wego/TacticalVehicle.gd")
const Viewer = preload("res://scripts/wego/ShotViewer.gd")
const Overlay = preload("res://scripts/wego/BattlefieldOverlay.gd")
const Playback = preload("res://scripts/wego/CombatPlayback.gd")
const Actions = preload("res://scripts/wego/ActionQueue.gd")
const Damage = preload("res://scripts/wego/DamageReport.gd")
const Armor = preload("res://scripts/wego/ArmorModel.gd")

const ContactTrack = preload("res://scripts/wego/ContactTrack.gd")
const Observation = preload("res://scripts/wego/Observation.gd")
const SensorModel = preload("res://scripts/wego/SensorModel.gd")
const FiringSolution = preload("res://scripts/wego/FiringSolution.gd")
const CrewDoctrine = preload("res://scripts/wego/CrewDoctrine.gd")
const WegoTimeline = preload("res://scripts/wego/WegoTimeline.gd")
const MASTODON_SCENE = preload("res://scenes/tank/A47_Mastodon_Player.tscn")
const CombatEffects = preload("res://scripts/wego/CombatEffects.gd")
const WorldPlanningGraphics = preload("res://scripts/wego/WorldPlanningGraphics.gd")

var world_graphics: WorldPlanningGraphics
var ghost_tank: A47_Mastodon_Vehicle

# 3D Tactical Perspective Camera
var cam_target: Vector3 = Vector3(-175, 0, 110)
var cam_yaw: float = deg_to_rad(-65.0)
var cam_pitch: float = deg_to_rad(-40.0)
var cam_distance: float = 46.0
var cam_fov: float = 58.0
var cam_shake: float = 0.0
var is_orbiting: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO

# Collapsible Drawers & HUD Controls
var left_drawer: Control
var right_drawer: Control
var radio_callout_label: Label
var radio_callout_timer: float = 0.0
var contact_summary_btn: Button
var tank_card_label: Label
var drawer_orders_btn: Button
var drawer_crew_btn: Button
var drawer_intel_btn: Button
var drawer_shots_btn: Button

var player
var enemy
var camera: Camera3D
var phase = "PLANNING"
var turn = 1
var active_tank = null
var time_left = 8.0
var sim_time = 0.0
var sense_timer = 0.0
var shells: Array = []
var records: Array = []
var rng = RandomNumberGenerator.new()

var timeline = null
var sensor_model = null
var player_track = null
var enemy_track = null
var player_firing_solution = null
var debug_overlay_enabled: bool = false
var recent_gunfire_time: float = -999.0
var recent_hit_time: float = -999.0
var player_was_hit_this_pulse: bool = false
var enemy_was_hit_this_pulse: bool = false
var pulse_mode_label: Label
var sop_contact_choice: OptionButton
var sop_fired_choice: OptionButton
var sop_fire_auth_choice: OptionButton

var status_label: Label
var contact_label: Label
var crew_label: Label
var report: Label
var execute_button: Button
var viewer
var fields: Dictionary = {}
var controls: Array = []
var display_contact: Dictionary = {}
var contact_visual_position = Vector3.ZERO
var contact_visual_radius = 22.0
var travel_target: Variant = null
var aim_target: Variant = null
var aim_selected = false
var input_mode = "select"
var updating_fields = false
var action_hint: Label
var order_summary: Label
var movement_button: Button
var fire_button: Button
var scan_button: Button
var contact_fire_button: Button
var cancel_button: Button
var execution_progress: ProgressBar
var detail_tabs: TabBar
var help_box: VBoxContainer
var phase_report = "Choose an action, then EXECUTE."
var ui_time = 0.0
var playback = Playback.new()
var shot_events: Array[Dictionary] = []
var turn_events: Array[Dictionary] = []
var shot_serial = 0
var turn_start_time = 0.0
var turn_start_position = Vector3.ZERO
var shot_clock = 0.0
var pause_button: Button
var speed_choice: OptionButton
var impact_panel: Control
var impact_viewer
var impact_title: Label
var impact_stage: Label
var impact_effects: Label
var impact_progress: ProgressBar
var turn_report: Label
var turn_shot_buttons: VBoxContainer
var map_scripts: Array[Node] = []
var map_particles: Array[GPUParticles3D] = []
var map_audio: Array[AudioStreamPlayer3D] = []
var order_notice = ""
var selected_record: OptionButton
var event_log: Label
var log_lines: Array[String] = []
var zoom = 115.0
var ammo_choice: OptionButton
var loadout_locked = false
var action_queue = Actions.new()
var queue_scroll: ScrollContainer
var queue_rows: VBoxContainer
var queue_widgets: Array[Dictionary] = []
var budget_label: Label
var reload_label: Label
var aim_button: Button
var hull_button: Button
var stop_button: Button
var wait_button: Button
var reload_button: Button
var next_action_limit: SpinBox
var impact_systems: Label
var impact_continue: Button
var using_queue = false

func _ready() -> void:
	rng.seed = 94217
	timeline = WegoTimeline.new()
	player_track = ContactTrack.new("CONTACT_A")
	enemy_track = ContactTrack.new("PLAYER_TANK")
	sensor_model = SensorModel.new(rng)
	player = Vehicle.new()
	player.name = "Your tank"
	player.position = Vector3(-185, 0, 110)
	player.rotation.y = -PI / 2
	player.doctrine = CrewDoctrine.new()
	player.track = player_track
	add_child(player)
	
	enemy = Vehicle.new()
	enemy.name = "Contact A"
	enemy.position = Vector3(-110, 0, 110)
	enemy.rotation.y = PI / 2
	enemy.color = Color("736752")
	enemy.doctrine = CrewDoctrine.new()
	enemy.track = enemy_track
	add_child(enemy)
	
	# Initialize 3D World Planning Graphics
	world_graphics = WorldPlanningGraphics.new()
	add_child(world_graphics)

	# Initialize 3D Ghost Tank for reconnaissance
	ghost_tank = MASTODON_SCENE.instantiate()
	add_child(ghost_tank)
	ghost_tank.visible = false
	_apply_ghost_material(ghost_tank)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = cam_fov
	add_child(camera)
	camera.current = true
	_update_camera(0.0)
	_build_ui()
	_set_map_running(false)
	
	# Initial contact tracks set up from reconnaissance briefing
	player_track.estimated_position = Vector3(-108, 0, 105)
	player_track.last_observed_position = player_track.estimated_position
	player_track.position_uncertainty = 35.0
	player_track.range_uncertainty = 35.0
	player_track.estimated_range = player.position.distance_to(player_track.estimated_position)
	player_track.estimated_bearing_deg = 90.0
	player_track.last_observation_time = 0.0
	player_track.sources = ["Briefing / unconfirmed"]
	player.contact = player_track.to_dict()
	
	enemy_track.estimated_position = Vector3(-180, 0, 120)
	enemy_track.last_observed_position = enemy_track.estimated_position
	enemy_track.position_uncertainty = 35.0
	enemy_track.range_uncertainty = 35.0
	enemy_track.estimated_range = enemy.position.distance_to(enemy_track.estimated_position)
	enemy_track.estimated_bearing_deg = 270.0
	enemy_track.last_observation_time = 0.0
	enemy_track.sources = ["Briefing"]
	enemy.contact = enemy_track.to_dict()
	
	player_firing_solution = FiringSolution.calculate(player, player_track, rng)
	_publish_contact()
	contact_visual_position = display_contact.position
	_log("Systems operational. Tactical WEGO initialized.")

func _apply_ghost_material(tank: A47_Mastodon_Vehicle) -> void:
	if tank == null or tank.visual == null: return
	var ghost_mat = StandardMaterial3D.new()
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.albedo_color = Color(0.92, 0.72, 0.28, 0.38)
	ghost_mat.emission_enabled = true
	ghost_mat.emission = Color(0.92, 0.65, 0.20)
	ghost_mat.emission_energy_multiplier = 0.75
	ghost_mat.cull_mode = BaseMaterial3D.CULL_BACK
	for arm_node in tank.visual.nodes_by_category["ARM"]:
		if arm_node is MeshInstance3D:
			arm_node.material_override = ghost_mat
	for cmp_node in tank.visual.nodes_by_category["CMP"]:
		if cmp_node is MeshInstance3D:
			cmp_node.material_override = ghost_mat

func _update_camera(delta: float) -> void:
	if not is_instance_valid(player) or camera == null: return
	
	if delta > 0.0:
		if phase == "EXECUTION":
			var target_pitch = deg_to_rad(-28.0)
			var target_dist = 28.0
			if not is_orbiting:
				cam_pitch = lerpf(cam_pitch, target_pitch, delta * 2.0)
				cam_distance = lerpf(cam_distance, target_dist, delta * 2.0)
			var combat_midpoint = player.position.lerp(enemy.position, 0.35)
			cam_target = cam_target.lerp(combat_midpoint, delta * 3.0)
		else:
			if not is_orbiting:
				cam_target = cam_target.lerp(player.position + Vector3(6, 0, 0), delta * 4.0)
	elif not is_orbiting:
		cam_target = player.position + Vector3(6, 0, 0)

	var shake_offset = Vector3.ZERO
	if cam_shake > 0.0:
		shake_offset = Vector3(
			sin(ui_time * 53.0) * cam_shake,
			cos(ui_time * 41.0) * cam_shake * 0.5,
			sin(ui_time * 67.0) * cam_shake
		)
		cam_shake = maxf(0.0, cam_shake - delta * 3.0)

	var rot_quat = Quaternion.from_euler(Vector3(cam_pitch, cam_yaw, 0.0))
	var offset = rot_quat * Vector3(0, 0, cam_distance)
	camera.position = cam_target + offset + shake_offset
	camera.look_at(cam_target + Vector3(0, 1.4, 0))

func _callout(speaker: String, text_val: String) -> void:
	if radio_callout_label != null:
		radio_callout_label.text = "[RADIO] %s: \"%s\"" % [speaker.to_upper(), text_val]
		radio_callout_timer = 3.5
		radio_callout_label.visible = true
	_log("%s: %s" % [speaker, text_val])

func _set_map_running(enabled: bool) -> void:
	map_scripts.clear()
	map_particles.clear()
	map_audio.clear()
	var pending: Array[Node] = [$MapBuilder]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		node.set_process(false)
		node.set_physics_process(false)
		if node.get_script() != null and node.has_method("_process"): map_scripts.append(node)
		if node is GPUParticles3D: map_particles.append(node)
		if node is AudioStreamPlayer3D: map_audio.append(node)
		pending.append_array(node.get_children())
	_world_playback_rate(playback.rate() if enabled else 0.0)

func _world_playback_rate(rate: float) -> void:
	for particles in map_particles: particles.speed_scale = rate
	for audio_player in map_audio: audio_player.stream_paused = rate <= 0

func _panel(parent: Control, left: float, top: float, right: float, bottom: float) -> VBoxContainer:
	var panel = PanelContainer.new()
	parent.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.anchor_left = left
	panel.anchor_top = top
	panel.anchor_right = right
	panel.anchor_bottom = bottom
	panel.offset_left = 6
	panel.offset_top = 6
	panel.offset_right = -6
	panel.offset_bottom = -6
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.04, 0.06, 0.72)
	style.border_color = Color(0.25, 0.38, 0.45, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	box.add_theme_constant_override("separation", 7)
	return box

func _hud_bar(parent: Control, left: float, top: float, right: float, bottom: float) -> VBoxContainer:
	var panel = PanelContainer.new()
	parent.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.anchor_left = left
	panel.anchor_top = top
	panel.anchor_right = right
	panel.anchor_bottom = bottom
	panel.offset_left = 6
	panel.offset_top = 6
	panel.offset_right = -6
	panel.offset_bottom = -6
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.04, 0.06, 0.78)
	style.border_color = Color(0.25, 0.38, 0.45, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	return box

func _label(parent: Node, text_value: String, font_size = 15) -> Label:
	var label = Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _spin(parent: Node, label: String, key: String, low: float, high: float, initial: float, increment = 1.0) -> void:
	var row = HBoxContainer.new()
	parent.add_child(row)
	var title = _label(row, label)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var spin = SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = increment
	spin.value = initial
	spin.custom_minimum_size.x = 115
	row.add_child(spin)
	fields[key] = spin
	controls.append(spin)

func _check(parent: Node, label: String, key: String, initial = false) -> void:
	var button = CheckBox.new()
	button.text = label
	button.button_pressed = initial
	parent.add_child(button)
	fields[key] = button
	controls.append(button)

func _button(parent: Node, caption: String, callback: Callable, height = 38) -> Button:
	var button = Button.new()
	button.text = caption
	button.custom_minimum_size.y = height
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)
	controls.append(button)
	return button

func _build_ui() -> void:
	var layer = CanvasLayer.new()
	add_child(layer)
	var root = Control.new()
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var overlay = Overlay.new()
	overlay.game = self
	root.add_child(overlay)
	var left = _panel(root, 0, 0, 0.22, 1.0)
	left_drawer = left.get_parent().get_parent()
	var left_header = HBoxContainer.new()
	left.add_child(left_header)
	var left_title = _label(left_header, "ORDERS", 18)
	left_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var left_close = Button.new()
	left_close.text = "◀"
	left_close.tooltip_text = "Collapse Orders Drawer [TAB]"
	left_close.custom_minimum_size = Vector2(28, 26)
	left_close.pressed.connect(func(): left_drawer.visible = false)
	left_header.add_child(left_close)
	pulse_mode_label = _label(left, "MANEUVER MODE (8.0s pulse)", 12)
	pulse_mode_label.add_theme_color_override("font_color", Color("8cddf0"))
	status_label = _label(left, "", 13)
	var actions = HBoxContainer.new()
	left.add_child(actions)
	movement_button = _button(actions, "MOVE", func(): _set_mode("move"), 38)
	fire_button = _button(actions, "AIM & FIRE", func(): _set_mode("fire"), 38)
	movement_button.toggle_mode = true
	fire_button.toggle_mode = true
	movement_button.tooltip_text = "Click MOVE, then click clear ground."
	fire_button.tooltip_text = "Append an aim-and-fire action."
	var orientation = HBoxContainer.new()
	left.add_child(orientation)
	aim_button = _button(orientation, "AIM TURRET", func(): _set_mode("aim"), 30)
	hull_button = _button(orientation, "TURN HULL", func(): _set_mode("hull"), 30)
	aim_button.tooltip_text = "Rotate turret only."
	aim_button.toggle_mode = true
	hull_button.toggle_mode = true
	hull_button.tooltip_text = "Pivot hull only."
	var utility = HBoxContainer.new()
	left.add_child(utility)
	reload_button = _button(utility, "RELOAD", func(): _append_action("reload", player.position), 28)
	wait_button = _button(utility, "WAIT 1s", func(): _append_action("wait", player.position, 1.0), 28)
	scan_button = _button(left, "SCAN FOR ENEMY", _queue_scan, 30)
	scan_button.tooltip_text = "Stop and sweep searchlight for 2s."
	var edits = HBoxContainer.new()
	left.add_child(edits)
	stop_button = _button(edits, "STOP / EDIT", _stop_and_edit, 28)
	controls.erase(stop_button)
	cancel_button = _button(edits, "CLEAR ALL", _clear_orders, 28)
	_label(left, "QUEUE", 13)
	queue_scroll = ScrollContainer.new()
	queue_scroll.custom_minimum_size.y = 100
	queue_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(queue_scroll)
	queue_rows = VBoxContainer.new()
	queue_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue_scroll.add_child(queue_rows)
	var limit_row = HBoxContainer.new()
	left.add_child(limit_row)
	var limit_caption = _label(limit_row, "Next limit / s", 12)
	limit_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_action_limit = SpinBox.new()
	next_action_limit.min_value = 0
	next_action_limit.max_value = 5
	next_action_limit.step = 0.25
	next_action_limit.tooltip_text = "0 = until finished. Set a limit for a short action."
	limit_row.add_child(next_action_limit)
	controls.append(next_action_limit)
	budget_label = _label(left, "", 12)
	reload_label = _label(left, "", 12)
	order_summary = _label(left, "", 12)
	var advanced = VBoxContainer.new()
	var advanced_toggle = _button(left, "Advanced orders  ▸", func(): advanced.visible = not advanced.visible, 26)
	left.add_child(advanced)
	advanced.visible = false
	_spin(advanced, "Travel / m", "move", -15, 35, 0)
	_spin(advanced, "Hull pivot / °", "pivot", -180, 180, 0)
	_spin(advanced, "Bearing / °", "bearing", 0, 359, 90)
	_spin(advanced, "Range / m", "range", 10, 500, 75)
	_spin(advanced, "Aim height / m", "height", 0.4, 3.2, 1.4, 0.1)
	_check(advanced, "Queue one shot", "fire")
	_check(advanced, "Engine running", "engine", true)
	_check(advanced, "Creep speed", "creep")
	_check(advanced, "Observe aiming sector", "observe", true)
	_check(advanced, "Searchlight / 2 seconds", "light")
	_check(advanced, "Loader fights fire", "extinguish")
	for key in ["move", "pivot"]:
		fields[key].value_changed.connect(func(_v):
			if not updating_fields: travel_target = null)
	for key in ["bearing", "range"]:
		fields[key].value_changed.connect(func(_v):
			if not updating_fields:
				aim_target = null
				aim_selected = true)
	_label(advanced, "Loadout (turn 1)")
	ammo_choice = OptionButton.new()
	ammo_choice.clip_text = true
	ammo_choice.fit_to_longest_item = false
	ammo_choice.add_item("25 rounds / protected storage")
	ammo_choice.add_item("40 rounds / overflow rack filled")
	advanced.add_child(ammo_choice)
	
	_label(advanced, "CREW DOCTRINE (SOP)", 13)
	_label(advanced, "On Contact:", 11)
	sop_contact_choice = OptionButton.new()
	sop_contact_choice.add_item("Halt & Track Target")
	sop_contact_choice.add_item("Continue & Track")
	sop_contact_choice.add_item("Reverse to Cover")
	sop_contact_choice.add_item("Hold Current Orders")
	sop_contact_choice.add_item("Remain Concealed")
	sop_contact_choice.item_selected.connect(func(idx):
		if player != null and player.doctrine != null:
			player.doctrine.on_contact = idx as CrewDoctrine.ContactReaction)
	advanced.add_child(sop_contact_choice)
	controls.append(sop_contact_choice)
	
	_label(advanced, "When Fired Upon:", 11)
	sop_fired_choice = OptionButton.new()
	sop_fired_choice.add_item("Halt Immediately")
	sop_fired_choice.add_item("Reverse Away")
	sop_fired_choice.add_item("Seek Cover")
	sop_fired_choice.add_item("Continue Orders")
	sop_fired_choice.item_selected.connect(func(idx):
		if player != null and player.doctrine != null:
			player.doctrine.on_fired_upon = idx as CrewDoctrine.FiredUponReaction)
	advanced.add_child(sop_fired_choice)
	controls.append(sop_fired_choice)
	
	_label(advanced, "Fire Authority:", 11)
	sop_fire_auth_choice = OptionButton.new()
	sop_fire_auth_choice.add_item("Hold Fire (Player Order Only)")
	sop_fire_auth_choice.add_item("Confirmed Hostile Only")
	sop_fire_auth_choice.add_item("Fire When Solution Ready")
	sop_fire_auth_choice.add_item("Return Fire When Attacked")
	sop_fire_auth_choice.item_selected.connect(func(idx):
		if player != null and player.doctrine != null:
			player.doctrine.fire_authority = idx as CrewDoctrine.FireAuthority)
	advanced.add_child(sop_fire_auth_choice)
	controls.append(sop_fire_auth_choice)
	_button(left, "Restart engagement", func(): get_tree().reload_current_scene(), 26)
	controls.pop_back()
	controls.erase(advanced_toggle)
	var right = _panel(root, 0.78, 0, 1.0, 1.0)
	right_drawer = right.get_parent().get_parent()
	var right_header = HBoxContainer.new()
	right.add_child(right_header)
	var right_title = _label(right_header, "INTELLIGENCE", 18)
	right_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right_close = Button.new()
	right_close.text = "▶"
	right_close.tooltip_text = "Collapse Intelligence Drawer"
	right_close.custom_minimum_size = Vector2(28, 26)
	right_close.pressed.connect(func(): right_drawer.visible = false)
	right_header.add_child(right_close)
	contact_label = _label(right, "", 12)
	contact_fire_button = _button(right, "FIRE AT ESTIMATE", _queue_contact_fire, 32)
	contact_fire_button.tooltip_text = "Queue a shot at the marked estimate."
	detail_tabs = TabBar.new()
	detail_tabs.add_theme_font_size_override("font_size", 12)
	for title in ["HELP", "SHOT", "CREW", "TURN"]: detail_tabs.add_tab(title)
	right.add_child(detail_tabs)
	help_box = VBoxContainer.new()
	var shot_box = VBoxContainer.new()
	var crew_box = VBoxContainer.new()
	var turn_box = VBoxContainer.new()
	for box in [help_box, shot_box, crew_box, turn_box]: right.add_child(box)
	shot_box.visible = false
	crew_box.visible = false
	turn_box.visible = false
	detail_tabs.tab_changed.connect(func(index):
		help_box.visible = index == 0
		shot_box.visible = index == 1
		crew_box.visible = index == 2
		turn_box.visible = index == 3)
	_label(turn_box, "TURN SUMMARY", 15)
	turn_report = _label(turn_box, "Ready for orders.", 13)
	turn_shot_buttons = VBoxContainer.new()
	turn_box.add_child(turn_shot_buttons)
	turn_box.move_child(turn_shot_buttons, 1)
	viewer = Viewer.new()
	viewer.custom_minimum_size = Vector2(230, 160)
	shot_box.add_child(viewer)
	_label(shot_box, "Replay: click / Orbit: right-drag", 11)
	selected_record = OptionButton.new()
	selected_record.clip_text = true
	selected_record.fit_to_longest_item = false
	selected_record.add_item("No armor impacts recorded")
	selected_record.item_selected.connect(func(index):
		if index < records.size(): _show_record(records[index]))
	shot_box.add_child(selected_record)
	report = _label(shot_box, "Fire a shot to see damage report.", 12)
	_label(crew_box, "CREW STATUS", 15)
	crew_label = _label(crew_box, "", 12)
	var person = OptionButton.new()
	for c in player.model.crew: person.add_item(c.name)
	crew_box.add_child(person)
	var station = OptionButton.new()
	for c in player.model.crew: station.add_item(c.station)
	crew_box.add_child(station)
	_button(crew_box, "Transfer crew / 10s", func():
		if phase not in ["EXECUTION", "COMPLETE"]:
			if player.model.reassign(person.selected, station.get_item_text(station.selected)): _log("Crew transfer started.")
			else: _log("Transfer unavailable."))
	_label(help_box, "TACTICAL GUIDE", 15)
	_label(help_box, "• MOVE: Click ground to set waypoint.\n• AIM & FIRE: Click enemy or ground to target.\n• SCAN: 2s searchlight sweep.\n• EXECUTE: Runs 5s turn simultaneously.\n• Mouse wheel: Zoom in/out.", 12)
	var hint_box = _hud_bar(root, 0.28, 0, 0.72, 0.08)
	var playback_row = HBoxContainer.new()
	playback_row.alignment = BoxContainer.ALIGNMENT_CENTER
	playback_row.add_theme_constant_override("separation", 10)
	hint_box.add_child(playback_row)
	execute_button = _button(playback_row, "EXECUTE ORDERS  ▶", _execute, 28)
	var execute_style = StyleBoxFlat.new()
	execute_style.bg_color = Color("285e55")
	execute_style.set_corner_radius_all(4)
	execute_button.add_theme_stylebox_override("normal", execute_style)
	execute_button.add_theme_font_size_override("font_size", 12)
	pause_button = _button(playback_row, "PAUSE", _toggle_playback_pause, 28)
	pause_button.add_theme_font_size_override("font_size", 12)
	controls.erase(pause_button)
	speed_choice = OptionButton.new()
	for caption in ["¼x", "½x", "1x"]: speed_choice.add_item(caption)
	speed_choice.select(1)
	speed_choice.item_selected.connect(func(index): playback.speed = [0.25, 0.5, 1.0][index])
	playback_row.add_child(speed_choice)
	execution_progress = ProgressBar.new()
	execution_progress.max_value = 5
	execution_progress.show_percentage = false
	execution_progress.custom_minimum_size.y = 3
	hint_box.add_child(execution_progress)
	action_hint = _label(hint_box, "", 11)
	action_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var impact_box = _panel(root, 0.23, 0.10, 0.77, 0.90)
	impact_panel = impact_box.get_parent().get_parent()
	var impact_style = impact_panel.get_theme_stylebox("panel").duplicate()
	impact_style.bg_color = Color("0d181f")
	impact_panel.add_theme_stylebox_override("panel", impact_style)
	var impact_scroll = impact_box.get_parent()
	var impact_frame = VBoxContainer.new()
	impact_panel.remove_child(impact_scroll)
	impact_panel.add_child(impact_frame)
	impact_frame.add_child(impact_scroll)
	impact_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	impact_title = _label(impact_box, "", 18)
	var impact_columns = HBoxContainer.new()
	impact_columns.add_theme_constant_override("separation", 16)
	impact_box.add_child(impact_columns)
	var animation_column = VBoxContainer.new()
	animation_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	impact_columns.add_child(animation_column)
	impact_viewer = Viewer.new()
	impact_viewer.custom_minimum_size = Vector2(260, 240)
	animation_column.add_child(impact_viewer)
	impact_systems = _label(animation_column, "", 13)
	var damage_column = VBoxContainer.new()
	damage_column.custom_minimum_size.x = 240
	damage_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	impact_columns.add_child(damage_column)
	_label(damage_column, "DAMAGE ASSESSMENT", 16)
	impact_stage = _label(damage_column, "", 14)
	impact_effects = _label(damage_column, "", 13)
	impact_effects.custom_minimum_size.y = 30
	impact_progress = ProgressBar.new()
	impact_progress.max_value = Playback.IMPACT_DURATION
	impact_progress.show_percentage = false
	impact_progress.custom_minimum_size.y = 5
	impact_frame.add_child(impact_progress)
	var replay_buttons = HBoxContainer.new()
	impact_frame.add_child(replay_buttons)
	var retry = _button(replay_buttons, "REPLAY SHOT", func(): playback.restart_replay(), 30)
	impact_continue = _button(replay_buttons, "SHOW DAMAGE  ▶", _continue_impact, 34)
	controls.erase(retry)
	controls.erase(impact_continue)
	impact_panel.visible = false
	var footer = _hud_bar(root, 0.24, 0.94, 0.76, 1.0)
	event_log = _label(footer, "", 12)
	event_log.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Radio Transmission Callout HUD Banner (Top Center)
	var radio_panel = PanelContainer.new()
	root.add_child(radio_panel)
	radio_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	radio_panel.anchor_left = 0.28
	radio_panel.anchor_right = 0.72
	radio_panel.anchor_top = 0.088
	radio_panel.anchor_bottom = 0.138
	radio_panel.offset_left = 6
	radio_panel.offset_top = 4
	radio_panel.offset_right = -6
	radio_panel.offset_bottom = -4
	var r_style = StyleBoxFlat.new()
	r_style.bg_color = Color(0.04, 0.08, 0.06, 0.88)
	r_style.border_color = Color(0.3, 0.85, 0.45, 0.85)
	r_style.set_border_width_all(1)
	r_style.set_corner_radius_all(4)
	radio_panel.add_theme_stylebox_override("panel", r_style)
	radio_callout_label = Label.new()
	radio_callout_label.add_theme_font_size_override("font_size", 12)
	radio_callout_label.add_theme_color_override("font_color", Color("77dd77"))
	radio_callout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	radio_callout_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	radio_panel.add_child(radio_callout_label)
	radio_panel.visible = false

	# Bottom-left persistent Tank Card
	var tank_card_box = _hud_bar(root, 0.01, 0.88, 0.23, 0.99)
	tank_card_label = _label(tank_card_box, "A-47 MASTODON • OPERATIONAL\nAMMO: 25/25 AP • SPEED: 0.0 m/s\nSYSTEMS STABLE", 11)
	tank_card_label.add_theme_color_override("font_color", Color("8cddf0"))

	# Bottom-right HUD Toolbar for quick drawer toggles
	var toolbar_box = _hud_bar(root, 0.77, 0.94, 0.99, 1.0)
	var toolbar_row = HBoxContainer.new()
	toolbar_box.add_child(toolbar_row)
	drawer_orders_btn = _button(toolbar_row, "ORDERS", func(): left_drawer.visible = not left_drawer.visible, 24)
	drawer_crew_btn = _button(toolbar_row, "CREW", func():
		right_drawer.visible = true
		detail_tabs.current_tab = 2, 24)
	drawer_intel_btn = _button(toolbar_row, "INTEL", func():
		right_drawer.visible = true
		detail_tabs.current_tab = 0, 24)
	drawer_shots_btn = _button(toolbar_row, "SHOTS", func():
		right_drawer.visible = true
		detail_tabs.current_tab = 1, 24)

func _can_edit_orders() -> bool:
	return phase not in ["EXECUTION", "COMPLETE"] or (phase == "EXECUTION" and time_left > 0.0001 and playback.paused and not playback.busy())

func _set_order_controls(enabled: bool) -> void:
	for control in controls:
		if control is SpinBox: control.editable = enabled
		elif control is BaseButton: control.disabled = not enabled
	for row in queue_widgets:
		row.cancel.disabled = not enabled
		row.limit.editable = enabled

func _stop_and_edit() -> void:
	if phase != "EXECUTION" or playback.busy() or time_left <= 0.0001: return
	playback.paused = true
	playback.accumulator = 0.0
	_world_playback_rate(0)
	_set_order_controls(true)
	order_notice = "Turn paused. Cancel the current action with ×, add orders, then RESUME."

func _append_action(kind: String, point: Vector3, limit_override: float = -1) -> void:
	if not _can_edit_orders(): return
	action_queue.append(kind, point, next_action_limit.value if limit_override < 0 else limit_override, fields.creep.button_pressed)
	using_queue = true
	_sync_queue_markers()
	_rebuild_queue()
	order_notice = Actions.TITLES[kind] + " added. Review its time estimate in the queue."

func _cancel_action(index: int) -> void:
	if not _can_edit_orders() or index < 0 or index >= action_queue.actions.size(): return
	var title: String = Actions.TITLES[action_queue.actions[index].kind]
	action_queue.actions.remove_at(index)
	if index == 0:
		action_queue.running = false
		if phase == "EXECUTION": player.commit(Actions.hold_plan(player))
	_sync_queue_markers()
	_rebuild_queue()
	order_notice = title + " cancelled. Spent time and fired shells are unchanged."

func _sync_queue_markers() -> void:
	travel_target = null
	fields.fire.button_pressed = false
	fields.light.button_pressed = false
	for action in action_queue.actions:
		if action.kind == "move" and travel_target == null: travel_target = action.point
		if action.kind == "fire": fields.fire.button_pressed = true
		if action.kind == "scan": fields.light.button_pressed = true
		if action.kind in ["fire", "aim", "scan"]:
			_aim_at(Vector3(action.point.x, 0, action.point.z))
			break

func _rebuild_queue() -> void:
	if queue_rows == null: return
	for child in queue_rows.get_children():
		queue_rows.remove_child(child)
		child.queue_free()
	queue_widgets.clear()
	queue_scroll.visible = not action_queue.actions.is_empty()
	for i in range(action_queue.actions.size()):
		var action = action_queue.actions[i]
		var row = HBoxContainer.new()
		queue_rows.add_child(row)
		var label = _label(row, "", 13)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var limit = SpinBox.new()
		limit.min_value = 0
		limit.max_value = maxf(5, action.spent)
		limit.step = 0.25
		limit.value = action.limit
		limit.custom_minimum_size.x = 68
		limit.tooltip_text = "Action time limit in seconds, including time already spent. 0 = until done."
		row.add_child(limit)
		limit.value_changed.connect(func(value):
			if _can_edit_orders(): action.limit = value)
		var cancel = Button.new()
		cancel.text = "×"
		cancel.tooltip_text = "Cancel this action"
		cancel.custom_minimum_size = Vector2(28, 32)
		row.add_child(cancel)
		cancel.pressed.connect(func(): _cancel_action(i))
		queue_widgets.append({"label": label, "limit": limit, "cancel": cancel})
	_refresh_queue()

func _refresh_queue() -> void:
	if budget_label == null: return
	queue_scroll.visible = not action_queue.actions.is_empty()
	var budget = time_left if phase == "EXECUTION" else (timeline.pulse_duration if timeline else 5.0)
	var estimates = action_queue.estimates(player)
	var total: float = estimates.back().end if not estimates.is_empty() else 0.0
	var committed = minf(total, budget)
	budget_label.text = "Budget: %.1fs (Queued: %.1fs)" % [budget, committed]
	if total > budget: budget_label.text += " • Spills over"
	var reload_time = Actions.reload_seconds(player)
	reload_label.text = "Gun Ready • %d rnds" % player.model.rounds if reload_time <= 0 else "Reload: %.1fs • %d rnds" % [reload_time, player.model.rounds]
	if not player.model.can_fire(): reload_label.text = "Gun Unavailable"
	if reload_time > 0 and player.orders.get("extinguish", false): reload_label.text += " (loader fighting fire)"
	for i in range(mini(estimates.size(), queue_widgets.size())):
		var estimate = estimates[i]
		var row = queue_widgets[i]
		var timing = "~%.2f s" % estimate.seconds if is_finite(estimate.seconds) else "blocked"
		var caption = "%d  %s · %s" % [i + 1, estimate.title, timing]
		if not estimate.reason.is_empty(): caption += "\n" + estimate.reason
		elif estimate.start >= budget: caption += "\nNext turn"
		elif estimate.end > budget: caption += "\nContinues next turn"
		elif i == 0 and action_queue.running: caption += "\nActive · %.2f s spent" % action_queue.actions[0].spent
		row.label.text = caption
		row.label.add_theme_color_override("font_color", Color("efc477") if estimate.end > budget else Color("8cddf0"))
		row.cancel.disabled = not _can_edit_orders()
		row.limit.editable = _can_edit_orders()
	stop_button.disabled = phase != "EXECUTION" or playback.busy() or time_left <= 0.0001
	stop_button.text = "EDITING · PAUSED" if _can_edit_orders() and phase == "EXECUTION" else "STOP / EDIT"

func _set_mode(mode: String) -> void:
	if not _can_edit_orders(): return
	input_mode = mode
	order_notice = ""

func _clear_orders() -> void:
	if not _can_edit_orders(): return
	action_queue.actions.clear()
	action_queue.running = false
	if phase == "EXECUTION": player.commit(Actions.hold_plan(player))
	_rebuild_queue()
	travel_target = null
	aim_target = null
	aim_selected = false
	input_mode = "select"
	fields.move.value = 0
	fields.pivot.value = 0
	fields.fire.button_pressed = false
	fields.light.button_pressed = false
	fields.extinguish.button_pressed = false
	order_notice = "Orders cleared. Tank will hold position."

func _queue_scan() -> void:
	if not _can_edit_orders() or display_contact.is_empty(): return
	_aim_at(display_contact.position)
	fields.engine.button_pressed = false
	fields.observe.button_pressed = true
	fields.light.button_pressed = true
	order_notice = "Scan queued: listen and use the searchlight for 2 seconds."
	_append_action("scan", _planned_aim())
	_log("SCAN appended. The light can reveal your position.")

func _queue_contact_fire() -> void:
	if not _can_edit_orders() or display_contact.is_empty(): return
	_queue_fire(display_contact.position)

func _queue_fire(point: Vector3) -> void:
	if not _can_edit_orders(): return
	_aim_at(point)
	fields.fire.button_pressed = true
	input_mode = "select"
	order_notice = "One shot queued. Press EXECUTE to aim and fire."
	_append_action("fire", _planned_aim())
	_log("FIRE appended. A shot at an uncertain estimate can miss.")

func _queue_move(point: Vector3) -> void:
	if not _can_edit_orders(): return
	point.y = player.position.y
	if not player.model.can_move():
		order_notice = "Cannot move: driver, engine or transmission unavailable. Check CREW."
		return
	if point.distance_to(player.position) < 1:
		order_notice = "Choose a destination farther from your tank."
		return
	# A swept tank-sized box checks the straight route against industrial cover.
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = player.get_node("CollisionShape3D").shape
	query.transform = player.global_transform * player.get_node("CollisionShape3D").transform
	var route_start: Vector3 = player.position
	for action in action_queue.actions:
		if action.kind == "move" and action.limit == 0: route_start = action.point
	query.transform.origin += route_start - player.position
	query.motion = point - route_start
	query.collision_mask = 1
	query.margin = 0.1
	var fractions = get_world_3d().direct_space_state.cast_motion(query)
	if fractions.is_empty() or fractions[0] < 0.99:
		order_notice = "Route blocked by cover. Choose clear ground or move around the building in shorter steps."
		_log(order_notice)
		return
	fields.move.value = 0
	fields.pivot.value = 0
	travel_target = point
	fields.engine.button_pressed = true
	input_mode = "select"
	order_notice = "Move queued. Press EXECUTE to turn and drive along the blue path."
	_append_action("move", point)
	_log("MOVE appended. Set a time limit to stop early for another action.")

func _planned_aim() -> Vector3:
	if aim_target != null: return Vector3(aim_target.x, fields.height.value, aim_target.z)
	var bearing = deg_to_rad(fields.bearing.value)
	return player.position + Vector3(sin(bearing) * fields.range.value, fields.height.value, -cos(bearing) * fields.range.value)

func _aim_at(point: Vector3) -> void:
	aim_selected = true
	aim_target = point
	updating_fields = true
	var offset = point - player.position
	fields.bearing.value = fposmod(rad_to_deg(atan2(offset.x, -offset.z)), 360)
	fields.range.value = Vector2(offset.x, offset.z).length()
	updating_fields = false

func _execute() -> void:
	if phase == "EXECUTION":
		if _can_edit_orders():
			playback.paused = false
			order_notice = ""
			_set_order_controls(false)
		return
	if phase in ["EXECUTION", "COMPLETE"] or player.model.catastrophic or playback.busy(): return
	if not loadout_locked:
		player.model.set_loadout(25 if ammo_choice.selected == 0 else 40)
		loadout_locked = true
		ammo_choice.disabled = true
	var plan: Dictionary = {}
	for key in fields:
		plan[key] = fields[key].value if fields[key] is SpinBox else fields[key].button_pressed
	plan.aim_point = _planned_aim()
	if travel_target != null: plan.destination = travel_target
	turn_start_time = sim_time
	turn_start_position = player.position
	turn_events.clear()
	playback.accumulator = 0.0
	playback.paused = false
	playback.shot_focus = 0.0
	active_tank = null # True simultaneous execution: no single active tank!
	player_was_hit_this_pulse = false
	enemy_was_hit_this_pulse = false
	
	using_queue = not action_queue.actions.is_empty()
	action_queue.running = false
	if using_queue:
		player.orders["extinguish"] = plan.extinguish
		action_queue.start(player)
	else:
		player.commit(plan)
	input_mode = "select"
	order_notice = ""
	
	# AI plans simultaneously from its own ContactTrack (NO cheat access to player truth!)
	_plan_ai()
	
	# Determine pulse length based on contact status (8s Maneuver vs 3s Combat)
	var direct_engagement = plan.get("fire", false)
	if using_queue:
		for a in action_queue.actions:
			if a.kind == "fire":
				direct_engagement = true
				break
	var p_mode = timeline.evaluate_mode(
		player_track,
		enemy_track,
		sim_time - recent_gunfire_time < 8.0,
		sim_time - recent_hit_time < 8.0,
		direct_engagement
	)
	timeline.start_pulse(p_mode)
	time_left = timeline.pulse_duration
	if pulse_mode_label != null:
		var mode_name = "COMBAT" if p_mode == WegoTimeline.PulseMode.COMBAT else "MANEUVER"
		pulse_mode_label.text = "%s MODE (%.0fs pulse)" % [mode_name, timeline.pulse_duration]
		pulse_mode_label.add_theme_color_override("font_color", Color("ff9b86") if p_mode == WegoTimeline.PulseMode.COMBAT else Color("8cddf0"))
		
	_set_map_running(true)
	phase = "EXECUTION"
	_event("SIMULTANEOUS EXECUTION (%s, %.0fs): Both sides acting." % ["COMBAT" if p_mode == WegoTimeline.PulseMode.COMBAT else "MANEUVER", timeline.pulse_duration])
	if plan.has("destination"): _event("YOU: advancing toward destination.")
	if plan.light: _event("YOU: sweeping searchlight for 2 seconds.")
	
	execute_button.disabled = true
	for control in controls:
		if control is SpinBox: control.editable = false
		elif control is BaseButton: control.disabled = true

func _plan_ai() -> void:
	if enemy == null or enemy.model.catastrophic: return
	var ai_plan: Dictionary = {
		"move": 0.0,
		"pivot": 0.0,
		"bearing": 270.0,
		"range": 75.0,
		"height": 1.45,
		"fire": false,
		"engine": true,
		"observe": true,
		"light": turn % 4 == 0,
		"extinguish": enemy.model.burning
	}
	
	if enemy_track != null:
		var offset = enemy_track.estimated_position - enemy.position
		ai_plan["range"] = maxf(10.0, offset.length())
		ai_plan["bearing"] = fposmod(rad_to_deg(atan2(offset.x, -offset.z)), 360.0)
		
		# If AI has confirmed visual or tight track, it calculates moving lead and fires
		if enemy_track.has_visual_los or enemy_track.range_uncertainty < 35.0:
			var ai_sol = FiringSolution.calculate(enemy, enemy_track, rng)
			ai_plan["aim_point"] = ai_sol.predicted_target_position
			ai_plan["fire"] = turn > 1 and enemy.model.can_fire()
			
		# AI patrol maneuvers when out of contact
		if turn % 3 == 0 and not enemy_track.has_visual_los:
			ai_plan["move"] = -8.0
	enemy.commit(ai_plan)

func _physics_process(delta: float) -> void:
	if phase != "EXECUTION": return
	if not playback.paused: shot_clock += delta
	if not playback.active.is_empty():
		playback.feed(delta)
		impact_viewer.seek(playback.replay_time)
		viewer.seek(playback.replay_time)
		_refresh_impact()
		_world_playback_rate(0)
		return
	if not playback.pending.is_empty():
		_begin_impact()
		return
	if time_left <= 0.0001 and shells.is_empty():
		_finish_execution()
		return
	if not shells.is_empty(): playback.shot_focus = maxf(playback.shot_focus, 0.1)
	playback.feed(delta)
	_world_playback_rate(playback.rate())
	while playback.take_step():
		_simulation_step(Playback.STEP)
		if playback.busy():
			_begin_impact()
			break
		if time_left <= 0.0001 and shells.is_empty():
			_finish_execution()
			break

func _simulation_step(delta: float) -> void:
	var acting = time_left > 0.0001
	var dt = minf(delta, time_left) if acting else delta
	sim_time += dt
	time_left = maxf(0, time_left - dt)
	timeline.sim_time = sim_time
	timeline.pulse_time_left = time_left
	for node in map_scripts: node.call("_process", dt)
	
	if acting:
		# 1. Advance Player Orders
		if using_queue: action_queue.start(player)
		player.step(dt)
		if using_queue:
			var completed = action_queue.advance(player, dt)
			if not completed.is_empty():
				_event("YOU: " + completed)
				_sync_queue_markers()
				_rebuild_queue()
				
		# 2. Advance Enemy SIMULTANEOUSLY!
		enemy.step(dt)
		
		# 3. Evaluate Standing Orders (SOP) based strictly on possessed info
		var p_react = player.doctrine.evaluate(
			player,
			player_track,
			player_was_hit_this_pulse,
			sim_time - recent_gunfire_time < 2.0,
			player_firing_solution.solution_quality if player_firing_solution else "POOR"
		)
		if p_react.halt_movement: player.doctrine_halt = true
		if p_react.reverse_movement: player.doctrine_reversing = true
		if p_react.fire_authorized: player.doctrine_fire_authorized = true
		if not p_react.notice.is_empty() and player.elapsed < dt * 2.0:
			_event(p_react.notice)
			
		var e_react = enemy.doctrine.evaluate(
			enemy,
			enemy_track,
			enemy_was_hit_this_pulse,
			sim_time - recent_gunfire_time < 2.0,
			"ACQUIRED"
		)
		if e_react.halt_movement: enemy.doctrine_halt = true
		if e_react.reverse_movement: enemy.doctrine_reversing = true
		if e_react.fire_authorized: enemy.doctrine_fire_authorized = true
		
		# 4. Simultaneous Firing Checks: both tanks may fire during the same timeline
		if player.ready_to_shoot(): _fire(player)
		if enemy.ready_to_shoot(): _fire(enemy)
		
	# 5. Shell Physics & Collisions
	_step_shells(dt)
	
	# 6. Sensors & Intelligence Update
	sense_timer += dt
	if sense_timer >= 0.25:
		var s_dt = sense_timer
		sense_timer = 0.0
		_evaluate_sensors(s_dt)

func _finish_execution() -> void:
	if phase != "EXECUTION" or playback.busy() or not shells.is_empty(): return
	timeline.complete_pulse()
	_set_map_running(false)
	phase = "ASSESSMENT"
	turn += 1
	player.lamp.visible = false
	enemy.lamp.visible = false
	player.muzzle_flash.visible = false
	enemy.muzzle_flash.visible = false
	player.flash = 0
	enemy.flash = 0
	action_queue.running = false
	
	# Evaluate next pulse mode
	var direct_engagement_next = false
	if using_queue:
		for a in action_queue.actions:
			if a.kind == "fire":
				direct_engagement_next = true
				break
	var next_mode = timeline.evaluate_mode(
		player_track,
		enemy_track,
		sim_time - recent_gunfire_time < 8.0,
		sim_time - recent_hit_time < 8.0,
		direct_engagement_next
	)
	var next_duration = 3.0 if next_mode == WegoTimeline.PulseMode.COMBAT else 8.0
	var mode_name = "COMBAT" if next_mode == WegoTimeline.PulseMode.COMBAT else "MANEUVER"
	if pulse_mode_label:
		pulse_mode_label.text = "%s MODE (%.0fs pulse)" % [mode_name, next_duration]
		pulse_mode_label.add_theme_color_override("font_color", Color("ff9b86") if next_mode == WegoTimeline.PulseMode.COMBAT else Color("8cddf0"))
		
	execute_button.disabled = false
	var has_ongoing = travel_target != null or not action_queue.actions.is_empty()
	execute_button.text = ("CONTINUE ORDERS (%.0fs)" if has_ongoing else "EXECUTE NEXT (%.0fs)") % next_duration
	
	for control in controls:
		if control is SpinBox: control.editable = true
		elif control is BaseButton: control.disabled = false
	updating_fields = true
	fields.move.value = 0
	fields.pivot.value = 0
	updating_fields = false
	if travel_target != null and player.position.distance_to(travel_target) < 0.7: travel_target = null
	
	phase_report = "Simultaneous pulse complete."
	if travel_target != null:
		phase_report += " Move still queued / in progress (%.0fm to destination)." % player.position.distance_to(travel_target)
	elif using_queue and not action_queue.actions.is_empty():
		phase_report += " %d actions remain in queue." % action_queue.actions.size()
	else:
		phase_report += " Orders fulfilled. Ready for next pulse."
		
	fields.fire.button_pressed = false
	if using_queue:
		_sync_queue_markers()
	_publish_contact()
	
	_log("Assessment: your tank %s." % player.model.status())
	if enemy.model.status() in ["Catastrophic loss", "Crew lost", "Combat ineffective"]:
		_log("Engagement complete: enemy %s. Restart to try another engagement." % enemy.model.status())
		phase = "COMPLETE"
		phase_report = "Enemy knocked out. Engagement complete. Use Restart engagement to play again."
		execute_button.disabled = true
	if player.model.status() in ["Catastrophic loss", "Crew lost", "Combat ineffective"]:
		phase = "COMPLETE"
		execute_button.disabled = true
		phase_report = "Your tank is " + player.model.status() + ". Use Restart engagement to play again."
		_log("Engagement ended: your tank " + player.model.status())

	if player.model.status() in ["Catastrophic loss", "Crew lost", "Combat ineffective"] and enemy.model.status() in ["Catastrophic loss", "Crew lost", "Combat ineffective"]:
		phase_report = "Both tanks are out of action. Review TURN for who hit whom."
	var moved = player.position.distance_to(turn_start_position)
	if moved > 0.1: _event("YOUR TANK moved %.1f m this pulse." % moved)
	_event("Pulse ended. Your tank: " + player.model.status() + ".")
	_update_turn_report()
	detail_tabs.current_tab = 3
	if phase == "COMPLETE":
		for control in controls:
			if control is SpinBox: control.editable = false
			elif control is BaseButton: control.disabled = true

func _toggle_playback_pause() -> void:
	if phase != "EXECUTION": return
	playback.paused = not playback.paused
	_world_playback_rate(playback.rate())
	_set_order_controls(_can_edit_orders())

func _begin_impact() -> void:
	var record = playback.start_next()
	if record.is_empty(): return
	_show_record(record, true)
	impact_viewer.show_record(record, true)
	impact_panel.visible = true
	impact_panel.get_parent().move_child(impact_panel, -1)
	_set_order_controls(false)
	impact_title.text = _shot_title(record)
	impact_title.add_theme_color_override("font_color", Color("8cddf0") if record.shooter == "Your tank" else Color("ff9b86"))
	_world_playback_rate(0)
	_refresh_impact()

func _continue_impact() -> void:
	if playback.active.is_empty(): return
	if playback.replay_time < Playback.IMPACT_DURATION:
		playback.replay_time = Playback.IMPACT_DURATION
		impact_viewer.seek(Viewer.DURATION)
		viewer.seek(Viewer.DURATION)
		_refresh_impact()
	else:
		_skip_impact()

func _refresh_impact() -> void:
	impact_stage.text = impact_viewer.stage_text()
	impact_progress.value = playback.replay_time
	var damage: Dictionary = playback.active.get("damage", {})
	var reached: Array[String] = impact_viewer.reached_volumes
	impact_continue.text = "CONTINUE  ▶" if playback.replay_time >= Playback.IMPACT_DURATION else "SHOW FULL REPORT  ▶"
	impact_systems.text = "Battlefield paused. No turn time is spent during this review."
	if playback.replay_time < 2.5:
		impact_effects.text = "Watching the shell strike the armor…"
	elif playback.replay_time < 4.8:
		var entries: Array[String] = []
		for change in damage.get("changes", []):
			if reached.has(change.name): entries.append(change.name.to_upper() + " · " + change.state + "\n" + change.effect)
		impact_effects.text = "\n\n".join(entries) if not entries.is_empty() else "Following the projectile and fragments…"
	else:
		impact_effects.text = Damage.text(damage)
		impact_systems.text = "TARGET STATUS · " + damage.get("status", "Unknown") + "\n\n" + "\n".join(damage.get("capabilities", []))
		if playback.replay_time >= Playback.IMPACT_DURATION:
			impact_stage.text = playback.active.result + "\nReview at your pace · Continue when ready"

func _skip_impact() -> void:
	if playback.active.is_empty(): return
	viewer.seek(Viewer.DURATION)
	viewer.driven = false
	viewer.playing = false
	playback.finish_replay()
	impact_panel.visible = false
	_set_order_controls(_can_edit_orders())
	if not playback.pending.is_empty(): _begin_impact()
	elif time_left <= 0.0001 and shells.is_empty(): _finish_execution()

func _shot_title(record: Dictionary) -> String:
	return "SHOT #%02d • %s → %s" % [record.get("shot_id", 0), "YOU" if record.get("shooter", "") == "Your tank" else "CONTACT A", "YOUR TANK" if record.target == "Your tank" else "CONTACT A"]

func _event(message: String) -> void:
	turn_events.append({"time": sim_time - turn_start_time, "text": message})
	var recent: Array[String] = []
	for entry in turn_events.slice(maxi(0, turn_events.size() - 2)):
		var summary: String = entry.text
		if summary.length() > 100: summary = summary.left(85) + "… [details: TURN]"
		recent.append("+%.2fs  %s" % [entry.time, summary])
	if event_log: event_log.text = "\n".join(recent)

func _update_turn_report() -> void:
	var lines: Array[String] = []
	for event in turn_events: lines.append("+%.2fs  %s" % [event.time, event.text])
	var summaries: Array[String] = ["YOUR TANK: " + player.model.status()]
	# The forensic damage reports already disclose a hit target's condition.
	if records.any(func(r): return r.target == enemy.name): summaries.append("CONTACT A: " + enemy.model.status())
	for event in shot_events:
		if event.get("turn_time", -1.0) < turn_start_time: continue
		summaries.append("#%02d %s → %s\n%s" % [event.id, "YOU" if event.shooter == "Your tank" else "CONTACT A", "YOUR TANK" if event.target == "Your tank" else (event.target if not event.target.is_empty() else "in flight"), event.result])
	turn_report.text = "\n\n".join(summaries) + "\n\nTIMELINE\n" + "\n\n".join(lines)
	for child in turn_shot_buttons.get_children(): child.queue_free()
	for record in records:
		if record.time < turn_start_time: continue
		var button = Button.new()
		button.text = "Replay shot #%02d • %s" % [record.shot_id, "OUTGOING" if record.shooter == "Your tank" else "INCOMING"]
		button.pressed.connect(func():
			if phase != "EXECUTION": _show_record(record))
		turn_shot_buttons.add_child(button)

func _dispersion(tank) -> float:
	var angle = 0.0015 + tank.speed * 0.0015
	if not tank.model.functional("Gunsight"): angle += 0.025
	for c in tank.model.crew:
		if c.station == "Gunner" and c.state != "Fit": angle += 0.008
	return angle

func _fire(tank) -> void:
	if phase != "EXECUTION" or not tank.ready_to_shoot(): return
	var origin: Vector3 = tank.position + Vector3(0, 2.65, 0)
	var dir: Vector3
	var range_m: float = 75.0
	
	if tank == player and player.doctrine_fire_authorized and not fields.fire.button_pressed and player_firing_solution != null:
		dir = player_firing_solution.compute_shell_direction(origin, rng)
		range_m = player_firing_solution.range_m
	else:
		var aim: Vector3
		if tank.orders.has("aim_point"):
			aim = tank.orders.aim_point
			range_m = Vector2(aim.x - origin.x, aim.z - origin.z).length()
		else:
			var bearing = deg_to_rad(tank.orders.get("bearing", 90.0))
			range_m = tank.orders.get("range", 75.0)
			aim = tank.position + Vector3(sin(bearing) * range_m, tank.orders.get("height", 1.4), -cos(bearing) * range_m)
		var time = range_m / Armor.MUZZLE_SPEED
		aim.y += 4.905 * time * time
		dir = (aim - origin).normalized()
		var cone = _dispersion(tank)
		var right = dir.cross(Vector3.UP).normalized()
		var up = right.cross(dir).normalized()
		dir = (dir + right * rng.randfn(0, cone) + up * rng.randfn(0, cone)).normalized()
		
	tank.consume_round()
	shot_serial += 1
	recent_gunfire_time = sim_time
	playback.shot_fired()
	var tracer = Vehicle.box(self, Vector3(0.08, 0.08, 1.5), Transform3D(Basis.IDENTITY, origin), Color("ffdb87"))
	shells.append({"id": shot_serial, "origin": origin, "position": origin, "velocity": dir * Armor.MUZZLE_SPEED, "shooter": tank, "distance": 0.0, "tracer": tracer})
	CombatEffects.spawn_muzzle_blast(self, origin, dir)
	cam_shake = maxf(cam_shake, 0.85)
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr != null and audio_mgr.has_method("play_sound_3d"):
		audio_mgr.play_sound_3d("cannon_fire", origin, 1, 40, 700)
	
	# Acoustic gunshot detection
	var other_tank = enemy if tank == player else player
	var other_track = player_track if tank == enemy else enemy_track
	var acoustic_res = sensor_model.evaluate(other_tank, tank, get_world_3d(), sim_time, true)
	var acoustic_obs = acoustic_res.get("acoustic_observation", null)
	if acoustic_obs != null:
		other_track.integrate_observation(acoustic_obs, sim_time)
		if other_tank == player:
			_publish_contact()
			_event("ACOUSTIC: Gun report detected on bearing %03d°!" % int(acoustic_obs.bearing_deg))

	var known_origin: bool = tank == player or contact_is_visible()
	var display_origin: Vector3 = origin if known_origin else display_contact.get("position", origin)
	shot_events.append({"id": shot_serial, "turn_time": turn_start_time, "shooter": tank.name, "from": display_origin, "to": display_origin, "known_origin": known_origin, "fired": shot_clock, "until": shot_clock + 4, "result": "IN FLIGHT", "target": "", "hit": false})
	_event("Shot #%02d: %s FIRED." % [shot_serial, "YOU" if tank == player else "CONTACT A"])

func _step_shells(delta: float) -> void:
	for i in range(shells.size() - 1, -1, -1):
		var shell = shells[i]
		var start: Vector3 = shell.position
		var finish: Vector3 = start + shell.velocity * delta + Vector3(0, -4.905, 0) * delta * delta
		var dir = (finish - start).normalized()
		var segment = start.distance_to(finish)
		var target = enemy if shell.shooter == player else player
		var inv: Transform3D = target.global_transform.affine_inverse()
		var local_start = inv * start
		var local_dir = inv.basis * dir
		var nearest = INF
		for plate in target.model.plates:
			var hit = Armor.intersect(local_start, local_dir, target.model.pose(plate), plate.size)
			if not hit.is_empty(): nearest = minf(nearest, hit.t)
		var query = PhysicsRayQueryParameters3D.create(start, finish, 1)
		var obstruction = get_world_3d().direct_space_state.intersect_ray(query)
		var obstacle_distance = start.distance_to(obstruction.position) if not obstruction.is_empty() else INF
		var remove = false
		if nearest <= segment and nearest < obstacle_distance:
			if target == player:
				player_was_hit_this_pulse = true
			else:
				enemy_was_hit_this_pulse = true
			recent_hit_time = sim_time
			
			var record = target.model.resolve(local_start, local_dir, shell.velocity.length(), rng.randi())
			record.range = shell.distance + nearest
			record.target = target.name
			record.shooter = shell.shooter.name
			record.shot_id = shell.id
			record.time = sim_time
			for path in record.paths:
				if not path.fragment and path.from == local_start: path.from = local_start + local_dir * maxf(0, nearest - 3)
			records.append(record.duplicate(true))
			if records.size() == 1: selected_record.clear()
			selected_record.add_item("#%02d / %s → %s / %s" % [shell.id, "YOU" if shell.shooter == player else "ENEMY", "YOU" if target == player else "ENEMY", record.result])
			playback.enqueue(record)
			var impact_world_pos = start + dir * nearest
			CombatEffects.spawn_impact_fx(self, impact_world_pos, -dir, record.result)
			cam_shake = maxf(cam_shake, 0.5)
			_set_shot_result(shell.id, impact_world_pos, record.result, target.name, true)
			_event(_shot_title(record) + ": " + record.result + ".")
			if not record.effects.is_empty(): _event(("Your tank: " if target == player else "Contact A: ") + "; ".join(record.effects))
			remove = true
		elif obstacle_distance <= segment:
			CombatEffects.spawn_impact_fx(self, obstruction.position, obstruction.get("normal", Vector3.UP), "GROUND_MISS")
			_set_shot_result(shell.id, obstruction.position, "MISS • COVER / GROUND", "Cover / ground", false)
			_event("Shot #%02d: %s → COVER / GROUND. No tank hit." % [shell.id, "YOU" if shell.shooter == player else "CONTACT A"])
			
			# Gunner splash observation for range refinement
			if shell.shooter == player and player_track != null and contact_is_visible():
				var imp_res = sensor_model.evaluate(player, enemy, get_world_3d(), sim_time, false, obstruction.position)
				var splash_rel = imp_res.get("impact_observation", "")
				if splash_rel != null and not splash_rel.is_empty() and splash_rel != "HIT":
					player_track.apply_observed_impact(splash_rel)
					_event("OBSERVED SPLASH: Shell fell %s. Range corrected!" % splash_rel)
			remove = true
		shell.distance += segment
		shell.position = finish
		shell.velocity += Vector3.DOWN * 9.81 * delta
		shell.tracer.position = finish
		if not remove:
			for event in shot_events:
				if event.id == shell.id: event.to = finish
		if shell.distance > 700:
			_set_shot_result(shell.id, finish, "MISS • OUT OF RANGE", "No hit", false)
			_event("Shot #%02d: %s missed; shell left the engagement." % [shell.id, "YOU" if shell.shooter == player else "CONTACT A"])
			remove = true
		if remove:
			shell.tracer.queue_free()
			shells.remove_at(i)

func _set_shot_result(id: int, point: Vector3, result: String, target: String, hit: bool) -> void:
	for event in shot_events:
		if event.id == id:
			event.to = point
			event.result = result
			event.target = target
			event.hit = hit
			event.until = shot_clock + 4.0
			return

func _evaluate_sensors(dt: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(enemy): return
	var world_3d = get_world_3d()
	
	# 1. Player senses Enemy
	var p_res = sensor_model.evaluate(player, enemy, world_3d, sim_time)
	var p_vis = p_res.get("visual_observation", null)
	var p_ac = p_res.get("acoustic_observation", null)
	if p_vis != null:
		var was_visible = player_track.has_visual_los
		player_track.integrate_observation(p_vis, sim_time)
		if not was_visible:
			_event("VISUAL CONTACT: Target acquired!")
		_publish_contact()
	elif p_ac != null:
		player_track.integrate_observation(p_ac, sim_time)
		if p_ac.source == "Gun report":
			_publish_contact()
	else:
		player_track.predict_motion(dt, sim_time)
		
	# 2. Enemy senses Player (Identical sensor rules! No cheating!)
	var e_res = sensor_model.evaluate(enemy, player, world_3d, sim_time)
	var e_vis = e_res.get("visual_observation", null)
	var e_ac = e_res.get("acoustic_observation", null)
	if e_vis != null:
		enemy_track.integrate_observation(e_vis, sim_time)
	elif e_ac != null:
		enemy_track.integrate_observation(e_ac, sim_time)
	else:
		enemy_track.predict_motion(dt, sim_time)
		
	# Update firing solution
	player_firing_solution = FiringSolution.calculate(player, player_track, rng)

func _publish_contact() -> void:
	if player_track != null and (player_track.has_visual_los or player_track.has_silhouette or player_track.position_uncertainty < 50.0):
		display_contact = player_track.to_dict()

func contact_is_visible() -> bool:
	return player_track != null and player_track.has_visual_los and (player_track.time_since_visual < 1.0)

func _fire_status() -> String:
	if not player.model.can_fire(): return "gunner, breech or ammunition unavailable — check CREW"
	var delay: float = player.model.reload * (1 if player.model.occupied("Loader") else 3.8)
	var point = _planned_aim()
	var offset = point - player.position
	var target_yaw = -atan2(offset.x, -offset.z)
	var turn_time = absf(angle_difference(player.rotation.y + player.model.turret_yaw, target_yaw)) / 0.5
	if phase == "EXECUTION":
		if delay > 0.05: return "reloading (%.1f s)" % delay
		return "turret still turning"
	if fields.extinguish.button_pressed and delay > 0.05: return "reload paused while loader fights fire"
	if maxf(delay, turn_time) > 4.9: return "needs more than this turn (reload %.1f s / aim %.1f s)" % [delay, turn_time]
	if delay > 0.05: return "reload %.1f s, then fire" % delay
	if turn_time > 0.1: return "aim %.1f s, then fire" % turn_time
	return "gun ready"

func _refresh_orders() -> void:
	_refresh_queue()
	var lines: Array[String] = []
	if travel_target != null:
		var distance = player.position.distance_to(travel_target)
		var offset: Vector3 = travel_target - player.position
		var turn_time = absf(angle_difference(player.rotation.y, -atan2(offset.x, -offset.z))) / 0.6
		var travel_time = distance / (2 if fields.creep.button_pressed else 7)
		var p_dur = timeline.pulse_duration if timeline else 5.0
		lines.append("MOVE %.0f m • about %d pulse(s)" % [distance, maxi(1, ceili((turn_time + travel_time) / p_dur))])
		if not player.model.can_move(): lines.append("Cannot move — check CREW / systems")
		elif not fields.engine.button_pressed: lines.append("Engine off — enable it to move")
	elif absf(fields.move.value) > 0 or absf(fields.pivot.value) > 0:
		lines.append("MOVE %.0f m / turn %.0f°" % [fields.move.value, fields.pivot.value])
	else: lines.append("HOLD position")
	if phase == "EXECUTION" and fields.fire.button_pressed and not player.shot_pending:
		lines.append("SHOT FIRED • reloading %.1f sim s" % player.model.reload)
	elif fields.fire.button_pressed:
		lines.append("FIRE 1 shot • %.0f m" % player.position.distance_to(_planned_aim()))
		lines.append(_fire_status().capitalize())
	elif fields.light.button_pressed:
		lines.append("SCAN • searchlight on for 2 seconds")
	elif not player.model.can_fire(): lines.append("Gun unavailable — check CREW")
	else: lines.append("No shot queued")
	if fields.extinguish.button_pressed: lines.append("Loader fights fire")
	order_summary.text = "\n".join(lines)
	if using_queue:
		order_summary.text = "Queue: %d actions" % action_queue.actions.size() if not action_queue.actions.is_empty() else ""
	movement_button.set_pressed_no_signal(input_mode == "move")
	fire_button.set_pressed_no_signal(input_mode == "fire")
	aim_button.set_pressed_no_signal(input_mode == "aim")
	hull_button.set_pressed_no_signal(input_mode == "hull")
	
	var p_dur = timeline.pulse_duration if timeline else 5.0
	execution_progress.max_value = p_dur
	execution_progress.value = p_dur - time_left if phase == "EXECUTION" else 0
	if phase == "EXECUTION":
		if not playback.active.is_empty():
			action_hint.text = "IMPACT REPLAY: " + _shot_title(playback.active)
		elif playback.paused:
			action_hint.text = "PAUSED (%.1fs left)" % time_left
		elif playback.shot_focus > 0:
			action_hint.text = "SLOW-MOTION REPLAY"
		else:
			action_hint.text = "EXECUTING SIMULTANEOUSLY: %.1fs / %.0fs" % [p_dur - time_left, p_dur]
		execute_button.text = "RESUME ▶ (%.1fs)" % time_left if _can_edit_orders() else "RUNNING (%.1fs)" % time_left
		execute_button.disabled = not _can_edit_orders()
	elif phase == "COMPLETE":
		action_hint.text = phase_report
		execute_button.text = "ENGAGEMENT COMPLETE"
	elif input_mode == "move":
		action_hint.text = order_notice if not order_notice.is_empty() else "Click ground to set move destination"
	elif input_mode in ["aim", "hull"]:
		action_hint.text = "Click direction to orient " + ("turret" if input_mode == "aim" else "hull")
	elif input_mode == "fire":
		action_hint.text = "Click target location to aim & fire"
	else:
		action_hint.text = order_notice if not order_notice.is_empty() else (phase_report if phase == "ASSESSMENT" else "")
	if phase not in ["EXECUTION", "COMPLETE"]:
		var has_orders = travel_target != null or fields.fire.button_pressed or fields.light.button_pressed or fields.move.value != 0 or fields.pivot.value != 0 or not action_queue.actions.is_empty()
		execute_button.text = "EXECUTE ORDERS  ▶" if has_orders else "EXECUTE / WAIT %.0fs" % p_dur
		movement_button.disabled = not player.model.can_move()
		fire_button.disabled = not player.model.can_fire()
		contact_fire_button.disabled = not player.model.can_fire() or display_contact.is_empty()
		scan_button.disabled = display_contact.is_empty()

func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	ui_time += delta
	_update_camera(delta)
	
	if radio_callout_timer > 0.0:
		radio_callout_timer -= delta
		if radio_callout_timer <= 0.0 and radio_callout_label:
			radio_callout_label.visible = false

	var pulse_name = "COMBAT (3s)" if (timeline and timeline.current_mode == WegoTimeline.PulseMode.COMBAT) else "MANEUVER (8s)"
	var phase_str = "REPLAY" if not playback.active.is_empty() else ("SIMULTANEOUS EXEC" if phase == "EXECUTION" and not playback.paused else "PLANNING")
	status_label.text = "PULSE #%02d • %s\nMODE: %s\n%s • %d rnds" % [turn, phase_str, pulse_name, player.model.status(), player.model.rounds]
	crew_label.text = player.station_report()

	if tank_card_label != null:
		tank_card_label.text = "A-47 MASTODON • %s\nAMMO: %d/%d • SPEED: %.1fm/s\n%s" % [
			player.model.status().to_upper(),
			player.model.rounds,
			25 if (ammo_choice == null or ammo_choice.selected == 0) else 40,
			player.speed,
			"LOADER EXTINGUISHING" if player.orders.get("extinguish", false) else "SYSTEMS STABLE"
		]

	var visible_contact = contact_is_visible()
	enemy.visible = visible_contact

	if player_track != null and not display_contact.is_empty():
		var age = sim_time - player_track.last_observation_time
		var radius: float = maxf(1.5, player_track.position_uncertainty)
		var blend = 1.0 - exp(-delta * 6)
		contact_visual_position = contact_visual_position.lerp(player_track.estimated_position, blend)
		contact_visual_radius = lerpf(contact_visual_radius, radius, blend)
		var distance = player_track.estimated_range
		var state_str = "SIGHTED" if visible_contact else ("LAST SEEN" if player_track.has_silhouette else "UNCONFIRMED")
		var sol_quality = player_firing_solution.solution_quality if player_firing_solution else "NO SOLUTION"
		contact_label.text = "CONTACT A • %s\nEst. Range: %.0f m (±%.0f m)\nHeading: %03d° (±%d°) • Spd: %.1f m/s\nSolution: %s (Age: %.1fs)" % [
			state_str,
			distance,
			player_track.range_uncertainty,
			int(player_track.estimated_heading_deg),
			int(player_track.heading_uncertainty),
			player_track.estimated_speed_mps,
			sol_quality,
			age
		]
	
	# Update in-world 3D Ghost Tank
	if ghost_tank != null:
		if not visible_contact and player_track != null and player_track.has_silhouette:
			ghost_tank.visible = true
			ghost_tank.position = player_track.silhouette_position
			ghost_tank.rotation.y = player_track.silhouette_yaw
		else:
			ghost_tank.visible = false

	# Update in-world 3D Planning Graphics
	if world_graphics != null:
		var q_pts: Array = []
		for a in action_queue.actions:
			if a.kind == "move": q_pts.append(a.point)
		world_graphics.update_route(player.position, travel_target, q_pts, phase != "EXECUTION")
		world_graphics.update_observation(player.position, player.rotation.y + player.model.turret_yaw, phase != "EXECUTION")
		if not visible_contact and player_track != null and player_track.has_silhouette and player_track.estimated_speed_mps > 0.4:
			world_graphics.update_predicted_corridor(player_track.get_predicted_corridor(5.5), true)
		else:
			world_graphics.update_predicted_corridor({}, false)

	_refresh_orders()
	selected_record.disabled = phase == "EXECUTION"
	pause_button.disabled = phase != "EXECUTION"
	pause_button.text = "RESUME ▶" if playback.paused else "PAUSE"

func _show_record(record: Dictionary, driven = false) -> void:
	detail_tabs.current_tab = 1
	viewer.show_record(record, driven)
	for i in range(records.size()):
		if records[i].get("shot_id", -1) == record.get("shot_id", -2): selected_record.select(i)
	var text_value = _shot_title(record) + "\n75 mm APCBC\nRange %.1f m · impact %.0f m/s\n%s" % [record.range, record.speed, record.result]
	for impact in record.impacts:
		text_value += "\n%s: %.0f mm / %.1f° from normal\nLOS %.1f mm · %s" % [impact.plate, impact.mm, impact.angle, impact.effective, impact.outcome]
	for impact in record.impacts:
		if impact.has("residual_speed"): text_value += "\nResidual projectile: %.0f m/s" % impact.residual_speed
	for effect in record.effects: text_value += "\n" + effect
	if record.effects.is_empty(): text_value += "\nNo internal component or crew effects."
	if record.has("damage"):
		text_value += "\n\nDAMAGE ASSESSMENT\n" + Damage.text(record.damage) + "\n\n" + "\n".join(record.damage.capabilities)
	report.text = text_value

func _log(message: String) -> void:
	log_lines.append(message)
	if log_lines.size() > 2: log_lines.pop_front()
	if event_log: event_log.text = "\n".join(log_lines)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F3:
			debug_overlay_enabled = not debug_overlay_enabled
			player.set_debug_visuals(debug_overlay_enabled)
			enemy.set_debug_visuals(debug_overlay_enabled)
			_event("Debug overlay: %s" % ("ENABLED" if debug_overlay_enabled else "DISABLED"))
		elif event.keycode == KEY_F:
			cam_target = player.position + Vector3(6, 0, 0)
			_event("Camera: Focused on Mastodon.")
		elif event.keycode == KEY_C:
			if player_track != null:
				cam_target = player_track.estimated_position
				_event("Camera: Focused on contact estimate.")
		elif event.keycode == KEY_TAB:
			if left_drawer: left_drawer.visible = not left_drawer.visible
			if right_drawer: right_drawer.visible = not right_drawer.visible
		elif event.keycode == KEY_W:
			cam_target += Vector3(-sin(cam_yaw), 0, -cos(cam_yaw)) * 6.0
		elif event.keycode == KEY_S:
			cam_target += Vector3(sin(cam_yaw), 0, cos(cam_yaw)) * 6.0
		elif event.keycode == KEY_A:
			cam_target += Vector3(-cos(cam_yaw), 0, sin(cam_yaw)) * 6.0
		elif event.keycode == KEY_D:
			cam_target += Vector3(cos(cam_yaw), 0, -sin(cam_yaw)) * 6.0
		elif event.keycode == KEY_ESCAPE:
			input_mode = "select"
			order_notice = "Target selection cancelled. Existing orders are unchanged."
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_orbiting = event.pressed
			last_mouse_pos = event.position
			if event.pressed and _can_edit_orders() and input_mode != "select":
				input_mode = "select"
				order_notice = "Target selection cancelled. Use CLEAR ALL to remove queued orders."
		elif event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				cam_distance = clampf(cam_distance - 4.0, 14.0, 140.0)
				zoom = clampf(zoom - 8.0, 35.0, 200.0)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				cam_distance = clampf(cam_distance + 4.0, 14.0, 140.0)
				zoom = clampf(zoom + 8.0, 35.0, 200.0)
			elif event.button_index == MOUSE_BUTTON_LEFT and _can_edit_orders():
				var ray = camera.project_ray_origin(event.position)
				var direction = camera.project_ray_normal(event.position)
				var hit = Plane(Vector3.UP, 0).intersects_ray(ray, direction)
				if hit != null:
					if input_mode == "move": _queue_move(hit)
					elif input_mode == "fire": _queue_fire(hit)
					elif input_mode in ["aim", "hull"]:
						var kind = input_mode
						if kind == "aim": _aim_at(hit)
						_append_action(kind, Vector3(hit.x, fields.height.value, hit.z) if kind == "aim" else hit)
						input_mode = "select"
					else: order_notice = "Choose MOVE or AIM & FIRE first, then click a point in the yard."
	elif event is InputEventMouseMotion and is_orbiting:
		var delta_mouse = event.position - last_mouse_pos
		last_mouse_pos = event.position
		cam_yaw += delta_mouse.x * 0.006
		cam_pitch = clampf(cam_pitch - delta_mouse.y * 0.006, deg_to_rad(-80.0), deg_to_rad(-10.0))

