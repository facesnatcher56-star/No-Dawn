extends RefCounted
class_name MastodonVisualController
## Controls X-ray presentation, armor transparency, cutaways, and component highlighting.

enum DisplayMode { NORMAL, XRAY, CUTAWAY, CREW_FOCUS, COMPONENT_FOCUS, ARMOR_FOCUS }

var root_node: Node3D
var nodes_by_category: Dictionary = {
	"ARM": [],
	"CMP": [],
	"CREW": [],
	"AMMO": [],
	"HATCH": [],
	"OPT": [],
	"VIS": [],
	"MKR": []
}
var nodes_by_name: Dictionary = {}
var original_materials: Dictionary = {}

var xray_material: StandardMaterial3D
var highlight_material: StandardMaterial3D
var current_mode: DisplayMode = DisplayMode.NORMAL

func _init(tank_root: Node3D) -> void:
	root_node = tank_root
	_create_utility_materials()
	index_nodes(tank_root)

func _create_utility_materials() -> void:
	xray_material = StandardMaterial3D.new()
	xray_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	xray_material.albedo_color = Color(0.2, 0.45, 0.6, 0.22)
	xray_material.metallic = 0.5
	xray_material.roughness = 0.3
	xray_material.cull_mode = BaseMaterial3D.CULL_BACK

	highlight_material = StandardMaterial3D.new()
	highlight_material.albedo_color = Color(1.0, 0.85, 0.25, 1.0)
	highlight_material.emission_enabled = true
	highlight_material.emission = Color(1.0, 0.75, 0.15)
	highlight_material.emission_energy_multiplier = 2.0

func index_nodes(node: Node) -> void:
	for child in node.get_children():
		var node_name = child.name
		nodes_by_name[node_name] = child
		
		# Categorize by prefix
		var found_cat = false
		for cat in nodes_by_category.keys():
			if node_name.begins_with(cat + "_"):
				nodes_by_category[cat].append(child)
				found_cat = true
				break
		if not found_cat and node_name.begins_with("VIS_"):
			nodes_by_category["VIS"].append(child)
			
		# Store original materials if MeshInstance3D
		if child is MeshInstance3D and child.mesh:
			original_materials[child] = child.material_override
			
		index_nodes(child)

func set_display_mode(mode: DisplayMode) -> void:
	current_mode = mode
	
	match mode:
		DisplayMode.NORMAL:
			_apply_visibility(true, false, false, false, true)
			_reset_armor_materials()
		DisplayMode.XRAY:
			_apply_visibility(true, true, true, true, false)
			_apply_armor_material(xray_material)
		DisplayMode.CUTAWAY:
			_apply_visibility(false, true, true, true, false)
			_reset_armor_materials()
		DisplayMode.CREW_FOCUS:
			_apply_visibility(false, false, true, false, false)
		DisplayMode.COMPONENT_FOCUS:
			_apply_visibility(false, true, false, true, false)
		DisplayMode.ARMOR_FOCUS:
			_apply_visibility(true, false, false, false, false)
			_color_code_armor()

func _apply_visibility(show_armor: bool, show_cmp: bool, show_crew: bool, show_ammo: bool, show_vis: bool) -> void:
	for node in nodes_by_category["ARM"]:
		node.visible = show_armor
	for node in nodes_by_category["CMP"]:
		node.visible = show_cmp
	for node in nodes_by_category["CREW"]:
		node.visible = show_crew
	for node in nodes_by_category["AMMO"]:
		node.visible = show_ammo
	for node in nodes_by_category["VIS"]:
		node.visible = show_vis

func _apply_armor_material(mat: Material) -> void:
	for node in nodes_by_category["ARM"]:
		if node is MeshInstance3D:
			node.material_override = mat

func _reset_armor_materials() -> void:
	for node in nodes_by_category["ARM"]:
		if node is MeshInstance3D:
			node.material_override = original_materials.get(node, null)

func _color_code_armor() -> void:
	# Color-code armor based on thickness: green (light) to red/purple (heavy)
	for node in nodes_by_category["ARM"]:
		if node is MeshInstance3D:
			var mat = StandardMaterial3D.new()
			var mm = 70.0
			var name_str = node.name
			if "UpperGlacis" in name_str or "Mantlet" in name_str or "TurretFront" in name_str:
				mat.albedo_color = Color(0.9, 0.2, 0.2) # Heavy (90-120mm)
			elif "LowerGlacis" in name_str or "TurretLeft" in name_str or "TurretRight" in name_str:
				mat.albedo_color = Color(0.9, 0.6, 0.1) # Medium-Heavy (75mm)
			elif "HullLeft" in name_str or "HullRight" in name_str or "TurretRear" in name_str:
				mat.albedo_color = Color(0.8, 0.8, 0.2) # Medium (60-70mm)
			else:
				mat.albedo_color = Color(0.2, 0.75, 0.3) # Roof/Floor (25-30mm)
			node.material_override = mat

var currently_highlighted: MeshInstance3D = null

func highlight_node(target_name: String) -> void:
	if currently_highlighted != null:
		if nodes_by_category["ARM"].has(currently_highlighted) and current_mode == DisplayMode.XRAY:
			currently_highlighted.material_override = xray_material
		else:
			currently_highlighted.material_override = original_materials.get(currently_highlighted, null)
		currently_highlighted = null
			
	if target_name.is_empty():
		return

	var target = nodes_by_name.get(target_name)
	if target:
		target.visible = true
		if target is MeshInstance3D:
			currently_highlighted = target
			target.material_override = highlight_material

func get_node_by_name(name_str: String) -> Node3D:
	return nodes_by_name.get(name_str, null)
