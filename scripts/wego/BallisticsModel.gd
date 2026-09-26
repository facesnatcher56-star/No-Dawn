extends RefCounted
class_name BallisticsModel
## Computes physical projectile flight state, range-dependent kinetic velocity loss,
## chemical energy shaped-charge penetration, normalization, ricochet angles,
## material multipliers (RHA vs Cast vs Spaced), and detailed debug reports.

const AmmunitionData = preload("res://scripts/wego/AmmunitionData.gd")

# Material resistance multipliers relative to standard Rolled Homogeneous Armor (RHA)
const MATERIAL_FACTORS: Dictionary = {
	"RHA": 1.0,
	"CAST": 0.92,       # Cast armor has ~8% lower resistance than rolled plate
	"SPACED": 1.0,      # Spaced plate
	"ALUMINUM": 0.45,   # Lightweight armor
	"COMPOSITE": 1.40   # Modern composite array
}

static func get_material_multiplier(material_name: String, is_chemical: bool) -> float:
	var mat = material_name.to_upper()
	if is_chemical:
		if mat == "SPACED":
			return 1.40 # Spaced armor causes premature shaped-charge detonation
		elif mat == "COMPOSITE":
			return 2.20 # Ceramic/composite highly disrupts HEAT jets
	return MATERIAL_FACTORS.get(mat, 1.0)

# Resolves a single armor plate impact with comprehensive ballistics
static func evaluate_plate_impact(
	plate: Dictionary,
	dir: Vector3,
	hit_normal: Vector3,
	hit_pos: Vector3,
	ammo: AmmunitionData,
	range_m: float,
	energy_in: float,
	rng: RandomNumberGenerator
) -> Dictionary:
	var base_mm: float = plate.get("mm", 50.0)
	var mat_name: String = plate.get("material", "RHA")
	var is_chemical: bool = (ammo.category == AmmunitionData.Category.CHEMICAL)
	var mat_mult: float = get_material_multiplier(mat_name, is_chemical)
	
	# 1. Physical Impact Angle
	var cosine: float = maxf(0.02, absf(dir.dot(hit_normal)))
	var impact_angle_rad: float = acos(clampf(cosine, 0.0, 1.0))
	var impact_angle_deg: float = rad_to_deg(impact_angle_rad)
	
	# 2. Ricochet Check
	var is_ricochet: bool = ammo.check_ricochet(impact_angle_deg, rng)
	
	# 3. Slope Normalization (reduces effective angle for capped/penetrating rounds)
	var effective_angle_deg: float = maxf(0.0, impact_angle_deg - ammo.normalization_deg)
	var effective_cosine: float = maxf(0.05, cos(deg_to_rad(effective_angle_deg)))
	
	# 4. Effective Armor Resistance (Line-of-sight thickness modified by material factor)
	var effective_armor_mm: float = (base_mm * mat_mult) / effective_cosine
	
	# 5. Penetration capability at impact range
	var nominal_pen_mm: float = ammo.get_penetration_at_range(range_m)
	var striking_velocity: float = ammo.get_velocity_at_range(range_m)
	
	# 6. Outcome determination
	var outcome: String = "MISS"
	var residual_energy: float = 0.0
	var residual_pen_mm: float = 0.0
	
	if is_ricochet:
		outcome = "RICOCHET"
	elif nominal_pen_mm >= effective_armor_mm:
		outcome = "PENETRATION"
		var remaining_ratio: float = clampf(1.0 - (effective_armor_mm / maxf(1.0, nominal_pen_mm)), 0.05, 1.0)
		residual_pen_mm = nominal_pen_mm - effective_armor_mm
		residual_energy = energy_in * remaining_ratio
	elif nominal_pen_mm >= effective_armor_mm * 0.90:
		outcome = "PARTIAL_PENETRATION"
		residual_energy = energy_in * 0.08
		residual_pen_mm = 0.0
	else:
		outcome = "STOPPED"
		
	var report = {
		"outcome": outcome,
		"position": hit_pos,
		"normal": hit_normal,
		"plate": plate.get("name", "Plate"),
		"mm": base_mm,
		"material": mat_name,
		"material_factor": mat_mult,
		"impact_angle": impact_angle_deg,
		"effective_angle": effective_angle_deg,
		"effective": effective_armor_mm,
		"nominal_penetration": nominal_pen_mm,
		"striking_velocity": striking_velocity,
		"energy_in": energy_in,
		"energy_out": residual_energy,
		"residual_penetration_mm": residual_pen_mm,
		"is_ricochet": is_ricochet
	}
	return report

# Formats an in-depth developer debug shot report
static func format_debug_report(record: Dictionary, ammo: AmmunitionData) -> String:
	var imp = record.get("impacts", [])
	var first_imp = imp[0] if not imp.is_empty() else {}
	var lines = PackedStringArray()
	lines.append("=======================================================")
	lines.append("                BALLISTIC IMPACT REPORT                ")
	lines.append("=======================================================")
	lines.append("Shot ID:               #%02d" % record.get("shot_id", 0))
	lines.append("Shooter:               %s  →  Target: %s" % [record.get("shooter", "Unknown"), record.get("target", "Unknown")])
	lines.append("Ammunition:            %s (%s)" % [ammo.name, "KINETIC" if ammo.category == AmmunitionData.Category.KINETIC else "CHEMICAL"])
	lines.append("Firing Range:          %.1f m" % record.get("range", 0.0))
	lines.append("Muzzle Velocity:       %.1f m/s" % ammo.muzzle_velocity)
	lines.append("Impact Velocity:       %.1f m/s" % first_imp.get("striking_velocity", record.get("speed", ammo.muzzle_velocity)))
	lines.append("Nominal Penetration:   %.1f mm RHA" % first_imp.get("nominal_penetration", ammo.get_penetration_at_range(record.get("range", 0.0))))
	lines.append("-------------------------------------------------------")
	lines.append("Armor Zone Hit:        %s [%s]" % [first_imp.get("plate", "N/A"), first_imp.get("material", "RHA")])
	lines.append("Base Armor Thickness:  %.1f mm" % first_imp.get("mm", 0.0))
	lines.append("Impact Angle:          %.1f° (Normalized: %.1f°)" % [first_imp.get("impact_angle", 0.0), first_imp.get("effective_angle", 0.0)])
	lines.append("Effective Resistance:  %.1f mm RHA eq" % first_imp.get("effective", 0.0))
	lines.append("Ricochet Check:        %s" % ("RICOCHET DETECTED" if first_imp.get("is_ricochet", false) else "NO RICOCHET"))
	lines.append("-------------------------------------------------------")
	lines.append("Outcome:               %s" % record.get("result", "UNKNOWN"))
	lines.append("Residual Penetration:  %.1f mm" % first_imp.get("residual_penetration_mm", 0.0))
	lines.append("Internal Strikes:      %d component(s)" % record.get("strikes", []).size())
	if not record.get("effects", []).is_empty():
		lines.append("Consequences:          " + "; ".join(record.get("effects", [])))
	else:
		lines.append("Consequences:          None (armor integrity held)")
	lines.append("=======================================================")
	return "\n".join(lines)
