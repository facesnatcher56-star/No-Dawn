extends Node3D
class_name WorldPlanningGraphics
## In-world 3D tactical graphics: movement route ribbons, waypoint stop markers,
## observation sector cones, and predicted movement corridor ribbons on terrain.

var route_mesh: MeshInstance3D
var observation_mesh: MeshInstance3D
var corridor_mesh: MeshInstance3D
var dest_marker: Node3D

var mat_route: StandardMaterial3D
var mat_cone: StandardMaterial3D
var mat_corridor: StandardMaterial3D
var mat_border: StandardMaterial3D

func _ready() -> void:
	_init_materials()
	_create_meshes()

func _init_materials() -> void:
	mat_route = StandardMaterial3D.new()
	mat_route.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_route.albedo_color = Color(0.25, 0.65, 0.85, 0.45) # Tactical blue
	mat_route.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_route.cull_mode = BaseMaterial3D.CULL_DISABLED

	mat_cone = StandardMaterial3D.new()
	mat_cone.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_cone.albedo_color = Color(0.20, 0.45, 0.65, 0.025) # Whisper-faint transparent observation sector
	mat_cone.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_cone.cull_mode = BaseMaterial3D.CULL_DISABLED

	mat_corridor = StandardMaterial3D.new()
	mat_corridor.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_corridor.albedo_color = Color(0.92, 0.72, 0.28, 0.16) # Tactical amber prediction
	mat_corridor.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_corridor.cull_mode = BaseMaterial3D.CULL_DISABLED

	mat_border = StandardMaterial3D.new()
	mat_border.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_border.albedo_color = Color(0.92, 0.72, 0.28, 0.55)
	mat_border.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func _create_meshes() -> void:
	route_mesh = MeshInstance3D.new()
	route_mesh.material_override = mat_route
	add_child(route_mesh)

	observation_mesh = MeshInstance3D.new()
	observation_mesh.material_override = mat_cone
	add_child(observation_mesh)

	corridor_mesh = MeshInstance3D.new()
	corridor_mesh.material_override = mat_corridor
	add_child(corridor_mesh)

	dest_marker = Node3D.new()
	add_child(dest_marker)
	_build_dest_marker()

func _build_dest_marker() -> void:
	# Tank footprint outline at destination (3.4m x 7.0m)
	var ring = MeshInstance3D.new()
	var tor = TorusMesh.new()
	tor.inner_radius = 2.4
	tor.outer_radius = 2.7
	tor.rings = 24
	tor.ring_segments = 8
	ring.mesh = tor
	ring.material_override = mat_route
	ring.position.y = 0.08
	dest_marker.add_child(ring)

	var arrow = MeshInstance3D.new()
	var pm = PrismMesh.new()
	pm.size = Vector3(2.2, 0.12, 3.2)
	arrow.mesh = pm
	arrow.material_override = mat_route
	arrow.position = Vector3(0, 0.12, -2.4)
	arrow.rotation.x = -PI * 0.5
	dest_marker.add_child(arrow)
	dest_marker.visible = false

## Updates the in-world 3D route line and destination marker
func update_route(start: Vector3, dest: Variant, queue_points: Array, is_planning: bool) -> void:
	if dest == null or not is_planning:
		route_mesh.visible = false
		dest_marker.visible = false
		return

	var dest_pos: Vector3 = dest as Vector3
	dest_marker.visible = true
	dest_marker.position = Vector3(dest_pos.x, 0.05, dest_pos.z)
	var travel_dir = (dest_pos - start).normalized()
	if travel_dir.length_squared() > 0.01:
		dest_marker.rotation.y = -atan2(travel_dir.x, -travel_dir.z)

	# Build ribbon from start to dest
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)

	var pts: Array[Vector3] = [start]
	for qp in queue_points:
		if qp is Vector3: pts.append(qp)
	pts.append(dest_pos)

	var half_w = 0.8
	for i in range(pts.size() - 1):
		var p1 = pts[i]
		var p2 = pts[i + 1]
		var dir = (p2 - p1).normalized()
		var side = dir.cross(Vector3.UP).normalized() * half_w

		st.add_vertex(p1 - side + Vector3.UP * 0.08)
		st.add_vertex(p1 + side + Vector3.UP * 0.08)
		st.add_vertex(p2 - side + Vector3.UP * 0.08)
		st.add_vertex(p2 + side + Vector3.UP * 0.08)

	route_mesh.mesh = st.commit()
	route_mesh.visible = true

## Updates the in-world observation sector fan on the ground
func update_observation(tank_pos: Vector3, turret_yaw: float, is_planning: bool, fov_deg: float = 45.0, range_m: float = 65.0) -> void:
	if not is_planning:
		observation_mesh.visible = false
		return

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var origin = tank_pos + Vector3.UP * 0.12
	var half_fov = deg_to_rad(fov_deg * 0.5)
	var base_yaw = turret_yaw
	var segments = 24

	var arc_pts: Array[Vector3] = []
	for i in range(segments + 1):
		var angle = base_yaw - half_fov + (float(i) / segments) * (half_fov * 2.0)
		var edge_dir = Vector3(sin(angle), 0, -cos(angle))
		arc_pts.append(origin + edge_dir * range_m)

	for i in range(segments):
		st.add_vertex(origin)
		st.add_vertex(arc_pts[i])
		st.add_vertex(arc_pts[i + 1])

	observation_mesh.mesh = st.commit()
	observation_mesh.visible = true

## Updates the 3D Predicted Movement Corridor extending forward from ghost tank
func update_predicted_corridor(corridor_data: Dictionary, show: bool) -> void:
	if not show or corridor_data.is_empty():
		corridor_mesh.visible = false
		return

	var left_pts = corridor_data.get("left_edge", [])
	var right_pts = corridor_data.get("right_edge", [])

	if left_pts.size() < 2 or right_pts.size() < 2:
		corridor_mesh.visible = false
		return

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)

	var count = mini(left_pts.size(), right_pts.size())
	for i in range(count):
		var lp: Vector3 = left_pts[i] + Vector3.UP * 0.14
		var rp: Vector3 = right_pts[i] + Vector3.UP * 0.14
		st.add_vertex(lp)
		st.add_vertex(rp)

	corridor_mesh.mesh = st.commit()
	corridor_mesh.visible = true
