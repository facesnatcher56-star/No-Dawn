extends RefCounted
class_name ReconCue
## Evidence of a phenomenon, never a resolved vehicle or a hidden world position.
var cue_id: String = ""
var source: String = "Commander"
var source_type: String = "VISUAL"
var timestamp: float = 0.0
var observer_position: Vector3 = Vector3.ZERO
var bearing_deg: float = 0.0
var bearing_uncertainty: float = 15.0
var category: String = "MOVEMENT"
var strength: float = 0.5
var persistence: float = 18.0
var confidence: float = 0.5
var distance_category: String = "UNKNOWN RANGE"

func is_expired(now: float) -> bool:
	return now - timestamp > persistence

func label(hull_bearing: float = 0.0) -> String:
	var clock_hour = posmod(roundi((bearing_deg - hull_bearing) / 30.0), 12)
	if clock_hour == 0: clock_hour = 12
	return "%s REPORTED\n%d O'CLOCK • %s" % [category.replace("_", " "), clock_hour, distance_category]
