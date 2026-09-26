extends RefCounted
## All distances are metres, armor is mm RHA, energy is joules.
## Deliberately approximate energy/armor relation, not historical ammunition data.
const Damage = preload("res://scripts/wego/DamageReport.gd")
const AmmunitionData = preload("res://scripts/wego/AmmunitionData.gd")
const BallisticsModel = preload("res://scripts/wego/BallisticsModel.gd")
const MASS = 6.8
const MUZZLE_SPEED = 740.0
var plates: Array = []
var modules: Array = []
var crew: Array = []
var turret_yaw = 0.0
var rounds = 25
var rack_counts = {"Ready rack": 6, "Floor rack": 19, "Overflow rack": 0}
var reload = 0.0
var fire_seconds = 0.0
var burning = false
var catastrophic = false
var transfer: Dictionary = {}

func _init(ammunition: int = 25) -> void:
	set_loadout(ammunition)
	# Sloped glacis is an oriented physical plate, shared with the renderer.
	_plate("Glacis", Vector3(0, 1.25, -2.9), Vector3(3.4, 1.85, 0.07), 70.0, deg_to_rad(-18), false, "RHA")
	_plate("Rear", Vector3(0, 1.25, 2.9), Vector3(3.4, 1.85, 0.04), 40.0, 0.0, false, "RHA")
	_plate("Left hull", Vector3(-1.7, 1.25, 0), Vector3(0.04, 1.85, 6.4), 40.0, 0.0, false, "RHA")
	_plate("Right hull", Vector3(1.7, 1.25, 0), Vector3(0.04, 1.85, 6.4), 40.0, 0.0, false, "RHA")
	_plate("Deck", Vector3(0, 2.16, 0), Vector3(3.4, 0.02, 6.4), 20.0, 0.0, false, "RHA")
	_plate("Floor", Vector3(0, 0.33, 0), Vector3(3.4, 0.02, 6.4), 20.0, 0.0, false, "RHA")
	_plate("Turret front", Vector3(0, 2.65, -1.25), Vector3(2.5, 1, 0.08), 80.0, 0, true, "CAST")
	_plate("Turret rear", Vector3(0, 2.65, 1.25), Vector3(2.5, 1, 0.04), 40.0, 0, true, "RHA")
	_plate("Turret left", Vector3(-1.25, 2.65, 0), Vector3(0.05, 1, 2.5), 50.0, 0, true, "RHA")
	_plate("Turret right", Vector3(1.25, 2.65, 0), Vector3(0.05, 1, 2.5), 50.0, 0, true, "RHA")
	_plate("Turret roof", Vector3(0, 3.15, 0), Vector3(2.5, 0.02, 2.5), 20.0, 0, true, "RHA")
	_module("Transmission", Vector3(0, 0.75, -2.3), Vector3(2.7, 0.65, 0.65), 130000)
	_module("Engine", Vector3(0, 1.1, 2.1), Vector3(2.2, 1.1, 1.3), 200000)
	_module("Fuel line", Vector3(1.35, 1.1, 2.1), Vector3(0.35, 1.2, 1.4), 15000)
	_module("Firewall", Vector3(0, 1.25, 1.35), Vector3(3.3, 1.8, 0.06), 90000)
	_module("Ready rack", Vector3(-1.25, 1.4, 0.5), Vector3(0.5, 1, 1), 25000)
	_module("Floor rack", Vector3(0, 0.6, 0.4), Vector3(1.7, 0.4, 1.2), 50000)
	_module("Overflow rack", Vector3(1.25, 1.4, 0.5), Vector3(0.5, 1, 1), 25000)
	_module("Breech", Vector3(0, 2.6, -0.4), Vector3(0.6, 0.65, 1.1), 160000, true)
	_module("Gunsight", Vector3(-0.65, 2.9, -1.1), Vector3(0.3, 0.3, 0.3), 10000, true)
	_module("Commander optics", Vector3(0.65, 3, 0.55), Vector3(0.35, 0.3, 0.35), 10000, true)
	_module("Radio", Vector3(1.3, 1.8, -1.4), Vector3(0.35, 0.4, 0.5), 15000)
	_module("Searchlight", Vector3(1, 2.9, -1.3), Vector3(0.3, 0.3, 0.35), 10000, true)
	_module("Turret drive", Vector3(0, 1.8, -0.2), Vector3(0.8, 0.4, 0.8), 60000, true)
	for spec in [["Driver", Vector3(-0.8, 1.45, -1.85), false], ["Radio operator", Vector3(0.8, 1.45, -1.85), false], ["Gunner", Vector3(-0.65, 2.5, -0.35), true], ["Commander", Vector3(0.65, 2.5, 0.55), true], ["Loader", Vector3(-0.7, 1.55, 0.2), false]]:
		crew.append({"name": spec[0], "station": spec[0], "state": "Fit"})
		_module(spec[0], spec[1], Vector3(0.5, 0.85, 0.5), 45000, spec[2], true)

