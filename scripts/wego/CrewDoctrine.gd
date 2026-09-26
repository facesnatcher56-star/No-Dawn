extends RefCounted
class_name CrewDoctrine
## Stores and evaluates crew standing operating procedures (SOP).
## Reaction decisions are strictly governed by information the crew actually possesses.

enum ContactReaction {
	HOLD_ORDERS = 0,
	HALT_AND_TRACK = 1,
	CONTINUE_AND_TRACK = 2,
	REVERSE_COVER = 3,
	REMAIN_CONCEALED = 4
}

enum FiredUponReaction {
	CONTINUE_ORDERS = 0,
	HALT = 1,
	REVERSE = 2,
	SEEK_COVER = 3
}

enum FireAuthority {
	HOLD_FIRE = 0,
	CONFIRMED_ONLY = 1,
	FIRE_WHEN_READY = 2,
	RETURN_FIRE = 3
}

var on_contact: ContactReaction = ContactReaction.CONTINUE_AND_TRACK
var on_fired_upon: FiredUponReaction = FiredUponReaction.HALT
var fire_authority: FireAuthority = FireAuthority.HOLD_FIRE

func duplicate_doctrine() -> RefCounted:
	var copy = (load("res://scripts/wego/CrewDoctrine.gd") as GDScript).new()
	copy.on_contact = on_contact
	copy.on_fired_upon = on_fired_upon
	copy.fire_authority = fire_authority
	return copy

func evaluate(
	tank,
	track,
	was_hit: bool,
	fired_upon: bool,
	sol_quality: String = "POOR"
) -> Dictionary:
	var result = {
		"halt_movement": false,
		"reverse_movement": false,
		"track_target": false,
		"stop_engine": false,
		"fire_authorized": false,
		"notice": ""
	}
	
	if tank == null:
		return result
		
	# 1. Fired upon reaction (highest priority)
	if was_hit or fired_upon:
		match on_fired_upon:
			FiredUponReaction.HALT:
				result["halt_movement"] = true
				result["notice"] = "SOP: Fired upon -> Halting vehicle"
			FiredUponReaction.REVERSE, FiredUponReaction.SEEK_COVER:
				result["reverse_movement"] = true
				result["notice"] = "SOP: Fired upon -> Reversing to cover"
			FiredUponReaction.CONTINUE_ORDERS:
				pass
				
	# 2. Unexpected contact reaction (only if track exists and is active)
	elif track != null and (track.has_visual_los or track.time_since_visual < 4.0):
		match on_contact:
			ContactReaction.HALT_AND_TRACK:
				result["halt_movement"] = true
				result["track_target"] = true
				result["notice"] = "SOP: Contact -> Halting & tracking target"
			ContactReaction.CONTINUE_AND_TRACK:
				result["track_target"] = true
				result["notice"] = "SOP: Contact -> Tracking target on the move"
			ContactReaction.REVERSE_COVER:
				result["reverse_movement"] = true
				result["notice"] = "SOP: Contact -> Reversing toward cover"
			ContactReaction.REMAIN_CONCEALED:
				result["halt_movement"] = true
				result["stop_engine"] = true
				result["notice"] = "SOP: Contact -> Holding position concealed"
			ContactReaction.HOLD_ORDERS:
				pass
				
	# 3. Fire authority evaluation
	if track != null and tank.model.can_fire() and tank.model.reload <= 0.0:
		match fire_authority:
			FireAuthority.HOLD_FIRE:
				result["fire_authorized"] = false
			FireAuthority.CONFIRMED_ONLY:
				if track.has_visual_los and track.identification_confidence >= 0.7:
					result["fire_authorized"] = true
			FireAuthority.FIRE_WHEN_READY:
				if sol_quality in ["ACQUIRED", "OPTIMAL"]:
					result["fire_authorized"] = true
			FireAuthority.RETURN_FIRE:
				if (was_hit or fired_upon) and (track.has_visual_los or track.time_since_visual < 3.0):
					result["fire_authorized"] = true
					
	return result
