extends Control
## Screen-space tactical symbols keep their labels readable at every zoom level.
var game
var font: Font = ThemeDB.fallback_font
var label_rects: Array[Rect2] = []
const BLUE = Color("8cddf0")
const AMBER = Color("efc477")
const RED = Color("ff9b86")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	queue_redraw()

func screen(point: Vector3) -> Vector2:
	return game.camera.unproject_position(point)

func _tag(at: Vector2, words: String, tint: Color) -> void:
	var lines = words.split("\n")
	var width = 0.0
	for line in lines: width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x)
	var extent = Vector2(width + 18, lines.size() * 19 + 10)
	var origin = at - Vector2(extent.x / 2, 0)
	origin.x = clampf(origin.x, size.x * 0.26 + 6, maxf(size.x * 0.26 + 6, size.x * 0.72 - extent.x - 6))
	origin.y = clampf(origin.y, 158, maxf(158, size.y * 0.83 - extent.y))
	var initial = origin
	for shift in [0, 1, -1, 2, -2, 3]:
		var candidate = initial + Vector2(0, shift * (extent.y + 10))
		candidate.y = clampf(candidate.y, 158, maxf(158, size.y * 0.83 - extent.y - 5))
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
	style.bg_color = Color(0.03, 0.055, 0.07, 0.94)
	style.border_color = Color(tint, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style

func _draw() -> void:
	label_rects.clear()
	if game == null or not is_instance_valid(game.player): return
	var tank = screen(game.player.position + Vector3.UP)
	label_rects.append(Rect2(tank - Vector2(19, 19), Vector2(38, 38)))
	# Label the actual player, and show which way its hull faces.
	draw_arc(tank, 16, 0, TAU, 40, BLUE, 2, true)
	var forward = screen(game.player.position - game.player.global_basis.z * 8 + Vector3.UP)
	draw_line(tank, forward, BLUE, 2, true)
	var arrow = (forward - tank).normalized()
	draw_colored_polygon(PackedVector2Array([forward + arrow * 5, forward - arrow.rotated(0.6) * 8, forward - arrow.rotated(-0.6) * 8]), BLUE)
	var gun_forward = screen(game.player.position - game.player.turret.global_basis.z * 13 + Vector3.UP)
	draw_line(tank, gun_forward, Color("b4edb2"), 3, true)
	draw_circle(gun_forward, 3, Color("b4edb2"))
	draw_string(font, gun_forward + Vector2(4, -4), "TURRET", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("b4edb2"))
	draw_string(font, forward + Vector2(4, 12), "HULL", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, BLUE)
	var activity = "YOUR TANK"
	if game.phase == "EXECUTION" and game.active_tank == game.player:
		if game.player.speed > 0.1: activity += " • MOVING"
		elif game.travel_target != null: activity += " • TURNING / WAITING"
		elif game.player.shot_pending: activity += " • AIMING / LOADING"
	_tag(tank + Vector2(0, 24), activity, BLUE)
	var contact: Dictionary = game.display_contact
	if not contact.is_empty():
		var center: Vector3 = game.contact_visual_position
		var radius: float = game.contact_visual_radius
		var ring = PackedVector2Array()
		for i in range(65):
			var angle = i * TAU / 64.0
			ring.append(screen(center + Vector3(cos(angle) * radius, 0.35, sin(angle) * radius)))
		var confirmed: bool = game.contact_is_visible()
		var tint = RED if confirmed else AMBER
		draw_colored_polygon(ring, Color(tint, 0.10))
		for i in range(64):
			if confirmed or i % 4 < 2: draw_line(ring[i], ring[i + 1], Color(tint, 0.85), 2, true)
		var middle = screen(center + Vector3.UP)
		label_rects.append(Rect2(middle - Vector2(14, 14), Vector2(28, 28)))
		draw_circle(middle, 11, Color(0.05, 0.07, 0.08, 0.95))
		draw_arc(middle, 11, 0, TAU, 32, tint, 2, true)
		draw_string(font, middle + Vector2(-4, 5), "!" if confirmed else "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, tint)
		var top = middle.y
		for point in ring: top = minf(top, point.y)
		_tag(Vector2(middle.x, top - 58), "CONTACT A • " + ("ENEMY SIGHTED" if confirmed else ("LAST SEEN" if contact.source == "Visual silhouette" else "POSSIBLE ENEMY")) + "\n" + ("Visual confirmation" if confirmed else "Dashed area = uncertain location"), tint)
	if game.travel_target != null:
		var destination = screen(game.travel_target + Vector3.UP * 0.4)
		label_rects.append(Rect2(destination - Vector2(14, 14), Vector2(28, 28)))
		draw_dashed_line(tank, destination, BLUE, 2, 7, true)
		draw_arc(destination, 10, 0, TAU, 32, BLUE, 2, true)
		draw_line(destination + Vector2(-6, 0), destination + Vector2(6, 0), BLUE, 2)
		draw_line(destination + Vector2(0, -6), destination + Vector2(0, 6), BLUE, 2)
		_tag(destination + Vector2(0, 20), "MOVE HERE • %.0f m\n%s" % [game.player.position.distance_to(game.travel_target), "Moving / turning" if game.phase == "EXECUTION" else "Queued for EXECUTE"], BLUE)
	if game.aim_selected or game.fields.fire.button_pressed:
		var point: Vector3 = game._planned_aim()
		var aim = screen(Vector3(point.x, 0.5, point.z))
		label_rects.append(Rect2(aim - Vector2(19, 19), Vector2(38, 38)))
		var fired: bool = game.phase == "EXECUTION" and game.fields.fire.button_pressed and not game.player.shot_pending
		var firing: bool = game.fields.fire.button_pressed and not fired
		var tint = RED if firing else BLUE
		if not fired: draw_dashed_line(tank, aim, Color(tint, 0.7), 1.5, 6, true)
		for offset in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			draw_line(aim + offset * 6, aim + offset * 15, tint, 2, true)
		var spread: float = maxf(0.3, game.player.position.distance_to(point) * game._dispersion(game.player) * 2)
		var ellipse = PackedVector2Array()
		for i in range(49):
			var angle = TAU * i / 48.0
			ellipse.append(screen(Vector3(point.x, 0.5, point.z) + Vector3(cos(angle) * spread, 0, sin(angle) * spread)))
		draw_polyline(ellipse, tint, 1, true)
		_tag(aim + Vector2(0, 25), "YOUR AIM POINT • FIRED" if fired else ("FIRE HERE • SHOT QUEUED" if firing else "WATCH THIS POINT"), tint)
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
		if start.distance_to(end) > 8:
			var arrow_tip = start.lerp(end, 0.65) + lane
			draw_colored_polygon(PackedVector2Array([arrow_tip + direction * 9, arrow_tip - direction.rotated(0.5) * 9, arrow_tip - direction.rotated(-0.5) * 9]), tint)
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