func _plate(label: String, pos: Vector3, size: Vector3, mm: float, slope = 0.0, turret = false, material: String = "RHA") -> void:
	plates.append({"name": label, "pose": Transform3D(Basis(Vector3.RIGHT, slope), pos), "size": size, "mm": mm, "turret": turret, "material": material})

func _module(label: String, pos: Vector3, size: Vector3, resistance: float, turret = false, person = false) -> void:
	modules.append({"name": label, "pose": Transform3D(Basis.IDENTITY, pos), "size": size, "resistance": resistance, "turret": turret, "crew": person, "state": "Functional"})

func pose(volume: Dictionary) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, turret_yaw), Vector3.ZERO) * volume.pose if volume.turret else volume.pose

static func intersect(origin: Vector3, direction: Vector3, transform: Transform3D, size: Vector3) -> Dictionary:
	var inv = transform.affine_inverse()
	var p = inv * origin
	var d = inv.basis * direction
	var near = -INF
	var far = INF
	var normal = Vector3.ZERO
	for axis in range(3):
		if absf(d[axis]) < 0.000001:
			if absf(p[axis]) > size[axis] * 0.5:
				return {}
			continue
		var a = (-size[axis] * 0.5 - p[axis]) / d[axis]
		var b = (size[axis] * 0.5 - p[axis]) / d[axis]
		if minf(a, b) > near:
			near = minf(a, b)
			normal = Vector3.ZERO
			normal[axis] = -signf(d[axis])
		far = minf(far, maxf(a, b))
		if near > far:
			return {}
	if far < 0:
		return {}
	return {"t": maxf(0, near), "exit": far, "normal": (transform.basis * normal).normalized()}

func occupied(station: String) -> bool:
	for member in crew:
		if member.station == station and member.state in ["Fit", "Wounded", "Seriously wounded"]:
			return true
	return false

func functional(label: String) -> bool:
	for module in modules:
		if module.name == label:
			return module.state == "Functional"
	return false

func can_move() -> bool:
	return not catastrophic and occupied("Driver") and functional("Engine") and functional("Transmission")

func can_fire() -> bool:
	return not catastrophic and occupied("Gunner") and functional("Breech") and rounds > 0

func status() -> String:
	if catastrophic: return "Catastrophic loss"
	var survivors = crew.filter(func(c): return c.state in ["Fit", "Wounded", "Seriously wounded"])
	if survivors.is_empty(): return "Crew lost"
	if not functional("Breech"): return "Combat ineffective"
	if not can_move(): return "Immobilized"
	if burning or survivors.size() < 5 or modules.any(func(m): return m.state != "Functional"): return "Degraded"
	return "Operational"

func reassign(person: int, station: String) -> bool:
	if not transfer.is_empty() or occupied(station) or crew[person].state not in ["Fit", "Wounded", "Seriously wounded"]:
		return false
	crew[person].station = "Transferring"
	transfer = {"person": person, "station": station, "remaining": 10.0}
	return true

