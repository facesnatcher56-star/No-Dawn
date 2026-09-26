extends Node3D
class_name CombatEffects
## Procedural 3D combat visual effects: muzzle blast, recoil dust kicker,
## ballistic shell tracer, and distinct armor impact debris/sparks.

static func spawn_muzzle_blast(parent: Node3D, muzzle_pos: Vector3, gun_dir: Vector3) -> void:
	if parent == null: return

	# 1. Forward fireball burst
	var flash_particles = GPUParticles3D.new()
	flash_particles.position = muzzle_pos
	flash_particles.amount = 24
	flash_particles.lifetime = 0.18
	flash_particles.one_shot = true
	flash_particles.explosiveness = 0.95
	flash_particles.speed_scale = 1.6

	var pmat = ParticleProcessMaterial.new()
	pmat.direction = gun_dir
	pmat.spread = 22.0
	pmat.initial_velocity_min = 18.0
	pmat.initial_velocity_max = 32.0
	pmat.gravity = Vector3.ZERO
	pmat.scale_min = 0.8
	pmat.scale_max = 2.4
	pmat.color = Color(1.0, 0.65, 0.18, 0.9)
	flash_particles.process_material = pmat

	var pmesh = SphereMesh.new()
	pmesh.radius = 0.35
	pmesh.height = 0.7
	var smat = StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(1.0, 0.65, 0.15)
	pmesh.material = smat
	flash_particles.draw_pass_1 = pmesh
	parent.add_child(flash_particles)
	flash_particles.emitting = true

	# 2. Side muzzle-brake gas deflection jets (Left & Right)
	var right_dir = gun_dir.cross(Vector3.UP).normalized()
	for side in [-1.0, 1.0]:
		var jet = GPUParticles3D.new()
		jet.position = muzzle_pos + right_dir * (side * 0.35)
		jet.amount = 16
		jet.lifetime = 0.22
		jet.one_shot = true
		jet.explosiveness = 0.92

		var jet_mat = ParticleProcessMaterial.new()
		jet_mat.direction = right_dir * side
		jet_mat.spread = 15.0
		jet_mat.initial_velocity_min = 12.0
		jet_mat.initial_velocity_max = 22.0
		jet_mat.gravity = Vector3.ZERO
		jet_mat.scale_min = 0.5
		jet_mat.scale_max = 1.6
		jet_mat.color = Color(1.0, 0.72, 0.25, 0.8)
		jet.process_material = jet_mat
		jet.draw_pass_1 = pmesh
		parent.add_child(jet)
		jet.emitting = true

	# 3. Expanding billowing muzzle smoke
	var smoke = GPUParticles3D.new()
	smoke.position = muzzle_pos + gun_dir * 1.2
	smoke.amount = 36
	smoke.lifetime = 2.2
	smoke.one_shot = true
	smoke.explosiveness = 0.85
	smoke.speed_scale = 0.9

	var smoke_mat = ParticleProcessMaterial.new()
	smoke_mat.direction = gun_dir + Vector3(0, 0.3, 0)
	smoke_mat.spread = 35.0
	smoke_mat.initial_velocity_min = 4.0
	smoke_mat.initial_velocity_max = 9.0
	smoke_mat.gravity = Vector3(0, 0.6, 0)
	smoke_mat.scale_min = 1.2
	smoke_mat.scale_max = 4.2
	smoke_mat.color = Color(0.35, 0.36, 0.38, 0.45)
	smoke.process_material = smoke_mat

	var smoke_mesh = SphereMesh.new()
	smoke_mesh.radius = 0.8
	smoke_mesh.height = 1.6
	var smoke_smat = StandardMaterial3D.new()
	smoke_smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_smat.albedo_color = Color(0.32, 0.34, 0.36, 0.4)
	smoke_smat.roughness = 0.9
	smoke_mesh.material = smoke_smat
	smoke.draw_pass_1 = smoke_mesh
	parent.add_child(smoke)
	smoke.emitting = true

	# 4. Ground dust kicker beneath the muzzle
	var ground_pos = Vector3(muzzle_pos.x, 0.1, muzzle_pos.z)
	var dust = GPUParticles3D.new()
	dust.position = ground_pos
	dust.amount = 28
	dust.lifetime = 1.8
	dust.one_shot = true
	dust.explosiveness = 0.9

	var dust_mat = ParticleProcessMaterial.new()
	dust_mat.direction = Vector3(0, 0.4, 0)
	dust_mat.spread = 80.0
	dust_mat.initial_velocity_min = 3.5
	dust_mat.initial_velocity_max = 8.0
	dust_mat.gravity = Vector3(0, -0.4, 0)
	dust_mat.scale_min = 1.0
	dust_mat.scale_max = 3.5
	dust_mat.color = Color(0.36, 0.33, 0.28, 0.45)
	dust.process_material = dust_mat
	dust.draw_pass_1 = smoke_mesh
	parent.add_child(dust)
	dust.emitting = true

	# 5. Intense brief muzzle light
	var light = OmniLight3D.new()
	light.position = muzzle_pos
	light.light_color = Color(1.0, 0.75, 0.35)
	light.light_energy = 16.0
	light.omni_range = 35.0
	parent.add_child(light)

	var tween = parent.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.18)
	tween.tween_callback(light.queue_free)

	# Auto-clean particles after lifetime
	var clean_tween = parent.create_tween()
	clean_tween.tween_interval(3.0)
	clean_tween.tween_callback(func():
		if is_instance_valid(flash_particles): flash_particles.queue_free()
		if is_instance_valid(smoke): smoke.queue_free()
		if is_instance_valid(dust): dust.queue_free()
	)

