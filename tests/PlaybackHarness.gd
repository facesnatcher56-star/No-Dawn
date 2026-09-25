extends RefCounted

static func finish_turn(game) -> bool:
	# Advance wall-clock presentation quickly while preserving 60 Hz sim ticks.
	for i in range(900):
		if game.phase != "EXECUTION": return true
		await game.get_tree().physics_frame
		game._physics_process(0.1)
	return false