func step(delta: float, extinguish: bool) -> void:
	if catastrophic: return
	if not transfer.is_empty():
		transfer.remaining -= delta
		if transfer.remaining <= 0:
			var c = crew[transfer.person]
			if c.state in ["Fit", "Wounded", "Seriously wounded"]: c.station = transfer.station
			transfer = {}
	if can_fire() and (occupied("Loader") or occupied("Gunner")) and not extinguish:
		reload = maxf(0, reload - delta / (1.0 if occupied("Loader") else 3.8))
	if burning:
		if extinguish and occupied("Loader"):
			fire_seconds = maxf(0, fire_seconds - delta * 3)
			if fire_seconds <= 0: burning = false
		else:
			fire_seconds += delta
			if fire_seconds > (35.0 if functional("Firewall") else 12.0): catastrophic = true

func set_loadout(ammunition: int) -> void:
	rounds = ammunition
	rack_counts = {"Ready rack": mini(6, rounds), "Floor rack": clampi(rounds - 6, 0, 19), "Overflow rack": maxi(0, rounds - 25)}

func consume_round() -> void:
	if rounds <= 0: return
	for rack in ["Ready rack", "Floor rack", "Overflow rack"]:
		if rack_counts[rack] > 0:
			rack_counts[rack] -= 1
			rounds -= 1
			break
	reload = 6.5 if rack_counts["Ready rack"] > 0 else 10.8

func rack_filled(label: String) -> bool:
	return rack_counts.get(label, 0) > 0

func resolve(origin: Vector3, direction: Vector3, speed: float, seed_value: int, ammo: AmmunitionData = null, range_m: float = -1.0) -> Dictionary:
	var before = Damage.snapshot(self)
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	var result = {"paths": [], "effects": [], "strikes": [], "impacts": [], "volumes": [], "speed": speed, "result": "MISS", "seed": seed_value}
	for v in plates + modules:
		result.volumes.append({"name": v.name, "pose": pose(v), "size": v.size, "armor": v.has("mm"), "crew": v.get("crew", false)})
	var p_mass = ammo.mass_kg if ammo != null else MASS
	var energy = 0.5 * p_mass * speed * speed
	var r = range_m if range_m >= 0.0 else maxf(10.0, origin.length())
	_trace(origin, direction.normalized(), energy, false, result, rng, ammo, r)
	result.damage = Damage.summarize(before, Damage.snapshot(self))
	if ammo != null:
		result.debug_report = BallisticsModel.format_debug_report(result, ammo)
	return result

