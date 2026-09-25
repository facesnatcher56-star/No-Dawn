extends Node3D
const Vehicle = preload("res://scripts/wego/TacticalVehicle.gd")
const Viewer = preload("res://scripts/wego/ShotViewer.gd")
const Overlay = preload("res://scripts/wego/BattlefieldOverlay.gd")
const Playback = preload("res://scripts/wego/CombatPlayback.gd")
const Armor = preload("res://scripts/wego/ArmorModel.gd")
var player
var enemy
var camera: Camera3D
var phase = "PLANNING"
var turn = 1
var time_left = 5.0
var sim_time = 0.0
var sense_timer = 0.0
var shells: Array = []
var records: Array = []
var rng = RandomNumberGenerator.new()
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
var zoom = 150.0
var ammo_choice: OptionButton
var loadout_locked = false

func _ready() -> void:
	rng.seed = 94217
	player = Vehicle.new()
	player.name = "Your tank"
	player.position = Vector3(-185, 0, 110)
	player.rotation.y = -PI / 2
	add_child(player)
	enemy = Vehicle.new()
	enemy.name = "Contact A"
	enemy.position = Vector3(-110, 0, 110)
	enemy.rotation.y = PI / 2
	enemy.color = Color("736752")
	add_child(enemy)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = zoom
	add_child(camera)
	camera.current = true
	_build_ui()
	_set_map_running(false)
	# The two crews start with an imprecise briefing, not the opponent's coordinates.
	player.contact = {"position": Vector3(-108, 0, 105), "uncertainty": 22.0, "time": 0.0, "source": "Briefing / unconfirmed", "bearing": 90.0, "arc": 16.0}
	enemy.contact = {"position": Vector3(-180, 0, 120), "uncertainty": 25.0, "time": 0.0, "source": "Briefing", "bearing": 270.0, "arc": 16.0}
	_publish_contact()
	contact_visual_position = display_contact.position
	_log("Start here: SCAN FOR ENEMY, then EXECUTE. Or choose MOVE / AIM & FIRE and click the yard.")

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
	panel.offset_left = 12
	panel.offset_top = 12
	panel.offset_right = -12
	panel.offset_bottom = -12
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.065, 0.08, 0.96)
	style.border_color = Color("405a60")
	style.set_border_width_all(1)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	box.add_theme_constant_override("separation", 7)
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
	var left = _panel(root, 0, 0, 0.26, 0.83)
	_label(left, "YOUR ORDERS", 23)
	status_label = _label(left, "", 14)
	_label(left, "1  CHOOSE AN ACTION", 13)
	var actions = HBoxContainer.new()
	left.add_child(actions)
	movement_button = _button(actions, "MOVE", func(): _set_mode("move"), 44)
	fire_button = _button(actions, "AIM & FIRE", func(): _set_mode("fire"), 44)
	movement_button.toggle_mode = true
	fire_button.toggle_mode = true
	movement_button.tooltip_text = "Click MOVE, then click clear ground. The tank turns and drives there during execution."
	fire_button.tooltip_text = "Click AIM & FIRE, then click a point on the battlefield. One shot is queued for execution."
	scan_button = _button(left, "SCAN FOR ENEMY", _queue_scan)
	scan_button.tooltip_text = "Stop and watch the enemy estimate, switch the engine off, and shine the searchlight for two seconds. This can expose you."
	_label(left, "2  REVIEW YOUR ORDERS", 13)
	order_summary = _label(left, "", 14)
	order_summary.custom_minimum_size.y = 90
	execute_button = _button(left, "EXECUTE ORDERS  ▶", _execute, 48)
	var execute_style = StyleBoxFlat.new()
	execute_style.bg_color = Color("285e55")
	execute_style.set_corner_radius_all(4)
	execute_button.add_theme_stylebox_override("normal", execute_style)
	execution_progress = ProgressBar.new()
	execution_progress.max_value = 5
	execution_progress.show_percentage = false
	execution_progress.custom_minimum_size.y = 7
	left.add_child(execution_progress)
	_label(left, "5 simulated seconds per turn.\nPlayback starts at half speed.", 13)
	cancel_button = _button(left, "CLEAR ORDERS", _clear_orders, 30)
	var advanced = VBoxContainer.new()
	var advanced_toggle = _button(left, "Advanced orders  ▸", func(): advanced.visible = not advanced.visible, 30)
	advanced_toggle.tooltip_text = "Optional manual bearing, range, engine and crew controls."
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
	_label(advanced, "Loadout (before turn 1)")
	ammo_choice = OptionButton.new()
	ammo_choice.clip_text = true
	ammo_choice.fit_to_longest_item = false
	ammo_choice.add_item("25 rounds / protected storage")
	ammo_choice.add_item("40 rounds / overflow rack filled")
	advanced.add_child(ammo_choice)
	_button(left, "Restart engagement", func(): get_tree().reload_current_scene(), 28)
	# Restart and advanced inspection remain usable after an engagement ends.
	controls.pop_back()
	controls.erase(advanced_toggle)
	var right = _panel(root, 0.72, 0, 1, 1)
	_label(right, "ENEMY INTELLIGENCE", 20)
	contact_label = _label(right, "", 14)
	contact_fire_button = _button(right, "FIRE AT THIS ESTIMATE", _queue_contact_fire, 40)
	contact_fire_button.tooltip_text = "Queue a shot at the marked estimate. An uncertain contact can be far from the real tank."
	detail_tabs = TabBar.new()
	detail_tabs.add_theme_font_size_override("font_size", 13)
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
	_label(turn_box, "WHAT HAPPENED THIS TURN", 18)
	turn_report = _label(turn_box, "Execute your orders to see movement, shots and damage here.", 14)
	turn_shot_buttons = VBoxContainer.new()
	turn_box.add_child(turn_shot_buttons)
	turn_box.move_child(turn_shot_buttons, 1)
	_label(help_box, "WATCH THE ACTION", 18)
	_label(help_box, "Execution starts at half speed. Gunfire slows automatically. Armor impacts pause the battlefield for a 6.5-second cutaway. Pause / Resume works during both action and replay. Impacts play one at a time; Continue skips to the next.", 14)
	_label(help_box, "YOUR FIRST TURN", 18)
	_label(help_box, "1. Press SCAN FOR ENEMY.\n2. Press EXECUTE ORDERS.\n3. Watch the 5-second action, then read the new report.", 15)
	_label(help_box, "HOW TO MOVE", 18)
	_label(help_box, "Press MOVE, then click clear ground. A blue path shows your destination. Press EXECUTE to turn and drive. Long moves continue over later turns.", 14)
	_label(help_box, "HOW TO FIRE", 18)
	_label(help_box, "Press AIM & FIRE, then click a target point. Or press FIRE AT THIS ESTIMATE above. A red crosshair marks the queued shot. Press EXECUTE to fire once the gun is ready and aimed.", 14)
	_label(help_box, "WHAT THE MARKERS MEAN", 18)
	_label(help_box, "Blue = your tank and move order.\nYellow ? = possible enemy area, not a visible tank. A wider area means less certainty.\nRed ! = enemy sighted.\nRed crosshair = your chosen firing point.\n\nSound estimates settle at turn end. Sightings and gunfire can update them sooner. Wheel zooms; Esc cancels target selection.", 14)
	right = shot_box
	viewer = Viewer.new()
	viewer.custom_minimum_size = Vector2(260, 180)
	right.add_child(viewer)
	_label(right, "Click to replay / right-drag to orbit", 12)
	selected_record = OptionButton.new()
	selected_record.clip_text = true
	selected_record.fit_to_longest_item = false
	selected_record.add_item("No armor impacts recorded")
	selected_record.item_selected.connect(func(index):
		if index < records.size(): _show_record(records[index]))
	right.add_child(selected_record)
	report = _label(right, "Fire a shot to see its armor and internal damage report here.", 13)
	right = crew_box
	_label(right, "CREW / VEHICLE", 18)
	crew_label = _label(right, "", 13)
	var person = OptionButton.new()
	for c in player.model.crew: person.add_item(c.name)
	right.add_child(person)
	var station = OptionButton.new()
	for c in player.model.crew: station.add_item(c.station)
	right.add_child(station)
	_button(right, "Transfer crew / 10 seconds", func():
		if phase not in ["EXECUTION", "COMPLETE"]:
			if player.model.reassign(person.selected, station.get_item_text(station.selected)): _log("Crew transfer started; advances during execution.")
			else: _log("Transfer unavailable: destination occupied, crew unfit, or transfer already underway."))
	var hint_box = _panel(root, 0.26, 0, 0.72, 0.205)
	action_hint = _label(hint_box, "", 15)
	var playback_row = HBoxContainer.new()
	hint_box.add_child(playback_row)
	pause_button = _button(playback_row, "PAUSE ACTION", _toggle_playback_pause, 28)
	controls.erase(pause_button)
	speed_choice = OptionButton.new()
	for caption in ["¼ speed", "½ speed (default)", "1× speed"]: speed_choice.add_item(caption)
	speed_choice.select(1)
	speed_choice.item_selected.connect(func(index): playback.speed = [0.25, 0.5, 1.0][index])
	playback_row.add_child(speed_choice)
	var impact_box = _panel(root, 0.27, 0.22, 0.72, 0.83)
	impact_panel = impact_box.get_parent().get_parent()
	impact_title = _label(impact_box, "", 19)
	impact_viewer = Viewer.new()
	impact_viewer.custom_minimum_size = Vector2(280, 220)
	impact_box.add_child(impact_viewer)
	impact_stage = _label(impact_box, "", 15)
	impact_effects = _label(impact_box, "", 13)
	impact_effects.custom_minimum_size.y = 35
	impact_progress = ProgressBar.new()
	impact_progress.max_value = Playback.IMPACT_DURATION
	impact_progress.show_percentage = false
	impact_progress.custom_minimum_size.y = 6
	impact_box.add_child(impact_progress)
	var replay_buttons = HBoxContainer.new()
	impact_box.add_child(replay_buttons)
	var retry = _button(replay_buttons, "REPLAY THIS SHOT", func(): playback.restart_replay(), 30)
	var next = _button(replay_buttons, "CONTINUE  ▶", _skip_impact, 30)
	controls.erase(retry)
	controls.erase(next)
	impact_panel.visible = false
	var footer = _panel(root, 0, 0.83, 0.72, 1)
	_label(footer, "ACTION TIMELINE • blue = your shots / red = enemy shots", 12)
	event_log = _label(footer, "", 14)

