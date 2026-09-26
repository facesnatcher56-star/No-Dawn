extends RefCounted
class_name AmmunitionData
## Data-driven ammunition characteristics and aerodynamic/ballistic penetration models.
## Distinguishes kinetic (KE) projectiles (which lose velocity and penetration to drag over range)
## from chemical-energy (HEAT/HE) projectiles (whose penetration depends on shaped charge / explosive mass,
## not striking velocity).

enum Category {
	KINETIC,
	CHEMICAL
}

var id: String = "APCBC_92"
var name: String = "92mm APCBC Pzgr. 39"
var category: Category = Category.KINETIC
var mass_kg: float = 10.2
var muzzle_velocity: float = 880.0 # m/s
var drag_coeff: float = 0.00032 # Aerodynamic drag deceleration factor: dv/dt = -drag_coeff * v^2

# Penetration table: Array of [range_m, penetration_mm_rha]
# For KINETIC ammunition, penetration degrades with range as drag robs projectile of velocity.
# For CHEMICAL ammunition, penetration is flat across range.
var penetration_table: Array = [
	[0.0, 215.0],
	[500.0, 195.0],
	[1000.0, 175.0],
	[1500.0, 155.0],
	[2000.0, 135.0]
]

# Impact geometry parameters
var normalization_deg: float = 3.5 # Armor slope normalization (sharpens angle against sloped plate)
var ricochet_start_deg: float = 70.0 # Angle at which ricochet chance begins
var ricochet_guaranteed_deg: float = 80.0 # Angle above which ricochet is guaranteed
var spall_cone_rad: float = 0.40
var spall_fragment_count: int = 18

func get_penetration_at_range(range_m: float) -> float:
	var r = maxf(0.0, range_m)
	if category == Category.CHEMICAL:
		# Chemical shaped-charge penetration is velocity-independent!
		if not penetration_table.is_empty():
			return float(penetration_table[0][1])
		return 180.0
		
	# Kinetic ammunition: interpolate penetration from range table
	if penetration_table.is_empty():
		return 150.0
	if r <= penetration_table[0][0]:
		return float(penetration_table[0][1])
	for i in range(penetration_table.size() - 1):
		var p0 = penetration_table[i]
		var p1 = penetration_table[i + 1]
		if r >= p0[0] and r <= p1[0]:
			var frac = (r - p0[0]) / maxf(1.0, p1[0] - p0[0])
			return lerpf(p0[1], p1[1], frac)
	# Extrapolate linearly beyond last table entry
	var last = penetration_table.back()
	var prev = penetration_table[penetration_table.size() - 2]
	var slope = (last[1] - prev[1]) / maxf(1.0, last[0] - prev[0])
	return maxf(20.0, last[1] + slope * (r - last[0]))

func get_velocity_at_range(range_m: float) -> float:
	var r = maxf(0.0, range_m)
	# Aerodynamic velocity degradation: v(x) = v0 / (1 + drag_coeff * v0 * x)
	# or exponential approximation v(x) = v0 * exp(-drag_coeff * x)
	return muzzle_velocity * exp(-drag_coeff * r)

func check_ricochet(angle_deg: float, rng: RandomNumberGenerator = null) -> bool:
	if angle_deg < ricochet_start_deg:
		return false
	if angle_deg >= ricochet_guaranteed_deg:
		return true
	var factor = (angle_deg - ricochet_start_deg) / (ricochet_guaranteed_deg - ricochet_start_deg)
	if rng != null:
		return rng.randf() < factor
	return factor > 0.5

# --- FACTORY METHODS FOR HISTORICAL & ALTERNATE-WWII AMMUNITION ---

static func create_apcbc() -> AmmunitionData:
	var ammo = (load("res://scripts/wego/AmmunitionData.gd") as GDScript).new()
	ammo.id = "APCBC_92"
	ammo.name = "92mm APCBC (Armor Piercing Capped)"
	ammo.category = Category.KINETIC
	ammo.mass_kg = 10.2
	ammo.muzzle_velocity = 880.0
	ammo.drag_coeff = 0.00030
	ammo.penetration_table = [
		[0.0, 215.0],
		[500.0, 195.0],
		[1000.0, 175.0],
		[1500.0, 155.0],
		[2000.0, 135.0]
	]
	ammo.normalization_deg = 3.5
	ammo.ricochet_start_deg = 70.0
	ammo.ricochet_guaranteed_deg = 80.0
	return ammo

static func create_apcr() -> AmmunitionData:
	var ammo = (load("res://scripts/wego/AmmunitionData.gd") as GDScript).new()
	ammo.id = "APCR_92"
	ammo.name = "92mm APCR / HVAP (Composite Rigid)"
	ammo.category = Category.KINETIC
	ammo.mass_kg = 6.8
	ammo.muzzle_velocity = 1080.0
	ammo.drag_coeff = 0.00062 # High drag because of lightweight carrier and blunt nose
	# APCR has enormous close-range penetration, but loses energy rapidly over distance
	ammo.penetration_table = [
		[0.0, 275.0],
		[500.0, 225.0],
		[1000.0, 175.0],
		[1500.0, 130.0],
		[2000.0, 95.0]
	]
	ammo.normalization_deg = 1.0 # Very poor slope normalization
	ammo.ricochet_start_deg = 65.0
	ammo.ricochet_guaranteed_deg = 75.0
	return ammo

static func create_heat() -> AmmunitionData:
	var ammo = (load("res://scripts/wego/AmmunitionData.gd") as GDScript).new()
	ammo.id = "HEAT_92"
	ammo.name = "92mm HEAT (High Explosive Anti-Tank)"
	ammo.category = Category.CHEMICAL
	ammo.mass_kg = 8.5
	ammo.muzzle_velocity = 650.0 # Slower muzzle velocity
	ammo.drag_coeff = 0.00045
	# Shaped-charge jet penetration does NOT fall off with range!
	ammo.penetration_table = [
		[0.0, 185.0],
		[500.0, 185.0],
		[1000.0, 185.0],
		[1500.0, 185.0],
		[2000.0, 185.0]
	]
	ammo.normalization_deg = 0.0 # Shaped charge does not normalize
	ammo.ricochet_start_deg = 75.0
	ammo.ricochet_guaranteed_deg = 83.0
	return ammo

static func create_he() -> AmmunitionData:
	var ammo = (load("res://scripts/wego/AmmunitionData.gd") as GDScript).new()
	ammo.id = "HE_92"
	ammo.name = "92mm HE (High Explosive Fragmentation)"
	ammo.category = Category.CHEMICAL
	ammo.mass_kg = 9.8
	ammo.muzzle_velocity = 700.0
	ammo.drag_coeff = 0.00040
	ammo.penetration_table = [
		[0.0, 45.0],
		[500.0, 45.0],
		[1000.0, 45.0],
		[1500.0, 45.0],
		[2000.0, 45.0]
	]
	ammo.normalization_deg = 0.0
	ammo.ricochet_start_deg = 80.0
	ammo.ricochet_guaranteed_deg = 85.0
	return ammo
