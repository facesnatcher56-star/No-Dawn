extends Node3D
class_name TankInspection
## Technical inspection and debug suite for the A-47 Mastodon Heavy Cruiser tank.

const A47_Mastodon_Vehicle = preload("res://scripts/tank/A47_Mastodon_Vehicle.gd")
const MastodonVisualController = preload("res://scripts/tank/MastodonVisualController.gd")

@onready var tank_instance: A47_Mastodon_Vehicle = $A47_Mastodon
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

# Camera Orbit variables
var camera_distance: float = 9.5
var camera_pitch: float = deg_to_rad(-18.0)
var camera_yaw: float = deg_to_rad(35.0)
var is_dragging: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO

# UI references
var ui_root: Control
var readout_title: Label
var readout_body: Label
var component_selector: OptionButton
var turret_slider: HSlider
var gun_slider: HSlider
var wheel_active: bool = false

func _ready() -> void:
	_setup_environment()
	_build_inspection_ui()
	_update_camera()

func _setup_environment() -> void:
	# Add ground plane grid for scale
	var grid = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(25.0, 25.0)
	grid.mesh = plane
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.14, 0.16)
	mat.roughness = 0.9
	grid.material_override = mat
	add_child(grid)

func _build_inspection_ui() -> void:
	var canvas = CanvasLayer.new()
	add_child(canvas)
	
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui_root)
	
	# Top Title Banner
	var top_panel = _create_panel(ui_root, 0.25, 0.01, 0.75, 0.08)
	var title = Label.new()
	title.text = "A-47 MASTODON HEAVY CRUISER • TECHNICAL INSPECTION SUITE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	top_panel.add_child(title)
	
	# Left Panel: Visual Modes & Inspector
	var left_panel = _create_panel(ui_root, 0.01, 0.09, 0.24, 0.98)
	var lbl_modes = Label.new()
	lbl_modes.text = "DISPLAY MODES (Keys 1-5)"
	lbl_modes.add_theme_font_size_override("font_size", 13)
	left_panel.add_child(lbl_modes)
	
	_create_button(left_panel, "1. Normal Exterior", func(): tank_instance.set_display_mode(MastodonVisualController.DisplayMode.NORMAL))
	_create_button(left_panel, "2. X-Ray View (Translucent Armor)", func(): tank_instance.set_display_mode(MastodonVisualController.DisplayMode.XRAY))
	_create_button(left_panel, "3. Cutaway View (Hide Armor)", func(): tank_instance.set_display_mode(MastodonVisualController.DisplayMode.CUTAWAY))
	_create_button(left_panel, "4. Crew Focus", func(): tank_instance.set_display_mode(MastodonVisualController.DisplayMode.CREW_FOCUS))
	_create_button(left_panel, "5. Components & Ammo Focus", func(): tank_instance.set_display_mode(MastodonVisualController.DisplayMode.COMPONENT_FOCUS))
	_create_button(left_panel, "Armor Thickness Analysis", func(): tank_instance.set_display_mode(MastodonVisualController.DisplayMode.ARMOR_FOCUS))
	
	var sep1 = HSeparator.new()
	left_panel.add_child(sep1)
	
	var lbl_insp = Label.new()
	lbl_insp.text = "COMPONENT / ARMOR INSPECTOR"
	lbl_insp.add_theme_font_size_override("font_size", 13)
	left_panel.add_child(lbl_insp)
	
	component_selector = OptionButton.new()
	component_selector.add_item("-- Select Component / Armor --")
	_populate_component_selector()
	component_selector.item_selected.connect(_on_component_selected)
	left_panel.add_child(component_selector)
	
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.04, 0.07, 0.10, 0.85)
	card_style.set_corner_radius_all(4)
	card_style.content_margin_left = 8
	card_style.content_margin_top = 8
	card_style.content_margin_right = 8
	card_style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", card_style)
	left_panel.add_child(card)
	
	var card_box = VBoxContainer.new()
	card.add_child(card_box)
	
	readout_title = Label.new()
	readout_title.text = "ITEM: Select an object"
	readout_title.add_theme_font_size_override("font_size", 13)
	card_box.add_child(readout_title)
	
	readout_body = Label.new()
	readout_body.text = "Select any component, crew member, or armor plate to inspect engineering data."
	readout_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	readout_body.add_theme_font_size_override("font_size", 12)
	card_box.add_child(readout_body)
	
	# Right Panel: Functional Animation Controls
	var right_panel = _create_panel(ui_root, 0.76, 0.09, 0.99, 0.98)
	var lbl_anim = Label.new()
	lbl_anim.text = "ARTICULATION & SYSTEMS"
	lbl_anim.add_theme_font_size_override("font_size", 13)
	right_panel.add_child(lbl_anim)
	
	# Gun & Turret
	var lbl_turret = Label.new()
	lbl_turret.text = "Turret Traverse"
	lbl_turret.add_theme_font_size_override("font_size", 12)
	right_panel.add_child(lbl_turret)
	
	turret_slider = HSlider.new()
	turret_slider.min_value = -180
	turret_slider.max_value = 180
	turret_slider.value = 0
	turret_slider.value_changed.connect(func(v): tank_instance.rotate_turret(deg_to_rad(v)))
	right_panel.add_child(turret_slider)
	
	var lbl_elev = Label.new()
	lbl_elev.text = "Gun Elevation (-8° to +20°)"
	lbl_elev.add_theme_font_size_override("font_size", 12)
	right_panel.add_child(lbl_elev)
	
	gun_slider = HSlider.new()
	gun_slider.min_value = -8
	gun_slider.max_value = 20
	gun_slider.value = 0
	gun_slider.value_changed.connect(func(v): tank_instance.elevate_gun(deg_to_rad(v)))
	right_panel.add_child(gun_slider)
	
	var fire_btn = _create_button(right_panel, "💥 FIRE CANNON / RECOIL (Space)", func(): tank_instance.fire_recoil())
	var fire_style = StyleBoxFlat.new()
	fire_style.bg_color = Color(0.65, 0.22, 0.15)
	fire_style.set_corner_radius_all(4)
	fire_btn.add_theme_stylebox_override("normal", fire_style)
	
	var sep2 = HSeparator.new()
	right_panel.add_child(sep2)
	
	# Hatches & Observer
	var lbl_hatches = Label.new()
	lbl_hatches.text = "HATCHES & SPOTTER"
	lbl_hatches.add_theme_font_size_override("font_size", 13)
	right_panel.add_child(lbl_hatches)
	
	_create_button(right_panel, "Commander Hatch (Key C)", func(): tank_instance.anim.toggle_commander_hatch())
	_create_button(right_panel, "Commander Spotter Exposed/Buttoned (Key E)", func(): tank_instance.anim.toggle_commander_posture())
	_create_button(right_panel, "Loader Hatch (Key L)", func(): tank_instance.anim.toggle_loader_hatch())
	_create_button(right_panel, "Driver Hatch (Key D)", func(): tank_instance.anim.toggle_driver_hatch())
	
	var sep3 = HSeparator.new()
	right_panel.add_child(sep3)
	
	# Running Gear
	_create_button(right_panel, "Drive Wheels / Tracks (Key W)", func():
		wheel_active = not wheel_active
		tank_instance.set_wheel_speed(4.0 if wheel_active else 0.0)
	)
	
	var help_lbl = Label.new()
	help_lbl.text = "Controls: Right-drag to Orbit • Wheel to Zoom • Shift-Drag to Pan"
	help_lbl.add_theme_font_size_override("font_size", 11)
	help_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_panel.add_child(help_lbl)