func _set_mode(mode: String) -> void:
	if phase in ["EXECUTION", "COMPLETE"]: return
	input_mode = mode
	order_notice = ""

func _clear_orders() -> void:
	if phase in ["EXECUTION", "COMPLETE"]: return
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
	if phase in ["EXECUTION", "COMPLETE"] or display_contact.is_empty(): return
	_clear_orders()
	_aim_at(display_contact.position)
	fields.engine.button_pressed = false
	fields.observe.button_pressed = true
	fields.light.button_pressed = true
	order_notice = "Scan queued: listen and use the searchlight for 2 seconds."
	_log("SCAN queued. Press EXECUTE to search the marked area. The light can reveal your position.")

func _queue_contact_fire() -> void:
	if phase in ["EXECUTION", "COMPLETE"] or display_contact.is_empty(): return
	_queue_fire(display_contact.position)

func _queue_fire(point: Vector3) -> void:
	if phase in ["EXECUTION", "COMPLETE"]: return
	_aim_at(point)
	fields.fire.button_pressed = true
	input_mode = "select"
	order_notice = "One shot queued. Press EXECUTE to aim and fire."
	_log("FIRE queued at %.0f m. Press EXECUTE. A shot at an uncertain estimate can miss." % player.position.distance_to(point))

func _queue_move(point: Vector3) -> void:
	if phase in ["EXECUTION", "COMPLETE"]: return
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
	query.motion = point - player.position
	query.collision_mask = 1
	query.margin = 0.1
	var fractions = get_world_3d().direct_space_state.cast_motion(query)
	if fractions[0] < 0.99:
		order_notice = "Route blocked by cover. Choose clear ground or move around the building in shorter steps."
		_log(order_notice)
		return
	fields.move.value = 0
	fields.pivot.value = 0
	travel_target = point
	fields.engine.button_pressed = true
	input_mode = "select"
	order_notice = "Move queued. Press EXECUTE to turn and drive along the blue path."
	_log("MOVE queued: %.0f m. Long moves continue when you execute later turns." % point.distance_to(player.position))

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
	player.commit(plan)
	input_mode = "select"
	order_notice = ""
	# AI commits using its own last observation, before either tank moves.
	var believed: Vector3 = enemy.contact.get("position", enemy.position + Vector3(-70, 0, 0))
	var offset = believed - enemy.position
	enemy.commit({"move": 0.0 if turn % 3 != 0 else -8.0, "pivot": 0.0, "bearing": fposmod(rad_to_deg(atan2(offset.x, -offset.z)), 360), "range": offset.length(), "height": 1.45, "fire": turn > 1, "engine": true, "observe": true, "light": turn % 4 == 0, "extinguish": enemy.model.burning})
	_set_map_running(true)
	phase = "EXECUTION"
	_event("Orders committed. Both tanks act simultaneously.")
	if plan.has("destination"): _event("YOU: move %.0f m toward the marked destination." % player.position.distance_to(plan.destination))
	if plan.light: _event("YOU: scan with searchlight for the first 2 simulated seconds.")
	time_left = 5
	execute_button.disabled = true
	for control in controls:
		if control is SpinBox: control.editable = false
		elif control is BaseButton: control.disabled = true

