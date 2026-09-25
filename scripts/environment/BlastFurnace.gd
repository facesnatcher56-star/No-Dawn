extends Node3D
class_name BlastFurnace

@onready var furnace_light: OmniLight3D = $FurnaceLight
var time_accum: float = 0.0

func _process(delta: float) -> void:
	time_accum += delta
	if furnace_light:
		# Pulsing molten iron glow
		furnace_light.light_energy = 5.0 + sin(time_accum * 3.5) * 1.2 + randf_range(-0.3, 0.3)