static func spawn_impact_fx(parent: Node3D, pos: Vector3, normal: Vector3, outcome: String) -> void:
	if parent == null: return

	var is_pen = outcome == "PENETRATION"
	var is_ricochet = outcome == "RICOCHET"

	# 1. Hot metal sparks
	var sparks = GPUParticles3D.new()
	sparks.position = pos
	sparks.amount = 40 if is_ricochet else (30 if is_pen else 18)
	sparks.lifetime = 0.45
	sparks.one_shot = true
	sparks.explosiveness = 0.95

	var spark_mat = ParticleProcessMaterial.new()
	var reflect_dir = normal
	if is_ricochet:
		reflect_dir = (normal + Vector3.UP * 0.4).normalized()
	spark_mat.direction = reflect_dir
	spark_mat.spread = 45.0 if is_ricochet else 75.0
	spark_mat.initial_velocity_min = 14.0
	spark_mat.initial_velocity_max = 30.0
	spark_mat.gravity = Vector3(0, -9.8, 0)
	spark_mat.scale_min = 0.1
	spark_mat.scale_max = 0.3
	spark_mat.color = Color(1.0, 0.85, 0.4)
	sparks.process_material = spark_mat

	var sp_mesh = BoxMesh.new()
	sp_mesh.size = Vector3(0.08, 0.08, 0.25)
	var sp_smat = StandardMaterial3D.new()
	sp_smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sp_smat.albedo_color = Color(1.0, 0.88, 0.45)
	sp_mesh.material = sp_smat
	sparks.draw_pass_1 = sp_mesh
	parent.add_child(sparks)
	sparks.emitting = true

	# 2. Impact smoke puff
	var smoke = GPUParticles3D.new()
	smoke.position = pos
	smoke.amount = 20
	smoke.lifetime = 1.4
	smoke.one_shot = true
	smoke.explosiveness = 0.9

	var sm_mat = ParticleProcessMaterial.new()
	sm_mat.direction = normal
	sm_mat.spread = 50.0
	sm_mat.initial_velocity_min = 2.0
	sm_mat.initial_velocity_max = 6.0
	sm_mat.gravity = Vector3(0, 0.5, 0)
	sm_mat.scale_min = 0.8
	sm_mat.scale_max = 2.4
	sm_mat.color = Color(0.25, 0.25, 0.26, 0.45) if is_pen else Color(0.45, 0.42, 0.38, 0.4)
	smoke.process_material = sm_mat

	var sm_mesh = SphereMesh.new()
	sm_mesh.radius = 0.5
	sm_mesh.height = 1.0
	var sm_smat = StandardMaterial3D.new()
	sm_smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm_smat.albedo_color = Color(0.28, 0.28, 0.30, 0.4)
	sm_mesh.material = sm_smat
	smoke.draw_pass_1 = sm_mesh
	parent.add_child(smoke)
	smoke.emitting = true

	# 3. Flash light
	var light = OmniLight3D.new()
	light.position = pos + normal * 0.4
	light.light_color = Color(1.0, 0.8, 0.4) if is_ricochet else Color(1.0, 0.5, 0.2)
	light.light_energy = 8.0
	light.omni_range = 14.0
	parent.add_child(light)

	var tween = parent.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.12)
	tween.tween_callback(light.queue_free)

	var clean = parent.create_tween()
	clean.tween_interval(2.0)
	clean.tween_callback(func():
		if is_instance_valid(sparks): sparks.queue_free()
		if is_instance_valid(smoke): smoke.queue_free()
	)