func _create_panel(parent: Control, left: float, top: float, right: float, bottom: float) -> VBoxContainer:
	var panel = PanelContainer.new()
	parent.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.anchor_left = left
	panel.anchor_top = top
	panel.anchor_right = right
	panel.anchor_bottom = bottom
	panel.offset_left = 6
	panel.offset_top = 6
	panel.offset_right = -6
	panel.offset_bottom = -6
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.04, 0.06, 0.78)
	style.border_color = Color(0.25, 0.38, 0.45, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)
	return box

func _create_button(parent: Node, caption: String, callback: Callable) -> Button:
	var btn = Button.new()
	btn.text = caption
	btn.custom_minimum_size.y = 28
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn

func _populate_component_selector() -> void:
	if not tank_instance or not tank_instance.metadata: return
	for arm in tank_instance.metadata.get_all_armor_names():
		component_selector.add_item(arm)
	for cmp in tank_instance.metadata.get_all_component_names():
		component_selector.add_item(cmp)
	for crw in tank_instance.metadata.get_all_crew_names():
		component_selector.add_item(crw)
	for rck in tank_instance.metadata.get_all_ammo_names():
		component_selector.add_item(rck)

func _on_component_selected(index: int) -> void:
	if index <= 0: return
	var item_name = component_selector.get_item_text(index)
	tank_instance.highlight_component(item_name)
	var info = tank_instance.get_component_info(item_name)
	
	readout_title.text = item_name
	var lines = []
	if item_name.begins_with("ARM_"):
		lines.append("Category: Armor Section")
		lines.append("Thickness: %d mm %s" % [info.get("thickness_mm", 0), info.get("material", "RHA")])
		lines.append("Slope Angle: %d°" % info.get("slope_deg", 0))
		lines.append("Zone: %s" % info.get("zone", "General"))
		lines.append("Spall Coefficient: %.1f" % info.get("spall_coefficient", 1.0))
	elif item_name.begins_with("CMP_"):
		lines.append("Category: Mechanical Component")
		lines.append("Subsystem: %s" % info.get("system", "Mechanical").capitalize())
		lines.append("Structural Durability: %d HP" % info.get("hp", 100))
		if info.has("capacity_liters"):
			lines.append("Fuel Capacity: %d Liters" % info.get("capacity_liters"))
	elif item_name.begins_with("CREW_"):
		lines.append("Category: Crew Member")
		lines.append("Role: %s" % info.get("role", "Crew"))
		lines.append("Station: %s" % info.get("location", "Vehicle").capitalize())
		lines.append("Casualty Status: Fit / Active")
	elif item_name.begins_with("AMMO_"):
		lines.append("Category: Ammunition Rack")
		lines.append("Location: %s" % info.get("location", "Rack").capitalize())
		lines.append("Shell Capacity: %d Rounds" % info.get("capacity", 0))
		lines.append("Caliber: 92mm High-Velocity AP/HE")
		
	readout_body.text = "\n".join(lines)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			is_dragging = event.pressed
			last_mouse_pos = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = maxf(4.0, camera_distance - 0.5)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = minf(20.0, camera_distance + 0.5)
			_update_camera()
			
	elif event is InputEventMouseMotion and is_dragging:
		var delta = event.position - last_mouse_pos
		last_mouse_pos = event.position
		camera_yaw += delta.x * 0.008
		camera_pitch = clampf(camera_pitch - delta.y * 0.008, deg_to_rad(-80.0), deg_to_rad(20.0))
		_update_camera()
		
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: tank_instance.set_display_mode(MastodonVisualController.DisplayMode.NORMAL)
			KEY_2: tank_instance.set_display_mode(MastodonVisualController.DisplayMode.XRAY)
			KEY_3: tank_instance.set_display_mode(MastodonVisualController.DisplayMode.CUTAWAY)
			KEY_4: tank_instance.set_display_mode(MastodonVisualController.DisplayMode.CREW_FOCUS)
			KEY_5: tank_instance.set_display_mode(MastodonVisualController.DisplayMode.COMPONENT_FOCUS)
			KEY_SPACE: tank_instance.fire_recoil()
			KEY_C: tank_instance.anim.toggle_commander_hatch()
			KEY_L: tank_instance.anim.toggle_loader_hatch()
			KEY_D: tank_instance.anim.toggle_driver_hatch()
			KEY_E: tank_instance.anim.toggle_commander_posture()
			KEY_W:
				wheel_active = not wheel_active
				tank_instance.set_wheel_speed(4.0 if wheel_active else 0.0)

func _update_camera() -> void:
	camera_pivot.rotation = Vector3(camera_pitch, camera_yaw, 0)
	camera.position = Vector3(0, 1.4, camera_distance)
	camera.look_at(camera_pivot.position + Vector3(0, 1.4, 0))
