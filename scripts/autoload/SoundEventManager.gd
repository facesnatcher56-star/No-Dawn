extends Node

signal sound_emitted(event_data: Dictionary)
signal masking_changed(is_masking: bool, level: float)

var listeners: Array = []
var recent_events: Array[Dictionary] = []
const MAX_DEBUG_EVENTS = 20

# Environmental masking (Steam hammer / blast machinery)
var masking_active: bool = false
var masking_level: float = 0.0 # 0.0 to 1.0

func _process(delta: float) -> void:
	# Prune stale debug events older than 8 seconds
	var now = Time.get_ticks_msec() / 1000.0
	for i in range(recent_events.size() - 1, -1, -1):
		if now - recent_events[i].time > 8.0:
			recent_events.remove_at(i)

func register_listener(node: Node) -> void:
	if not listeners.has(node):
		listeners.append(node)

func unregister_listener(node: Node) -> void:
	listeners.erase(node)

func set_masking(active: bool, level: float = 1.0) -> void:
	masking_active = active
	masking_level = clampf(level, 0.0, 1.0)
	masking_changed.emit(masking_active, masking_level)

func emit_sound(global_pos: Vector3, loudness: float, category: String, source_entity: Node = null, extra: Dictionary = {}) -> void:
	var now = Time.get_ticks_msec() / 1000.0

	# Apply environmental masking to acoustic sounds (engine, tracks)
	var effective_loudness = loudness
	if masking_active and (category.begins_with("engine") or category == "tracks"):
		effective_loudness *= (1.0 - masking_level * 0.70)

	var event_record = {
		"pos": global_pos,
		"loudness": effective_loudness,
		"base_loudness": loudness,
		"category": category,
		"source": source_entity,
		"time": now
	}
	recent_events.append(event_record)
	if recent_events.size() > MAX_DEBUG_EVENTS:
		recent_events.pop_front()

	sound_emitted.emit(event_record)

	# Distribute to listeners
	for listener in listeners:
		if not is_instance_valid(listener):
			continue
		if listener == source_entity:
			continue

		var listener_pos = listener.global_position
		var dist = listener_pos.distance_to(global_pos)

		# Check listener sensitivity modifier
		var sensitivity = 1.0
		if listener.has_method("get_hearing_sensitivity"):
			sensitivity = listener.get_hearing_sensitivity()

		var max_range = effective_loudness * sensitivity
		if dist <= max_range:
			# Calculate bearing and uncertainty
			var to_source = (global_pos - listener_pos)
			to_source.y = 0.0
			if to_source.length_squared() < 0.1:
				continue

			var true_bearing_deg = fposmod(rad_to_deg(atan2(-to_source.x, -to_source.z)), 360.0)

			# Angular uncertainty depends on distance/range ratio and listener mode
			var dist_ratio = clampf(dist / max_range, 0.1, 1.0)
			var base_error_deg = 20.0 * dist_ratio
			if sensitivity > 1.5: # e.g. Listening mode
				base_error_deg *= 0.35
			elif sensitivity < 0.8: # combat mode
				base_error_deg *= 1.4

			var bearing_error = randf_range(-base_error_deg, base_error_deg)
			var estimated_bearing = fposmod(true_bearing_deg + bearing_error, 360.0)

			# Range estimation (crude brackets)
			var est_min: float
			var est_max: float
			var range_fuzz = randf_range(0.8, 1.25)
			var perceived_dist = dist * range_fuzz

			if dist < 60.0:
				est_min = maxf(10.0, perceived_dist - 20.0)
				est_max = perceived_dist + 30.0
			elif dist < 200.0:
				est_min = maxf(40.0, perceived_dist - 50.0)
				est_max = perceived_dist + 80.0
			else:
				est_min = maxf(100.0, perceived_dist - 120.0)
				est_max = perceived_dist + 160.0

			var est_dist_mid = (est_min + est_max) * 0.5
			var est_rad = deg_to_rad(estimated_bearing)
			var est_dir = Vector3(-sin(est_rad), 0, -cos(est_rad))
			var estimated_pos = listener_pos + est_dir * est_dist_mid

			# Initial uncertainty radius
			var uncert_radius = (est_max - est_min) * 0.6

			var perception = {
				"source_entity": source_entity,
				"category": category,
				"true_pos": global_pos,
				"listener_pos": listener_pos,
				"estimated_pos": estimated_pos,
				"bearing_deg": estimated_bearing,
				"bearing_arc": maxf(10.0, base_error_deg * 2.0),
				"est_range_min": est_min,
				"est_range_max": est_max,
				"uncertainty_radius": uncert_radius,
				"confidence": clampf(1.0 - (dist / max_range) * 0.6, 0.25, 0.9),
				"time": now
			}

			if listener.has_method("on_sound_perceived"):
				listener.on_sound_perceived(perception)
