extends Node3D
const Vehicle = preload("res://scripts/wego/TacticalVehicle.gd")

func solid(label: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var body = StaticBody3D.new()
	body.name = label
	body.position = pos
	add_child(body)
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	Vehicle.box(body, size, Transform3D.IDENTITY, color)

func _ready() -> void:
	solid("KnownGround", Vector3(0, -0.5, -700), Vector3(2200, 1, 2400), Color("666957"))
	Vehicle.box(self, Vector3(12, 0.05, 2000), Transform3D(Basis.IDENTITY, Vector3(0, 0.03, -800)), Color("55565a"))
	solid("Warehouse", Vector3(0, 7, -1440), Vector3(95, 14, 40), Color("777b80"))
	solid("LowRidge", Vector3(210, 1.2, -1460), Vector3(150, 2.4, 18), Color("68614a"))
	for x in [-230, -270, -310]:
		solid("FuelTank%d" % x, Vector3(x, 5, -1400), Vector3(22, 10, 22), Color("858279"))
