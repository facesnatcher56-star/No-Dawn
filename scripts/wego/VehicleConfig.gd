extends RefCounted
class_name VehicleConfig
## Data-driven specification of vehicle capabilities, crew structure,
## stabilization systems, fire control, and ammunition loadouts.

const AmmunitionData = preload("res://scripts/wego/AmmunitionData.gd")

var vehicle_name: String = "A-47 Mastodon"

# Crew layout and assignments
var crew_layout: Array = [
	"Driver",
	"Gunner",
	"Loader",
	"Commander",
	"Radio operator"
]

# Data-driven crew substitution rules:
# Maps which crew stations can be filled by other surviving members
var crew_substitution: Dictionary = {
	"Commander": ["Gunner", "Loader"],       # Commander can step in as Gunner or Loader
	"Gunner": ["Loader"],                     # Gunner can load in an emergency
	"Radio operator": ["Driver", "Loader"],   # Radio op can take over Driver or Loader
	"Loader": ["Driver"]                      # Loader can transfer forward to drive
}

# Penalty factors applied when substituting:
var substitution_penalties: Dictionary = {
	"Loader": 3.5,     # 3.5x slower reload when Gunner/Commander has to load
	"Gunner": 1.6,     # 1.6x longer lay time when Commander takes gunner station
	"Driver_transfer_delay": 10.0 # Station transfer time in seconds (requires stationary tank)
}

# Gun stabilization system:
# "NONE"             - No stabilizer. Moving tank suffers severe aim disturbance and huge dispersion cone.
# "VERTICAL_ONLY"    - Elevation axis only (Sherman style). Pitch/bounce mitigated, yaw still disturbs aim.
# "BASIC_TWO_AXIS"   - Gyroscopic 2-axis stabilization (Mastodon/Centurion). Compensates moderate smooth speed.
# "MODERN_TWO_AXIS"  - Advanced computerized 2-axis mirror head stabilization. Smooth high-speed firing.
var gun_stabilization: String = "BASIC_TWO_AXIS"

# Traverse and elevation mechanical rates (degrees per second)
var turret_traverse_speed_deg: float = rad_to_deg(0.5) # 0.5 rad/s (approx 28.65 deg/s)
var gun_elevation_speed_deg: float = 14.0

# Commander systems
var commander_independent_sight: bool = true # Independent cupola/periscope (CITV capability)
var commander_weapon_override: bool = true   # Commander can lay gun or trigger fire

# Fire control quality modifier
var fire_control_quality: float = 1.0

# Loading system
var autoloader: bool = false
var reload_base_seconds: float = 6.5
var reload_floor_rack_seconds: float = 10.8
var allow_elevation_during_load: bool = true

# Available ammunition types
var available_ammunition: Array = []
var active_ammo_index: int = 0

func _init() -> void:
	available_ammunition = [
		AmmunitionData.create_apcbc(),
		AmmunitionData.create_apcr(),
		AmmunitionData.create_heat(),
		AmmunitionData.create_he()
	]

func get_active_ammo() -> AmmunitionData:
	if available_ammunition.is_empty():
		return AmmunitionData.create_apcbc()
	return available_ammunition[clampi(active_ammo_index, 0, available_ammunition.size() - 1)]

func set_active_ammo_by_id(id: String) -> bool:
	for i in range(available_ammunition.size()):
		if available_ammunition[i].id == id:
			active_ammo_index = i
			return true
	return false

# --- FACTORY METHODS FOR DISTINCT VEHICLE TYPES ---

static func create_mastodon() -> VehicleConfig:
	var cfg = (load("res://scripts/wego/VehicleConfig.gd") as GDScript).new()
	cfg.vehicle_name = "A-47 Mastodon"
	cfg.gun_stabilization = "BASIC_TWO_AXIS"
	cfg.turret_traverse_speed_deg = 24.0
	cfg.gun_elevation_speed_deg = 14.0
	cfg.commander_independent_sight = true
	cfg.commander_weapon_override = true
	cfg.fire_control_quality = 1.0
	cfg.reload_base_seconds = 6.5
	cfg.reload_floor_rack_seconds = 10.8
	return cfg

static func create_unstabilized(name: String = "Early WWII Heavy Tank") -> VehicleConfig:
	var cfg = (load("res://scripts/wego/VehicleConfig.gd") as GDScript).new()
	cfg.vehicle_name = name
	cfg.gun_stabilization = "NONE" # Unstabilized! Firing while moving heavily degraded
	cfg.turret_traverse_speed_deg = 14.0
	cfg.gun_elevation_speed_deg = 8.0
	cfg.commander_independent_sight = false # Cupola fixed with turret direction
	cfg.commander_weapon_override = false
	cfg.fire_control_quality = 0.75
	cfg.reload_base_seconds = 8.0
	cfg.reload_floor_rack_seconds = 13.5
	return cfg

static func create_modern(name: String = "Modern MBT") -> VehicleConfig:
	var cfg = (load("res://scripts/wego/VehicleConfig.gd") as GDScript).new()
	cfg.vehicle_name = name
	cfg.gun_stabilization = "MODERN_TWO_AXIS"
	cfg.turret_traverse_speed_deg = 42.0
	cfg.gun_elevation_speed_deg = 24.0
	cfg.commander_independent_sight = true
	cfg.commander_weapon_override = true
	cfg.fire_control_quality = 1.6
	cfg.autoloader = true
	cfg.reload_base_seconds = 5.0
	cfg.reload_floor_rack_seconds = 5.0
	return cfg
