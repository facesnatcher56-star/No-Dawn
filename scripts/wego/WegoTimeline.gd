extends RefCounted
class_name WegoTimeline
## Manages synchronized simulation time, tactical pulse modes (8s Maneuver vs 3s Combat),
## and ensures simultaneous execution across both friendly and enemy forces.

enum PulseMode {
	MANEUVER = 0, # ~8.0s execution pulses for positioning and quiet patrol
	COMBAT = 1    # ~3.0s execution pulses for high-intensity direct engagement
}

const MANEUVER_DURATION: float = 8.0
const COMBAT_DURATION: float = 3.0

var current_mode: PulseMode = PulseMode.MANEUVER
var pulse_duration: float = MANEUVER_DURATION
var pulse_time_left: float = 0.0
var sim_time: float = 0.0
var is_executing: bool = false
var pulse_number: int = 1

func evaluate_mode(
	player_track,
	enemy_track,
	recent_gunfire: bool,
	recent_hit: bool,
	direct_engagement: bool = false
) -> PulseMode:
	# Check if active hostile contact or direct engagement exists
	var player_has_threat = player_track != null and (
		player_track.has_visual_los or
		player_track.time_since_visual < 6.0 or
		player_track.range_uncertainty < 30.0
	)
	var enemy_has_threat = enemy_track != null and (
		enemy_track.has_visual_los or
		enemy_track.time_since_visual < 6.0
	)
	
	if direct_engagement or player_has_threat or enemy_has_threat or recent_gunfire or recent_hit:
		return PulseMode.COMBAT
	return PulseMode.MANEUVER

func start_pulse(mode: PulseMode) -> void:
	current_mode = mode
	pulse_duration = COMBAT_DURATION if mode == PulseMode.COMBAT else MANEUVER_DURATION
	pulse_time_left = pulse_duration
	is_executing = true

func step_pulse(delta: float) -> float:
	if not is_executing or pulse_time_left <= 0.00001:
		return 0.0
	var dt = minf(delta, pulse_time_left)
	sim_time += dt
	pulse_time_left = maxf(0.0, pulse_time_left - dt)
	return dt

func complete_pulse() -> void:
	is_executing = false
	pulse_number += 1

func is_pulse_finished() -> bool:
	return pulse_time_left <= 0.0001
