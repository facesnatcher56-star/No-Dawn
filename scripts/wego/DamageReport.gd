extends RefCounted
## Snapshots describe this shot, even when inspected after later damage.
static func snapshot(model) -> Dictionary:
	var states = {}
	var stations = {}
	for module in model.modules:
		if not module.crew: states[module.name] = module.state
	for person in model.crew:
		states[person.name] = person.state
		stations[person.name] = person.station
	return {"states": states, "stations": stations, "racks": model.rack_counts.duplicate(), "move": model.can_move(), "fire": model.can_fire(), "loader": model.occupied("Loader"), "optics": not model.catastrophic and model.functional("Commander optics") and model.occupied("Commander"), "burning": model.burning, "catastrophic": model.catastrophic, "status": model.status()}

static func consequence(name: String, state: String) -> String:
	match name:
		"Engine", "Transmission": return "Tank cannot move."
		"Breech": return "Main gun cannot fire."
		"Gunsight": return "Shots become much less accurate."
		"Commander optics": return "Visual spotting unavailable."
		"Searchlight": return "Searchlight scans unavailable."
		"Fuel line": return "Engine compartment burning; assign the loader to fight the fire."
		"Firewall": return "Engine fires can spread much faster."
		"Radio": return "Radio disabled; no additional combat penalty."
	if name.ends_with("rack"): return "Ammunition storage struck."
	if state in ["Incapacitated", "Dead"]:
		match name:
			"Driver": return "Driver lost; movement needs a replacement."
			"Gunner": return "Gunner lost; firing needs a replacement."
			"Loader": return "Reload takes 3.8× as long without a loader."
			"Commander": return "Visual spotting unavailable without a commander."
		return "Crew member can no longer operate a station."
	if name == "Gunner": return "Gunner wounded; shot accuracy reduced."
	return "Crew member remains able to operate a station."

static func summarize(before: Dictionary, after: Dictionary) -> Dictionary:
	var changes: Array[Dictionary] = []
	for name in after.states:
		if before.states.get(name) == after.states[name]: continue
		var effect = consequence(after.stations.get(name, name), after.states[name])
		if name.ends_with("rack") and after.catastrophic and after.racks.get(name, 0) > 0:
			effect = "Ammunition detonated; tank knocked out."
		changes.append({"name": name, "state": after.states[name], "effect": effect})
	var capabilities: Array[String] = []
	capabilities.append("MOVEMENT  " + ("Available" if after.move else "Unavailable"))
	capabilities.append("MAIN GUN  " + ("Available" if after.fire else "Unavailable"))
	capabilities.append("RELOAD  " + (("Normal crew rate" if after.loader else "3.8× slower · loader unavailable") if after.fire else "Unavailable"))
	capabilities.append("SPOTTING  " + ("Optics available" if after.optics else "Visual spotting unavailable"))
	if after.burning: capabilities.append("FIRE  Engine compartment burning")
	return {"changes": changes, "capabilities": capabilities, "status": after.status, "catastrophic": after.catastrophic, "new_fire": after.burning and not before.burning}

static func text(report: Dictionary) -> String:
	if report.is_empty(): return "No system report recorded."
	var lines: Array[String] = []
	if report.catastrophic: lines.append("TANK KNOCKED OUT · catastrophic damage")
	elif report.changes.is_empty() and not report.new_fire: lines.append("No new crew or system damage.")
	if report.new_fire: lines.append("ENGINE FIRE · newly ignited")
	for change in report.changes:
		lines.append(change.name.to_upper() + " · " + change.state + "\n" + change.effect)
	return "\n\n".join(lines)