func _physics_process(delta: float) -> void:
	if phase != "EXECUTION": return
	if not playback.paused: shot_clock += delta
	if not playback.active.is_empty():
		playback.feed(delta)
		impact_viewer.seek(playback.replay_time)
		viewer.seek(playback.replay_time)
		_refresh_impact()
		_world_playback_rate(0)
		if playback.replay_time >= Playback.IMPACT_DURATION: _skip_impact()
		return
	if not playback.pending.is_empty():
		_begin_impact()
		return
	if time_left <= 0.0001:
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
		if time_left <= 0.0001:
			_finish_execution()
			break

func _simulation_step(delta: float) -> void:
	var dt = minf(delta, time_left)
	sim_time += dt
	time_left = maxf(0, time_left - dt)
	for node in map_scripts: node.call("_process", dt)
	player.step(dt)
	enemy.step(dt)
	# Both readiness decisions are made before resolving this tick's projectile impacts.
	for tank in [player, enemy]:
		if tank.ready_to_shoot(): _fire(tank)
	_step_shells(dt)
	sense_timer += dt
	if sense_timer >= 0.5:
		sense_timer = 0
		_sense(player, enemy)
		_sense(enemy, player)

func _finish_execution() -> void:
	if phase != "EXECUTION" or playback.busy(): return
	_set_map_running(false)
	phase = "ASSESSMENT"
	turn += 1
	player.lamp.visible = false
	enemy.lamp.visible = false
	execute_button.disabled = false
	execute_button.text = "EXECUTE NEXT  /  5 SECONDS"
	for control in controls:
		if control is SpinBox: control.editable = true
		elif control is BaseButton: control.disabled = false
	updating_fields = true
	fields.move.value = 0
	fields.pivot.value = 0
	updating_fields = false
	if travel_target != null and player.position.distance_to(travel_target) < 0.7: travel_target = null
	phase_report = "Turn complete. Review the report, then choose your next orders."
	if player.shot_pending:
		phase_report = "Gun did not fire: " + _fire_status() + ". Queue a shot again next turn."
		_log(phase_report)
	elif fields.fire.button_pressed:
		phase_report = "Shot fired. Inspect SHOT for armor hits, or read the crew report for misses."
	if travel_target != null:
		phase_report += " Move still queued; EXECUTE continues it."
	fields.fire.button_pressed = false
	_publish_contact()
	if player.orders.get("light", false) and not player.orders.get("fire", false):
		phase_report = "Enemy spotted. FIRE AT THIS ESTIMATE queues a shot at its last seen position." if display_contact.get("source", "") == "Visual silhouette" else "No visual contact. Try another scan or move to improve your view."
	_log("Assessment: your tank %s. Unfinished reloads, transfers and projectiles carry into the next execution." % player.model.status())
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
	if moved > 0.1: _event("YOUR TANK moved %.1f m this turn." % moved)
	_event("Turn ended. Your tank: " + player.model.status() + ".")
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

