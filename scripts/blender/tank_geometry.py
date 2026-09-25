"""
A-47 Mastodon - Mesh & Primitive Geometry Generators
Provides procedural construction functions for armor, mechanical components, crew figures, and running gear.
"""

import bpy
import bmesh
import math
from mathutils import Vector, Matrix, Euler

def ensure_collection(name, parent_col=None):
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        if parent_col:
            parent_col.children.link(col)
        else:
            bpy.context.scene.collection.children.link(col)
    return col

def link_to_collection(obj, collection):
    if collection is None:
        collection = bpy.context.scene.collection
    for col in obj.users_collection:
        col.objects.unlink(obj)
    collection.objects.link(obj)

def create_box(name, size, location, rotation=(0, 0, 0), material=None, parent=None, collection=None):
    mesh = bpy.data.meshes.new(name + "_Mesh")
    obj = bpy.data.objects.new(name, mesh)
    
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
    bm.to_mesh(mesh)
    bm.free()
    
    obj.location = location
    obj.rotation_euler = Euler(rotation, 'XYZ')
    if parent:
        obj.parent = parent
    if material:
        obj.data.materials.append(material)
    
    link_to_collection(obj, collection)
    return obj

def create_cylinder(name, radius, depth, location, rotation=(0, 0, 0), vertices=24, material=None, parent=None, collection=None):
    mesh = bpy.data.meshes.new(name + "_Mesh")
    obj = bpy.data.objects.new(name, mesh)
    
    bm = bmesh.new()
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=vertices,
        radius1=radius,
        radius2=radius,
        depth=depth
    )
    bm.to_mesh(mesh)
    bm.free()
    
    obj.location = location
    obj.rotation_euler = Euler(rotation, 'XYZ')
    if parent:
        obj.parent = parent
    if material:
        obj.data.materials.append(material)
    
    link_to_collection(obj, collection)
    return obj

def create_empty(name, location, rotation=(0, 0, 0), parent=None, collection=None, empty_type='PLAIN_AXES', size=0.25):
    empty = bpy.data.objects.new(name, None)
    empty.empty_display_type = empty_type
    empty.empty_display_size = size
    empty.location = location
    empty.rotation_euler = Euler(rotation, 'XYZ')
    if parent:
        empty.parent = parent
    link_to_collection(empty, collection)
    return empty

def create_human_figure(name, location, seated=True, facing_y_pos=True, uniform_mat=None, skin_mat=None, parent=None, collection=None):
    """
    Creates a proportioned 5-part stylized human crew figure for spatial validation and X-ray damage detection.
    Scale: approx 1.76m tall standing, 0.44m shoulder width.
    """
    mesh = bpy.data.meshes.new(name + "_Mesh")
    obj = bpy.data.objects.new(name, mesh)
    
    bm = bmesh.new()
    
    # Orientation multiplier
    y_mult = 1.0 if facing_y_pos else -1.0
    
    # Head & Helmet (at local Z +0.55 relative to torso center)
    head_loc = Vector((0.0, 0.02 * y_mult, 0.58))
    bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=0.11, matrix=Matrix.Translation(head_loc))
    # Helmet rim / goggles visor
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation(head_loc + Vector((0, 0.05 * y_mult, 0.02))) @ Matrix.Diagonal((0.18, 0.12, 0.04, 1.0)))
    
    # Torso (chest + abdomen)
    torso_mat = Matrix.Translation(Vector((0, 0, 0.22))) @ Matrix.Diagonal((0.42, 0.26, 0.48, 1.0))
    bmesh.ops.create_cube(bm, size=1.0, matrix=torso_mat)
    
    # Arms
    for side in [-1, 1]:
        # Upper arm
        arm_mat = Matrix.Translation(Vector((side * 0.24, 0.05 * y_mult, 0.28))) @ Matrix.Diagonal((0.11, 0.11, 0.28, 1.0))
        bmesh.ops.create_cube(bm, size=1.0, matrix=arm_mat)
        # Forearm forward to controls
        forearm_mat = Matrix.Translation(Vector((side * 0.22, 0.22 * y_mult, 0.18))) @ Matrix.Diagonal((0.09, 0.26, 0.09, 1.0))
        bmesh.ops.create_cube(bm, size=1.0, matrix=forearm_mat)
    
    if seated:
        # Seated posture: Thighs extend forward horizontally, lower legs vertical down
        for side in [-1, 1]:
            # Thigh forward
            thigh_mat = Matrix.Translation(Vector((side * 0.13, 0.22 * y_mult, -0.05))) @ Matrix.Diagonal((0.14, 0.42, 0.14, 1.0))
            bmesh.ops.create_cube(bm, size=1.0, matrix=thigh_mat)
            # Shin down
            shin_mat = Matrix.Translation(Vector((side * 0.13, 0.40 * y_mult, -0.28))) @ Matrix.Diagonal((0.12, 0.12, 0.38, 1.0))
            bmesh.ops.create_cube(bm, size=1.0, matrix=shin_mat)
            # Boots
            boot_mat = Matrix.Translation(Vector((side * 0.13, 0.46 * y_mult, -0.46))) @ Matrix.Diagonal((0.13, 0.24, 0.10, 1.0))
            bmesh.ops.create_cube(bm, size=1.0, matrix=boot_mat)
    else:
        # Standing posture (Loader)
        for side in [-1, 1]:
            # Leg standing straight
            leg_mat = Matrix.Translation(Vector((side * 0.13, 0.0, -0.26))) @ Matrix.Diagonal((0.14, 0.16, 0.58, 1.0))
            bmesh.ops.create_cube(bm, size=1.0, matrix=leg_mat)
            # Boots
            boot_mat = Matrix.Translation(Vector((side * 0.13, 0.04 * y_mult, -0.56))) @ Matrix.Diagonal((0.13, 0.24, 0.10, 1.0))
            bmesh.ops.create_cube(bm, size=1.0, matrix=boot_mat)
    
    bm.to_mesh(mesh)
    bm.free()
    
    obj.location = location
    if parent:
        obj.parent = parent
    if uniform_mat:
        obj.data.materials.append(uniform_mat)
    
    link_to_collection(obj, collection)
    return obj

