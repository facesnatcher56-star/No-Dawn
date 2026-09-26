extends CharacterBody3D
const Armor = preload("res://scripts/wego/ArmorModel.gd")
const CrewDoctrine = preload("res://scripts/wego/CrewDoctrine.gd")
const ContactTrack = preload("res://scripts/wego/ContactTrack.gd")

var model = Armor.new()
var turret: Node3D
var lamp: SpotLight3D
var muzzle_flash: OmniLight3D
var orders: Dictionary = {}
var remaining_move = 0.0
var remaining_pivot = 0.0
var shot_pending = false
var elapsed = 0.0
var engine_on = true
var speed = 0.0
var flash = 0.0
var contact: Dictionary = {}
var history: Array = []
var color = Color("657665")

var doctrine = null
var track = null
var doctrine_fire_authorized: bool = false
var doctrine_halt: bool = false
var doctrine_reversing: bool = false

func _init() -> void:
	doctrine = CrewDoctrine.new()
var crew_skill: Dictionary = {
	"commander_spotting": 1.0,
	"gunner_tracking": 1.0,
	"driver_response": 1.0
}

static func box(parent: Node3D, size: Vector3, pose: Transform3D, tint: Color) -> MeshInstance3D:
	var mesh = MeshInstance3D.new()
	var shape = BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	var material = StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.8
	if tint.a < 1:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = material
	parent.add_child(mesh)
	mesh.transform = pose
	return mesh

func _ready() -> void:
	collision_layer = 2
	collision_mask = 3
	var collider = CollisionShape3D.new()
	collider.name = "CollisionShape3D"
	var shape = BoxShape3D.new()
	shape.size = Vector3(3.5, 2.8, 6.2)
	collider.shape = shape
	collider.position.y = 1.8
	add_child(collider)
	turret = Node3D.new()
	add_child(turret)
	for plate in model.plates:
		box(turret if plate.turret else self, plate.size, plate.pose, color)
	for x in [-1.9, 1.9]:
		box(self, Vector3(0.65, 0.8, 6.5), Transform3D(Basis.IDENTITY, Vector3(x, 0.65, 0)), Color("242a2d"))
	box(turret, Vector3(0.18, 0.18, 4), Transform3D(Basis.IDENTITY, Vector3(0, 2.65, -3)), Color("3a4143"))
	lamp = SpotLight3D.new()
	turret.add_child(lamp)
	lamp.position = Vector3(1, 2.9, -1.5)
	lamp.light_color = Color("e4d4a6")
	lamp.light_energy = 7
	lamp.spot_range = 140
	lamp.spot_angle = 20
	lamp.visible = false
	muzzle_flash = OmniLight3D.new()
	muzzle_flash.position = Vector3(0, 2.65, -5)
	muzzle_flash.light_color = Color("ffb866")
	muzzle_flash.omni_range = 14
	muzzle_flash.light_energy = 12
	muzzle_flash.visible = false
	turret.add_child(muzzle_flash)

func commit(plan: Dictionary) -> void:
	orders = plan.duplicate(true)
	remaining_move = orders.get("move", 0.0)
	remaining_pivot = deg_to_rad(orders.get("pivot", 0.0))
	shot_pending = orders.get("fire", false)
	doctrine_fire_authorized = false
	doctrine_halt = false
	doctrine_reversing = false
	elapsed = 0
	engine_on = orders.get("engine", true)

func step(delta: float) -> void:
	elapsed += delta
	flash = maxf(0, flash - delta)
	if muzzle_flash != null:
		muzzle_flash.visible = flash > 0.42
	model.step(delta, orders.get("extinguish", false))
	if lamp != null:
		lamp.visible = elapsed <= 2 and orders.get("light", false) and model.functional("Searchlight") and not model.catastrophic
	var world_turret_yaw = rotation.y + model.turret_yaw
	speed = 0
	if engine_on and model.can_move() and not doctrine_halt:
		var pivot = clampf(remaining_pivot, -delta * 0.3, delta * 0.3)
		var movement = clampf(remaining_move, -delta * 3, delta * (2 if orders.get("creep", false) else 7))
		if doctrine_reversing:
			movement = -delta * 2.5 # Reversing toward cover
			pivot = 0.0
		elif orders.has("destination"):
			var offset: Vector3 = orders.destination - position
			offset.y = 0
			var destination_yaw = -atan2(offset.x, -offset.z)
			pivot = clampf(angle_difference(rotation.y, destination_yaw), -delta * 0.6, delta * 0.6)
			movement = minf(offset.length(), delta * (2 if orders.get("creep", false) else 7))
			if absf(angle_difference(rotation.y, destination_yaw)) > 0.04 or offset.length() < 0.1: movement = 0
		rotation.y += pivot
		remaining_pivot -= pivot
		velocity = -transform.basis.z * movement / delta
		var before = position
		if is_inside_tree():
			move_and_slide()
		else:
			position += velocity * delta
		var travelled = position.distance_to(before)
		remaining_move -= signf(movement) * travelled
		speed = travelled / delta
	else:
		velocity = Vector3.ZERO

	# Traverse in world space so a hull pivot does not drag the gun off bearing.
	model.turret_yaw = rotate_toward(world_turret_yaw, gun_goal_yaw(), delta * 0.5) - rotation.y
	if turret != null:
		turret.rotation.y = model.turret_yaw

func gun_goal_yaw() -> float:
	if orders.has("aim_point"):
		var offset: Vector3 = orders.aim_point - position
		return -atan2(offset.x, -offset.z)
	elif orders.get("tracking_contact", false) and track != null:
		var offset: Vector3 = track.estimated_position - position
		return -atan2(offset.x, -offset.z)
	return deg_to_rad(-orders.get("bearing", 0.0))

func ready_to_shoot() -> bool:
	var target_yaw = gun_goal_yaw()
	var can_trigger = (shot_pending or doctrine_fire_authorized)
	return can_trigger and elapsed > 0.4 and model.reload <= 0 and model.can_fire() and absf(angle_difference(rotation.y + model.turret_yaw, target_yaw)) < 0.04

func consume_round() -> void:
	shot_pending = false
	doctrine_fire_authorized = false
	model.consume_round()
	flash = 0.5
	muzzle_flash.visible = true

func station_report() -> String:
	var lines = PackedStringArray()
	for c in model.crew:
		lines.append("%s: %s  ·  %s" % [c.name, c.state, c.station])
	if not model.transfer.is_empty(): lines.append("Transfer: %.1f s remaining" % model.transfer.remaining)
	for m in model.modules:
		if m.state != "Functional": lines.append(m.name + " DISABLED")
	if model.burning: lines.append("ENGINE FIRE — loader can extinguish")
	return "\n".join(lines)