func _trace(origin: Vector3, dir: Vector3, energy: float, fragment: bool, result: Dictionary, rng: RandomNumberGenerator, ammo: AmmunitionData = null, range_m: float = 10.0) -> void:
	var hits: Array = []
	for v in plates + modules:
		if v.name.ends_with("rack") and not rack_filled(v.name): continue
		if v.get("crew", false) and not crew.any(func(c): return c.station == v.name): continue
		var hit = intersect(origin, dir, pose(v), v.size)
		if not hit.is_empty():
			hit.volume = v
			hits.append(hit)
	hits.sort_custom(func(a, b): return a.t < b.t)
	var start = origin
	var entered = fragment
	for hit in hits:
		var v = hit.volume
		var point: Vector3 = origin + dir * hit.t
		if v.has("mm"):
			var cosine = maxf(0.05, absf(dir.dot(hit.normal)))
			var effective: float = v.mm / cosine
			var angle = rad_to_deg(acos(clampf(cosine, 0, 1)))
			var outcome = "STOPPED"
			var cost: float = 0.0
			var is_ricochet = false
			
			if ammo != null:
				var eval = BallisticsModel.evaluate_plate_impact(v, dir, hit.normal, point, ammo, range_m, energy, rng)
				outcome = eval.outcome
				effective = eval.effective
				angle = eval.impact_angle
				is_ricochet = (outcome == "RICOCHET")
				cost = energy * clampf(effective / maxf(1.0, eval.nominal_penetration), 0.1, 1.0)
			else:
				# Legacy formula for 100% backward compatibility with existing tests
				cost = effective / 140.0 * (0.5 * MASS * MUZZLE_SPEED * MUZZLE_SPEED)
				outcome = "PENETRATION" if energy > cost else "STOPPED"
				if angle > 72 and not fragment: outcome = "RICOCHET"
				is_ricochet = (outcome == "RICOCHET")
				
			if not fragment:
				var impact_entry = {"position": point, "normal": hit.normal, "plate": v.name, "mm": v.mm, "effective": effective, "angle": angle, "energy_in": energy, "outcome": outcome, "is_ricochet": is_ricochet}
				if ammo != null:
					impact_entry["material"] = v.get("material", "RHA")
					impact_entry["nominal_penetration"] = ammo.get_penetration_at_range(range_m)
					impact_entry["striking_velocity"] = ammo.get_velocity_at_range(range_m)
					impact_entry["residual_penetration_mm"] = maxf(0.0, impact_entry["nominal_penetration"] - effective) if outcome == "PENETRATION" else 0.0
				result.impacts.append(impact_entry)
				if result.impacts.size() == 1: result.result = outcome
			if fragment or outcome != "PENETRATION":
				result.paths.append({"from": start, "to": point, "fragment": fragment})
				if is_ricochet and not fragment: result.paths.append({"from": point, "to": point + dir.bounce(hit.normal) * 4, "fragment": false})
				return
			energy -= cost
			if not fragment:
				result.impacts.back()["energy_out"] = energy
				result.impacts.back()["residual_speed"] = sqrt(2 * energy / (ammo.mass_kg if ammo != null else MASS))
			if not entered:
				# Fragment directions and energy are resolved here once; viewer never rolls dice.
				var fragment_energy = minf(energy * 0.18, 180000.0)
				energy -= fragment_energy
				var inside: Vector3 = origin + dir * (hit.exit + 0.002)
				var frag_count = ammo.spall_fragment_count if ammo != null else 18
				var frag_spread = ammo.spall_cone_rad if ammo != null else 0.38
				for i in range(frag_count):
					var spread = Vector3(rng.randf_range(-frag_spread, frag_spread), rng.randf_range(-frag_spread, frag_spread), rng.randf_range(-frag_spread, frag_spread))
					_trace(inside, (dir + spread).normalized(), fragment_energy / frag_count, true, result, rng, ammo, range_m)
			entered = true
		elif entered:
			var stop_fraction = minf(1.0, energy / float(v.resistance))
			result.strikes.append({"volume": v.name, "position": point, "energy": energy, "fragment": fragment})
			_apply_hit(v, energy, fragment, result)
			if energy <= v.resistance:
				var end: Vector3 = point + dir * (hit.exit - hit.t) * stop_fraction
				result.paths.append({"from": start, "to": end, "fragment": fragment})
				return
			energy -= v.resistance
	result.paths.append({"from": start, "to": origin + dir * (9 if fragment else 14), "fragment": fragment})

func _apply_hit(v: Dictionary, energy: float, fragment: bool, result: Dictionary) -> void:
	var effect = ""
	if v.crew:
		for c in crew:
			if c.station != v.name: continue
			var states = ["Fit", "Wounded", "Seriously wounded", "Incapacitated", "Dead"]
			var next_state = "Incapacitated" if not fragment or energy > 6500 else "Wounded"
			if energy > 60000: next_state = "Dead"
			if states.find(next_state) > states.find(c.state): c.state = next_state
			effect = c.name + " — " + c.state
	else:
		v.state = "Disabled"
		effect = v.name + " — disabled"
		if v.name == "Fuel line":
			burning = true
			fire_seconds = maxf(4, fire_seconds)
			effect = "Fuel line — perforated; engine compartment fire"
		if v.name.ends_with("rack") and rack_filled(v.name):
			catastrophic = true
			effect = v.name + " — ammunition detonation"
	if not effect.is_empty() and not result.effects.has(effect): result.effects.append(effect)