func _begin_impact() -> void:
	var record = playback.start_next()
	if record.is_empty(): return
	_show_record(record, true)
	impact_viewer.show_record(record, true)
	impact_panel.visible = true
	impact_title.text = _shot_title(record)
	impact_title.add_theme_color_override("font_color", Color("8cddf0") if record.shooter == "Your tank" else Color("ff9b86"))
	_world_playback_rate(0)
	_refresh_impact()

func _refresh_impact() -> void:
	impact_stage.text = impact_viewer.stage_text()
	impact_progress.value = playback.replay_time
	var reached: Array[String] = impact_viewer.reached_volumes
	if playback.replay_time < 2.5:
		impact_effects.text = "Battlefield paused • impact %d of %d queued" % [1, 1 + playback.pending.size()]
	elif reached.is_empty():
		impact_effects.text = "No internal components struck." if playback.replay_time >= 4.8 else "Following the recorded projectile paths…"
	else:
		impact_effects.text = "STRUCK: " + ", ".join(reached)

func _skip_impact() -> void:
	if playback.active.is_empty(): return
	viewer.seek(Viewer.DURATION)
	viewer.driven = false
	viewer.playing = false
	playback.finish_replay()
	impact_panel.visible = false
	if not playback.pending.is_empty(): _begin_impact()
	elif time_left <= 0.0001: _finish_execution()

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
	var origin: Vector3 = tank.position + Vector3(0, 2.65, 0)
	var bearing = deg_to_rad(tank.orders.bearing)
	var range_m: float = tank.orders.range
	var aim: Vector3 = tank.position + Vector3(sin(bearing) * range_m, tank.orders.height, -cos(bearing) * range_m)
	if tank.orders.has("aim_point"):
		aim = tank.orders.aim_point
		range_m = Vector2(aim.x - origin.x, aim.z - origin.z).length()
	var time = range_m / Armor.MUZZLE_SPEED
	aim.y += 4.905 * time * time
	var dir = (aim - origin).normalized()
	var cone = _dispersion(tank)
	var right = dir.cross(Vector3.UP).normalized()
	var up = right.cross(dir).normalized()
	dir = (dir + right * rng.randfn(0, cone) + up * rng.randfn(0, cone)).normalized()
	tank.consume_round()
	shot_serial += 1
	playback.shot_fired()
	var tracer = Vehicle.box(self, Vector3(0.08, 0.08, 1.5), Transform3D(Basis.IDENTITY, origin), Color("ffdb87"))
	shells.append({"id": shot_serial, "origin": origin, "position": origin, "velocity": dir * Armor.MUZZLE_SPEED, "shooter": tank, "distance": 0.0, "tracer": tracer})
	AudioManager.play_sound_3d("cannon_fire", origin, 1, 40, 700)
	_sense(enemy if tank == player else player, tank, true)
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
			var record = target.model.resolve(local_start, local_dir, shell.velocity.length(), rng.randi())
			record.range = shell.distance + nearest
			record.target = target.name
			record.shooter = shell.shooter.name
			record.shot_id = shell.id
			record.time = sim_time
			# Keep the recorded incoming segment short enough for a useful cutaway.
			for path in record.paths:
				if not path.fragment and path.from == local_start: path.from = local_start + local_dir * maxf(0, nearest - 3)
			records.append(record.duplicate(true))
			if records.size() == 1: selected_record.clear()
			selected_record.add_item("#%02d / %s → %s / %s" % [shell.id, "YOU" if shell.shooter == player else "ENEMY", "YOU" if target == player else "ENEMY", record.result])
			playback.enqueue(record)
			_set_shot_result(shell.id, start + dir * nearest, record.result, target.name, true)
			_event(_shot_title(record) + ": " + record.result + ".")
			if not record.effects.is_empty(): _event(("Your tank: " if target == player else "Contact A: ") + "; ".join(record.effects))
			remove = true
		elif obstacle_distance <= segment:
			_set_shot_result(shell.id, obstruction.position, "MISS • COVER / GROUND", "Cover / ground", false)
			_event("Shot #%02d: %s → COVER / GROUND. No tank hit." % [shell.id, "YOU" if shell.shooter == player else "CONTACT A"])
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