def create_road_wheel(name, location, radius=0.36, width=0.22, parent=None, collection=None, steel_mat=None, rubber_mat=None):
    """
    Creates a dual-dish road wheel with rubber tire rim and central hub cap.
    """
    mesh = bpy.data.meshes.new(name + "_Mesh")
    obj = bpy.data.objects.new(name, mesh)
    
    bm = bmesh.new()
    
    # Rotation matrix to orient cylinder along X-axis (rotation axis for wheels)
    rot_x = Matrix.Rotation(math.pi / 2, 4, 'Y')
    
    # Rubber tire outer band
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=24,
        radius1=radius,
        radius2=radius,
        depth=width,
        matrix=rot_x
    )
    
    # Steel dish inner wheel
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=20,
        radius1=radius * 0.78,
        radius2=radius * 0.78,
        depth=width * 1.08,
        matrix=rot_x
    )
    
    # Center hub cap
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=16,
        radius1=radius * 0.28,
        radius2=radius * 0.22,
        depth=width * 1.25,
        matrix=rot_x
    )
    
    bm.to_mesh(mesh)
    bm.free()
    
    obj.location = location
    if parent:
        obj.parent = parent
    if steel_mat:
        obj.data.materials.append(steel_mat)
    if rubber_mat:
        obj.data.materials.append(rubber_mat)
        
    link_to_collection(obj, collection)
    return obj

def create_sprocket_wheel(name, location, radius=0.38, width=0.24, teeth=14, parent=None, collection=None, steel_mat=None):
    mesh = bpy.data.meshes.new(name + "_Mesh")
    obj = bpy.data.objects.new(name, mesh)
    bm = bmesh.new()
    
    rot_x = Matrix.Rotation(math.pi / 2, 4, 'Y')
    
    # Main drum
    bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=24,
        radius1=radius * 0.88, radius2=radius * 0.88, depth=width, matrix=rot_x
    )
    # Dual rings with sprocket teeth
    for x_off in [-width * 0.42, width * 0.42]:
        for i in range(teeth):
            angle = i * (2 * math.pi / teeth)
            tooth_pos = Vector((x_off, math.sin(angle) * radius * 0.96, math.cos(angle) * radius * 0.96))
            tooth_rot = Matrix.Translation(tooth_pos) @ Matrix.Rotation(angle, 4, 'X') @ Matrix.Diagonal((0.035, 0.05, 0.08, 1.0))
            bmesh.ops.create_cube(bm, size=1.0, matrix=tooth_rot)
            
    bm.to_mesh(mesh)
    bm.free()
    
    obj.location = location
    if parent:
        obj.parent = parent
    if steel_mat:
        obj.data.materials.append(steel_mat)
    link_to_collection(obj, collection)
    return obj

def create_ammo_rack(name, location, size, rows, cols, parent=None, collection=None, brass_mat=None, steel_mat=None):
    """
    Creates an ammunition rack with a structural armored casing and individual modeled shells.
    """
    mesh = bpy.data.meshes.new(name + "_Mesh")
    obj = bpy.data.objects.new(name, mesh)
    bm = bmesh.new()
    
    # Outer frame
    frame_mat = Matrix.Diagonal((size[0], size[1], size[2], 1.0))
    bmesh.ops.create_cube(bm, size=1.0, matrix=frame_mat)
    
    # Shell slots
    dx = size[0] / (cols + 1)
    dz = size[2] / (rows + 1)
    cal_radius = 0.046  # 92mm diameter -> 46mm radius
    shell_len = min(size[1] * 0.9, 0.65)
    
    for r in range(rows):
        for c in range(cols):
            x = -size[0] * 0.5 + (c + 1) * dx
            z = -size[2] * 0.5 + (r + 1) * dz
            # Shell casing cylinder (horizontal along Y)
            casing_mat = Matrix.Translation(Vector((x, 0, z))) @ Matrix.Rotation(math.pi / 2, 4, 'X')
            bmesh.ops.create_cone(
                bm, cap_ends=True, cap_tris=False, segments=12,
                radius1=cal_radius, radius2=cal_radius, depth=shell_len * 0.65,
                matrix=casing_mat
            )
            # Shell warhead cone
            warhead_mat = Matrix.Translation(Vector((x, shell_len * 0.38, z))) @ Matrix.Rotation(-math.pi / 2, 4, 'X')
            bmesh.ops.create_cone(
                bm, cap_ends=True, cap_tris=False, segments=12,
                radius1=cal_radius * 0.95, radius2=0.01, depth=shell_len * 0.35,
                matrix=warhead_mat
            )
            
    bm.to_mesh(mesh)
    bm.free()
    
    obj.location = location
    if parent:
        obj.parent = parent
    if brass_mat:
        obj.data.materials.append(brass_mat)
    if steel_mat:
        obj.data.materials.append(steel_mat)
    link_to_collection(obj, collection)
    return obj
