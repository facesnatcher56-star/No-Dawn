extends RefCounted
## Wall-clock presentation is separate from fixed-step combat simulation.
const STEP = 1.0 / 60.0
const IMPACT_DURATION = 6.5
const SHOT_SPEED = 0.08
var speed = 0.5
var paused = false
var accumulator = 0.0
var shot_focus = 0.0
var pending: Array[Dictionary] = []
var active: Dictionary = {}
var replay_time = 0.0

func rate() -> float:
	if paused or not active.is_empty() or not pending.is_empty(): return 0.0
	return minf(speed, SHOT_SPEED) if shot_focus > 0 else speed

func feed(delta: float) -> void:
	if paused: return
	if not active.is_empty():
		replay_time = minf(IMPACT_DURATION, replay_time + delta)
		return
	var current_rate = rate()
	shot_focus = maxf(0, shot_focus - delta)
	accumulator += delta * current_rate

func take_step() -> bool:
	if paused or not active.is_empty() or not pending.is_empty(): return false
	if accumulator + 0.0000001 < STEP: return false
	accumulator = maxf(0, accumulator - STEP)
	return true

func shot_fired() -> void:
	shot_focus = maxf(shot_focus, 1.2)
	# Do not spend already-budgeted fast time after a shot begins slow motion.
	accumulator = 0.0

func enqueue(record: Dictionary) -> void:
	pending.append(record.duplicate(true))

func start_next() -> Dictionary:
	if not active.is_empty() or pending.is_empty(): return {}
	active = pending.pop_front()
	replay_time = 0.0
	accumulator = 0.0
	return active

func finish_replay() -> void:
	active = {}
	replay_time = 0.0
	accumulator = 0.0

func restart_replay() -> void:
	replay_time = 0.0

func busy() -> bool:
	return not active.is_empty() or not pending.is_empty()