func _sense(observer, target, gun_report = false) -> void:
	var offset: Vector3 = target.position - observer.position
	var distance = offset.length()
	var actual_bearing = atan2(offset.x, -offset.z)
	var turret_bearing = -(observer.rotation.y + observer.model.turret_yaw)
	var watching = observer.orders.get("observe", false)
	var optics = observer.model.occupied("Commander") and observer.model.functional("Commander optics")
	var in_sector = absf(angle_difference(turret_bearing, actual_bearing)) < (0.5 if optics else 0.16)
	var query = PhysicsRayQueryParameters3D.create(observer.position + Vector3.UP * 3, target.position + Vector3.UP * 2, 1)
	var clear = get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	var lit = target.lamp.visible or observer.lamp.visible or target.flash > 0
	var visual = clear and in_sector and watching and distance < (140 if lit else 48) and optics
	if visual:
		observer.contact = {"position": target.position + Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3)), "uncertainty": 0.8, "time": sim_time, "source": "Visual silhouette", "bearing": rad_to_deg(actual_bearing), "arc": 1.0}
		if observer == player: _publish_contact()
		return
	if not gun_report and (not target.engine_on or not target.model.functional("Engine") or distance > 190): return
	var arc = 2.0 if gun_report else (5.0 if not observer.engine_on else 11.0)
	if SoundEventManager.masking_active and not gun_report: arc *= 1.8
	var measured = actual_bearing + deg_to_rad(rng.randf_range(-arc, arc))
	var direction = Vector2(sin(measured), -cos(measured))
	var here = Vector2(observer.position.x, observer.position.z)
	var range_guess = distance * rng.randf_range(0.65, 1.35)
	var estimated = here + direction * range_guess
	var uncertainty = maxf(5, distance * 0.35)
	var source = "Gun report" if gun_report else "Engine noise"
	for observation in observer.history:
		if here.distance_to(observation.position) < 12 or sim_time - observation.time > 20: continue
		var cross = direction.cross(observation.direction)
		if absf(cross) < 0.12: continue
		var t = (observation.position - here).cross(observation.direction) / cross
		var old_t = (observation.position - here).cross(direction) / cross
		if t > 5 and t < 350 and old_t > 0:
			estimated = here + direction * t
			uncertainty = maxf(4, t * deg_to_rad(arc) / absf(cross))
			source = "Cross-bearing fix"
			break
	if observer.history.is_empty() or here.distance_to(observer.history.back().position) > 8:
		observer.history.append({"position": here, "direction": direction, "time": sim_time})
		if observer.history.size() > 12: observer.history.pop_front()
	# A noisy sound does not overwrite a recent precise visual fix.
	if not observer.contact.is_empty() and observer.contact.source == "Visual silhouette" and sim_time - observer.contact.time < 8 and not gun_report: return
	var updated = {"position": Vector3(estimated.x, 0, estimated.y), "uncertainty": uncertainty, "time": sim_time, "source": source, "bearing": rad_to_deg(measured), "arc": arc}
	if not observer.contact.is_empty() and not gun_report:
		var previous: Dictionary = observer.contact
		var weight = 0.18 if source == "Engine noise" else 0.45
		updated.position = previous.position.lerp(updated.position, weight)
		# Repeated reports from the same place do not magically narrow the uncertainty.
		updated.uncertainty = maxf(uncertainty, previous.uncertainty * (1 - weight))
	observer.contact = updated
	if observer == player and gun_report: _publish_contact()

