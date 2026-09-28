extends RefCounted
class_name CrewVisibility
## Physics-only observation. Cameras never enter this interface.
const SAMPLE_POINTS = [Vector3(0, 0.7, -2.5), Vector3(0, 1.6, -2.0),
	Vector3(0, 2.35, 0), Vector3(0, 3.05, 0), Vector3(0, 1.4, 2.5),
	Vector3(-1.65, 1.5, 0), Vector3(1.65, 1.5, 0)]

static func eye(vehicle, station) -> Vector3:
	var height: float = 2.75
	if station.role_name == "Driver": height = 1.65
	if station.role_name == "Loader": height = 2.35
	if station.role_name == "Commander" and vehicle.orders.get("commander_exposed", false): height = 3.25
	if station.role_name == "Gunner" and vehicle.is_inside_tree():
		return vehicle.gunner_sight.get_optic_global_position()
	return vehicle.position + Vector3(0, height, 0)

static func clear_ray(world: World3D, origin: Vector3, point: Vector3, vehicle = null, target = null) -> bool:
	# A null world is the explicit geometry-free unit-test fixture.
	if world == null: return true
	var query = PhysicsRayQueryParameters3D.create(origin, point, 3)
	if vehicle is CollisionObject3D: query.exclude = [vehicle.get_rid()]
	var hit = world.direct_space_state.intersect_ray(query)
	return hit.is_empty() or (target != null and hit.get("collider") == target)

static func sees_point(vehicle, station, point: Vector3, world: World3D, target = null) -> bool:
	if not station.can_observe(vehicle): return false
	var origin = eye(vehicle, station)
	if origin.distance_to(point) > station.max_effective_range: return false
	if not station.is_point_in_fov(point, origin): return false
	return clear_ray(world, origin, point, vehicle, target)

static func sample_vehicle(vehicle, station, target, world: World3D) -> Dictionary:
	var rays: Array = []
	var count: int = 0
	var origin = eye(vehicle, station)
	var active: bool = station.can_observe(vehicle)
	for local_point in SAMPLE_POINTS:
		var point: Vector3 = target.position + Basis(Vector3.UP, target.rotation.y) * local_point
		var seen: bool = active and origin.distance_to(point) <= station.max_effective_range and station.is_point_in_fov(point, origin) and clear_ray(world, origin, point, vehicle, target)
		if seen: count += 1
		rays.append({"from": origin, "to": point, "visible": seen})
	return {"fraction": float(count) / SAMPLE_POINTS.size(), "rays": rays}

static func union_sees_point(vehicles: Array, point: Vector3, world: World3D) -> bool:
	for vehicle in vehicles:
		for station in vehicle.observers.values():
			if sees_point(vehicle, station, point, world): return true
	return false
