extends RefCounted
class_name BattlefieldKnowledge
## Coarse terrain presentation + exact dynamic-object visibility. Static map
## knowledge is independent of visual history. No camera references are accepted.
const Visibility = preload("res://scripts/wego/CrewVisibility.gd")
enum State { UNKNOWN, REMEMBERED, CURRENT }
const SIZE: int = 96
const CELL: float = 40.0
const HALF: float = SIZE * CELL * 0.5
var cells: Dictionary = {}
var remembered: Dictionary = {}
var dynamic_memory: Dictionary = {}
var dynamic_nodes: Array = []
var last_update: float = -999.0
var image: Image
var texture: ImageTexture
var material: ShaderMaterial

func _init() -> void:
	image = Image.create(SIZE, SIZE, false, Image.FORMAT_R8)
	image.fill(Color.BLACK)
	texture = ImageTexture.create_from_image(image)
	material = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never;
uniform sampler2D knowledge_mask : filter_linear, repeat_disable;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 vec2 uv = (world_position.xz + vec2(1920.0)) / 3840.0;
 float state = texture(knowledge_mask, uv).r;
 ALBEDO = vec3(0.12, 0.16, 0.20);
 ALPHA = mix(0.67, 0.0, state);
} """
	material.shader = shader
	material.set_shader_parameter("knowledge_mask", texture)

func cell_for(point: Vector3) -> Vector2i:
	return Vector2i(floori((point.x + HALF) / CELL), floori((point.z + HALF) / CELL))

func state_at(point: Vector3) -> int:
	var cell = cell_for(point)
	return State.CURRENT if cells.has(cell) else (State.REMEMBERED if remembered.has(cell) else State.UNKNOWN)

func is_live(point: Vector3, observers: Array, world: World3D) -> bool:
	return Visibility.union_sees_point(observers, point, world)

func remember_dynamic(id: String, state: Dictionary, visible_now: bool) -> Dictionary:
	if visible_now: dynamic_memory[id] = state.duplicate(true)
	return dynamic_memory.get(id, {}).duplicate(true)

func install_map(map_root: Node) -> void:
	if map_root == null: return
	var pending: Array[Node] = [map_root]
	while not pending.is_empty():
		var node = pending.pop_back()
		if node is MeshInstance3D: node.material_overlay = material
		if node is GPUParticles3D or node is Light3D or node is AudioStreamPlayer3D:
			dynamic_nodes.append(node)
			if node is Node3D: node.visible = false
		pending.append_array(node.get_children())

func update(observers: Array, world: World3D, now: float) -> void:
	# Effects use exact point tests on every sensing tick, never the coarse grid.
	for node in dynamic_nodes:
		if not is_instance_valid(node): continue
		var live = is_live(node.global_position, observers, world)
		if node is AudioStreamPlayer3D: node.stream_paused = not live
		elif node is Node3D: node.visible = live
	if now - last_update < 1.0: return
	last_update = now
	cells.clear()
	for z in range(SIZE):
		for x in range(SIZE):
			var cell = Vector2i(x, z)
			var point = Vector3((x + 0.5) * CELL - HALF, 0.3, (z + 0.5) * CELL - HALF)
			if is_live(point, observers, world):
				cells[cell] = true
				remembered[cell] = true
			image.set_pixel(x, z, Color.WHITE if cells.has(cell) else (Color(0.55, 0, 0) if remembered.has(cell) else Color.BLACK))
	texture.update(image)
