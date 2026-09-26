extends RefCounted
class_name Observation
## Represents a single discrete reconnaissance or sensory observation event.

var time: float = 0.0
var observer_position: Vector3 = Vector3.ZERO
var source: String = "Unconfirmed" # "Visual silhouette", "Commander optics", "Gunner sight", "Engine noise", "Gun report", "Cross-bearing fix", "Observed impact"
var bearing_deg: float = 0.0
var bearing_arc_deg: float = 10.0
var range_m: float = 0.0
var range_uncertainty_m: float = 50.0
var target_position: Vector3 = Vector3.ZERO
var position_uncertainty_m: float = 30.0
var target_heading_deg: float = 0.0
var heading_uncertainty_deg: float = 45.0
var target_speed_mps: float = 0.0
var speed_uncertainty_mps: float = 5.0
var target_classification: String = "Unconfirmed contact"
var is_direct_visual: bool = false
var observer_name: String = ""
var target_name: String = ""

func _init(
	p_time: float = 0.0,
	p_observer_pos: Vector3 = Vector3.ZERO,
	p_source: String = "Unconfirmed",
	p_bearing: float = 0.0,
	p_arc: float = 10.0,
	p_range: float = 0.0,
	p_range_unc: float = 50.0,
	p_target_pos: Vector3 = Vector3.ZERO,
	p_pos_unc: float = 30.0
) -> void:
	time = p_time
	observer_position = p_observer_pos
	source = p_source
	bearing_deg = p_bearing
	bearing_arc_deg = p_arc
	range_m = p_range
	range_uncertainty_m = p_range_unc
	target_position = p_target_pos
	position_uncertainty_m = p_pos_unc

func to_dict() -> Dictionary:
	return {
		"time": time,
		"observer_position": observer_position,
		"source": source,
		"bearing": bearing_deg,
		"arc": bearing_arc_deg,
		"range": range_m,
		"range_uncertainty": range_uncertainty_m,
		"position": target_position,
		"uncertainty": position_uncertainty_m,
		"heading": target_heading_deg,
		"heading_uncertainty": heading_uncertainty_deg,
		"speed": target_speed_mps,
		"speed_uncertainty": speed_uncertainty_mps,
		"classification": target_classification,
		"is_visual": is_direct_visual
	}