func _publish_contact() -> void:
	if not player.contact.is_empty(): display_contact = player.contact.duplicate(true)

func contact_is_visible() -> bool:
	return not player.contact.is_empty() and player.contact.source == "Visual silhouette" and sim_time - player.contact.time < 1.0

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
	var lines: Array[String] = []
	if travel_target != null:
		var distance = player.position.distance_to(travel_target)
		var offset: Vector3 = travel_target - player.position
		var turn_time = absf(angle_difference(player.rotation.y, -atan2(offset.x, -offset.z))) / 0.6
		var travel_time = distance / (2 if fields.creep.button_pressed else 7)
		lines.append("MOVE %.0f m • about %d turn(s)" % [distance, maxi(1, ceili((turn_time + travel_time) / 5))])
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
	movement_button.set_pressed_no_signal(input_mode == "move")
	fire_button.set_pressed_no_signal(input_mode == "fire")
	execution_progress.value = 5 - time_left if phase == "EXECUTION" else 0
	if phase == "EXECUTION":
		if not playback.active.is_empty():
			action_hint.text = "IMPACT REPLAY • BATTLEFIELD PAUSED\n" + _shot_title(playback.active)
		elif playback.paused:
			action_hint.text = "ACTION PAUSED\nPress RESUME to continue. Your orders are still locked."
		elif playback.shot_focus > 0:
			var firing: Array[String] = []
			for event in shot_events:
				if shot_clock - event.fired < 2: firing.append("YOU" if event.shooter == "Your tank" else "CONTACT A")
			action_hint.text = "SHOT SLOW-MOTION • 8% SPEED\n" + " + ".join(firing) + " FIRED — watch the colored trails."
		else:
			action_hint.text = "EXECUTING • %.2f / 5.00 simulated seconds\nPlayback %.2f× • both tanks act simultaneously." % [5 - time_left, playback.speed]
		execute_button.text = "WATCHING  •  %.1f sim s left" % time_left
	elif phase == "COMPLETE":
		action_hint.text = phase_report
		execute_button.text = "ENGAGEMENT COMPLETE"
	elif input_mode == "move":
		action_hint.text = order_notice if not order_notice.is_empty() else "MOVE: CLICK CLEAR GROUND\nThen press EXECUTE to turn and drive."
	elif input_mode == "fire":
		action_hint.text = "FIRE: CLICK A TARGET POINT\nThen press EXECUTE to aim and fire."
	else:
		action_hint.text = order_notice if not order_notice.is_empty() else (phase_report if phase == "ASSESSMENT" else "PLAN YOUR TURN\nMove or aim with a click, then press EXECUTE.")
	if phase not in ["EXECUTION", "COMPLETE"]:
		execute_button.text = "EXECUTE ORDERS  ▶" if travel_target != null or fields.fire.button_pressed or fields.light.button_pressed or fields.move.value != 0 or fields.pivot.value != 0 else "EXECUTE / WAIT 5 SECONDS"
		movement_button.disabled = not player.model.can_move()
		fire_button.disabled = not player.model.can_fire()
		contact_fire_button.disabled = not player.model.can_fire() or display_contact.is_empty()
		scan_button.disabled = display_contact.is_empty()

