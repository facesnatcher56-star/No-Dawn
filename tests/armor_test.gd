extends SceneTree
const Armor = preload("res://scripts/wego/ArmorModel.gd")
var failures = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _init() -> void:
	var hit = Armor.intersect(Vector3(0, 0, -5), Vector3.FORWARD, Transform3D.IDENTITY, Vector3.ONE)
	check(hit.is_empty(), "Ray moving away must miss")
	hit = Armor.intersect(Vector3(0, 0, -5), Vector3.BACK, Transform3D.IDENTITY, Vector3.ONE)
	check(is_equal_approx(hit.get("t", 0), 4.5), "Ray enters box at exact surface")
	check(hit.normal == Vector3.FORWARD, "Entry normal faces incoming projectile")
	check(Armor.intersect(Vector3(2, 0, -5), Vector3.BACK, Transform3D.IDENTITY, Vector3.ONE).is_empty(), "Parallel ray outside slab misses")
	var a = Armor.new()
	var b = Armor.new()
	var origin = Vector3(-0.8, 1.45, -8)
	var shot = a.resolve(origin, Vector3.BACK, 740, 42)
	var repeat = b.resolve(origin, Vector3.BACK, 740, 42)
	check(shot == repeat, "Identical initial state and seed reproduce exact recorded paths and effects")
	check(shot.result == "PENETRATION", "Frontal APCBC penetrates prototype glacis at muzzle velocity")
	check(absf(shot.impacts[0].angle - 18) < 0.1, "Physical glacis slope produces 18 degree incidence")
	check(not a.occupied("Driver"), "Projectile through driver's physical station incapacitates driver")
	check(not a.can_move(), "Loss of driver prevents movement without a health counter")
	check(shot.paths.any(func(p): return p.fragment), "Penetration emits recorded physical fragment rays")
	check(a.reassign(1, "Driver"), "Surviving radio operator can replace driver")
	a.step(5, false)
	check(not a.can_move(), "Transfer cannot finish in one five second execution")
	a.step(5, false)
	check(a.occupied("Driver"), "Transfer finishes after two executions")
	var low = Armor.new().resolve(origin, Vector3.BACK, 100, 42)
	check(low.result == "STOPPED" and low.effects.is_empty(), "Low energy shot stops in armor without internal damage")
	var grazing = Armor.new().resolve(Vector3(-10, 1.3, -2.5), Vector3(1, 0, 0.01).normalized(), 740, 4)
	check(not grazing.impacts.is_empty(), "Side-on geometric ray intersects armor")
	var angled = Armor.new()
	angled.plates = [angled.plates[0]]
	var tangent = Vector3(0.985, 0, 0.174).normalized()
	var ricochet = angled.resolve(Vector3(0, 1.25, -2.9) - tangent * 10, tangent, 740, 3)
	check(ricochet.result == "RICOCHET" and ricochet.effects.is_empty(), "Grazing plate hit deflects without internal effects")
	check(ricochet.paths.size() == 2, "Ricochet records incoming and reflected segments")
	var ammo = Armor.new(40)
	for i in range(6): ammo.consume_round()
	check(ammo.rounds == 34 and not ammo.rack_filled("Ready rack") and ammo.rack_filled("Overflow rack"), "Ready rack empties before reserve storage")
	check(ammo.reload == 10.8, "Empty ready rack requires longer reserve reload")
	var model = Armor.new()
	model.burning = true
	model.fire_seconds = 4
	model.step(2, true)
	check(not model.burning, "Loader extinguishes compartment fire")
	model.burning = true
	model.step(36, false)
	check(model.catastrophic, "Uncontrolled fire eventually causes catastrophic loss")
	check(not Armor.new(25).rack_filled("Overflow rack") and Armor.new(40).rack_filled("Overflow rack"), "Extra ammunition occupies the overflow volume")
	var empty = Armor.new(0)
	check(not empty.can_fire(), "No ammunition means no shot")
	var miss = Armor.new().resolve(Vector3(10, 8, -8), Vector3.BACK, 740, 42)
	check(miss.result == "MISS" and miss.effects.is_empty(), "Geometric miss causes no effects")
	print("Armor checks completed; failures: ", failures)
	quit(failures)