func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	ui_time += delta
	camera.size = zoom
	camera.position = player.position + Vector3(37, 90, 65)
	camera.look_at(player.position + Vector3(37, 0, 0))
	status_label.text = "TURN %02d • %s\n%s • %d rounds" % [turn, ("IMPACT REPLAY" if not playback.active.is_empty() else ("ACTING" if phase == "EXECUTION" and not playback.paused else "PAUSED")), player.model.status(), player.model.rounds]
	crew_label.text = player.station_report()
	var contact = display_contact
	if not contact.is_empty():
		var age = sim_time - contact.time
		var radius: float = maxf(1.5, contact.uncertainty + age * 2)
		var blend = 1.0 - exp(-delta * 6)
		contact_visual_position = contact_visual_position.lerp(contact.position, blend)
		contact_visual_radius = lerpf(contact_visual_radius, radius, blend)
		var distance = player.position.distance_to(contact.position)
		var visible_contact = contact_is_visible()
		var description = "Enemy sighted by your crew." if visible_contact else "Enemy location is uncertain. It may be anywhere in the yellow dashed area."
		var source: String = contact.source
		if source == "Visual silhouette" and not visible_contact: source = "Last seen position / sight lost"
		contact_label.text = "CONTACT A • %s\n%s\n\nReport: %s\nRange: %.0f–%.0f m • %.1f s ago" % ["SIGHTED" if visible_contact else ("LAST SEEN" if contact.source == "Visual silhouette" else "UNCONFIRMED"), description, source, maxf(0, distance - radius), distance + radius, age]
		enemy.visible = visible_contact
	else: enemy.visible = false
	_refresh_orders()
	selected_record.disabled = phase == "EXECUTION"
	pause_button.disabled = phase != "EXECUTION"
	pause_button.text = "RESUME ▶" if playback.paused else ("PAUSE REPLAY" if not playback.active.is_empty() else "PAUSE ACTION")

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
	report.text = text_value

func _log(message: String) -> void:
	log_lines.append(message)
	if log_lines.size() > 2: log_lines.pop_front()
	if event_log: event_log.text = "\n".join(log_lines)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		input_mode = "select"
		order_notice = "Target selection cancelled. Existing orders are unchanged."
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: zoom = maxf(35, zoom - 8)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: zoom = minf(200, zoom + 8)
		if event.button_index == MOUSE_BUTTON_RIGHT and phase not in ["EXECUTION", "COMPLETE"]:
			input_mode = "select"
			order_notice = "Target selection cancelled. Use CLEAR ORDERS to remove queued orders."
		if event.button_index == MOUSE_BUTTON_LEFT and phase not in ["EXECUTION", "COMPLETE"]:
			var ray = camera.project_ray_origin(event.position)
			var direction = camera.project_ray_normal(event.position)
			var hit = Plane(Vector3.UP, 0).intersects_ray(ray, direction)
			if hit != null:
				if input_mode == "move": _queue_move(hit)
				elif input_mode == "fire": _queue_fire(hit)
				else: order_notice = "Choose MOVE or AIM & FIRE first, then click a point in the yard."
