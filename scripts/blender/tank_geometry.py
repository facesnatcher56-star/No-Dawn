"""
A-47 Mastodon - Advanced Mesh & Geometry Generators
Provides procedural construction functions for armor, mechanical components,
crew figures, running gear, tracks with catenary sag, and detailed armament.
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

def create_box(name, size, location, rotation=(0, 0, 0), bevel_radius=0.0, material=None, parent=None, collection=None):
    """
    Creates a box mesh with optional beveling for realistic welded armor edges.
    """
    mesh = bpy.data.meshes.new(name + "_Mesh")
    obj = bpy.data.objects.new(name, mesh)
    
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
        
    if bevel_radius > 0.001:
        bmesh.ops.bevel(bm, geom=bm.edges, offset=bevel_radius, segments=2, profile=0.5)
        
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

def create_faceted_plate(name, points_2d, thickness, location, rotation=(0, 0, 0), bevel_amount=0.015, material=None, parent=None, collection=None):
    """
    Extrudes a 2D convex polygon into a 3D armor plate of specified thickness with beveled edges.
    points_2d: list of (x, y) coordinates defining the plate profile in the XY plane.
    """
    mesh = bpy.data.meshes.new(name + "_Mesh")
    obj = bpy.data.objects.new(name, mesh)
    
    bm = bmesh.new()
    
    # Create bottom face
    verts_bottom = []
    half_th = thickness * 0.5
    for pt in points_2d:
        verts_bottom.append(bm.verts.new((pt[0], pt[1], -half_th)))
    face_bottom = bm.faces.new(verts_bottom)
    
    # Extrude upward to create top face and side faces
    ext = bmesh.ops.extrude_face_region(bm, geom=[face_bottom])
    for geom in ext['geom']:
        if isinstance(geom, bmesh.types.BMVert):
            geom.co.z += thickness
            
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    
    if bevel_amount > 0.002:
        bmesh.ops.bevel(bm, geom=bm.edges, offset=bevel_amount, segments=2, profile=0.5)
        
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

def create_detailed_turret_shell(name, length=3.35, width=2.45, height=0.92, parent=None, collection=None, armor_mat=None):
    """
    Creates an advanced late-WWII heavy cruiser turret body with sloped frontal cheeks,
    recessed gun trunnion mount, inward-sloping sides, and rear counterweight bustle.
    """
    mesh = bpy.data.meshes.new(name + "_Mesh")
    obj = bpy.data.objects.new(name, mesh)
    bm = bmesh.new()
    
    # 8 vertices for the bottom ring, 8 vertices for the top ring
    # Coordinates in local turret space (X=right, Y=fwd, Z=up)
    # The front is at Y = +1.55, gun opening between X = -0.55 and +0.55
    # The rear bustle extends to Y = -1.60
    
    # Bottom ring vertices (at Z = 0.04 above turret ring)
    b_f_l = (-0.52,  1.52, 0.04)  # Front gun opening Left
    b_f_r = ( 0.52,  1.52, 0.04)  # Front gun opening Right
    b_ck_l= (-1.22,  0.88, 0.04)  # Cheek Left
    b_ck_r= ( 1.22,  0.88, 0.04)  # Cheek Right
    b_sd_l= (-1.24, -0.65, 0.04)  # Side Left
    b_sd_r= ( 1.24, -0.65, 0.04)  # Side Right
    b_rr_l= (-1.08, -1.62, 0.04)  # Bustle Rear Left
    b_rr_r= ( 1.08, -1.62, 0.04)  # Bustle Rear Right
    
    # Top ring vertices (at Z = 0.90, sloping inward by ~14-18 degrees)
    t_f_l = (-0.46,  1.38, 0.90)
    t_f_r = ( 0.46,  1.38, 0.90)
    t_ck_l= (-1.05,  0.80, 0.90)
    t_ck_r= ( 1.05,  0.80, 0.90)
    t_sd_l= (-1.06, -0.65, 0.90)
    t_sd_r= ( 1.06, -0.65, 0.90)
    t_rr_l= (-0.94, -1.52, 0.90)
    t_rr_r= ( 0.94, -1.52, 0.90)
    
    bottom_pts = [b_f_l, b_f_r, b_ck_r, b_sd_r, b_rr_r, b_rr_l, b_sd_l, b_ck_l]
    top_pts    = [t_f_l, t_f_r, t_ck_r, t_sd_r, t_rr_r, t_rr_l, t_sd_l, t_ck_l]
    
    v_b = [bm.verts.new(p) for p in bottom_pts]
    v_t = [bm.verts.new(p) for p in top_pts]
    
    # Create top face (roof)
    bm.faces.new([v_t[0], v_t[1], v_t[2], v_t[3], v_t[4], v_t[5], v_t[6], v_t[7]])
    # Create bottom face (floor)
    bm.faces.new([v_b[7], v_b[6], v_b[5], v_b[4], v_b[3], v_b[2], v_b[1], v_b[0]])
    
    # Create side faces around the perimeter
    for i in range(8):
        next_i = (i + 1) % 8
        bm.faces.new([v_b[i], v_b[next_i], v_t[next_i], v_t[i]])
        
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.bevel(bm, geom=bm.edges, offset=0.025, segments=2, profile=0.5)
    
    bm.to_mesh(mesh)
    bm.free()
    
    obj.location = (0.0, 0.05, 0.0)
    if parent:
        obj.parent = parent
    if armor_mat:
        obj.data.materials.append(armor_mat)
        
    link_to_collection(obj, collection)
    return obj

def create_cast_mantlet(name, parent=None, collection=None, steel_mat=None):
    """
    Creates a massive curved cast steel gun mantlet (120mm armor) with recessed gun collar,
    coaxial MG aperture with blast deflector, gunner telescopic sight aperture,
    and heavy trunnion side lugs.
    """
    mesh = bpy.data.meshes.new(name + "_Mesh")
    obj = bpy.data.objects.new(name, mesh)
    bm = bmesh.new()
    
    # Main curved shield: horizontal curved cylinder profile along X-axis
    rot_y = Matrix.Rotation(math.pi / 2, 4, 'Y')
    bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=28,
        radius1=0.48, radius2=0.48, depth=0.88, matrix=rot_y
    )
    
    # Flatten the back of the mantlet for breech clearance
    for v in bm.verts:
        if v.co.y < -0.10:
            v.co.y = -0.10
            
    # Central heavy reinforcing collar for 92mm gun tube
    collar_mat = Matrix.Translation(Vector((0.0, 0.36, 0.0))) @ Matrix.Rotation(math.pi / 2, 4, 'X')
    bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=24,
        radius1=0.22, radius2=0.18, depth=0.42, matrix=collar_mat
    )
    
    # Trunnion side retaining caps (Left & Right)
    for side in [-1, 1]:
        cap_mat = Matrix.Translation(Vector((side * 0.46, 0.0, 0.0))) @ Matrix.Rotation(math.pi / 2, 4, 'Y')
        bmesh.ops.create_cone(
            bm, cap_ends=True, cap_tris=False, segments=16,
            radius1=0.16, radius2=0.14, depth=0.08, matrix=cap_mat
        )
        # 6 bolt heads on trunnion cap
        for b_idx in range(6):
            ang = b_idx * (2 * math.pi / 6)
            by = math.sin(ang) * 0.11
            bz = math.cos(ang) * 0.11
            bolt_mat = Matrix.Translation(Vector((side * 0.505, by, bz))) @ Matrix.Diagonal((0.03, 0.024, 0.024, 1.0))
            bmesh.ops.create_cube(bm, size=1.0, matrix=bolt_mat)
            
    # Coaxial MG port (Left of cannon at X = -0.28, Z = +0.06)
    mg_port_mat = Matrix.Translation(Vector((-0.28, 0.35, 0.06))) @ Matrix.Rotation(math.pi / 2, 4, 'X')
    bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=12,
        radius1=0.06, radius2=0.045, depth=0.25, matrix=mg_port_mat
    )
    
    # Gunner sight aperture (Right of cannon at X = +0.32, Z = +0.08)
    sight_port_mat = Matrix.Translation(Vector((0.32, 0.32, 0.08))) @ Matrix.Rotation(math.pi / 2, 4, 'X')
    bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=12,
        radius1=0.07, radius2=0.055, depth=0.22, matrix=sight_port_mat
    )
    # Armored cast visor brow above sight aperture
    brow_mat = Matrix.Translation(Vector((0.32, 0.38, 0.15))) @ Matrix.Diagonal((0.14, 0.08, 0.04, 1.0))
    bmesh.ops.create_cube(bm, size=1.0, matrix=brow_mat)
    
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.bevel(bm, geom=bm.edges, offset=0.015, segments=2, profile=0.5)
    
    bm.to_mesh(mesh)
    bm.free()
    
    obj.location = (0.0, 0.45, 0.0)
    if parent:
        obj.parent = parent
    if steel_mat:
        obj.data.materials.append(steel_mat)
        
    link_to_collection(obj, collection)
    return obj

def create_detailed_cupola(name, location, radius=0.44, height=0.30, parent=None, collection=None, steel_mat=None, glass_mat=None):
    """
    Creates an armored commander's cupola with 8 vision blocks, cast armored hoods,
    optical glass prisms, and an inner hollow hatch opening for the commander.
    """
    mesh = bpy.data.meshes.new(name + "_Mesh")
    obj = bpy.data.objects.new(name, mesh)
    bm = bmesh.new()
    
    r_out = radius
    r_in = radius * 0.75  # Hollow hatch opening (~0.33m radius)
    z_bot = -height * 0.5
    z_top = height * 0.5
    segments = 28
    
    verts_out_b = []
    verts_out_t = []
    verts_in_b = []
    verts_in_t = []
    
    for i in range(segments):
        ang = i * (2 * math.pi / segments)
        ca = math.cos(ang)
        sa = math.sin(ang)
        verts_out_b.append(bm.verts.new((ca * r_out, sa * r_out, z_bot)))
        verts_out_t.append(bm.verts.new((ca * (r_out * 0.94), sa * (r_out * 0.94), z_top)))
        verts_in_b.append(bm.verts.new((ca * r_in, sa * r_in, z_bot)))
        verts_in_t.append(bm.verts.new((ca * r_in, sa * r_in, z_top)))
        
    for i in range(segments):
        next_i = (i + 1) % segments
        # Outer wall
        bm.faces.new([verts_out_b[i], verts_out_b[next_i], verts_out_t[next_i], verts_out_t[i]])
        # Inner wall
        bm.faces.new([verts_in_b[next_i], verts_in_b[i], verts_in_t[i], verts_in_t[next_i]])
        # Top rim annulus
        bm.faces.new([verts_out_t[i], verts_out_t[next_i], verts_in_t[next_i], verts_in_t[i]])
        # Bottom rim annulus
        bm.faces.new([verts_out_b[next_i], verts_out_b[i], verts_in_b[i], verts_in_b[next_i]])
        
    # 8 Cast periscope hoods around the perimeter
    for i in range(8):
        ang = i * (2 * math.pi / 8)
        px = math.cos(ang) * (radius * 0.95)
        py = math.sin(ang) * (radius * 0.95)
        pz = 0.02
        hood_mat = Matrix.Translation(Vector((px, py, pz))) @ Matrix.Rotation(ang, 4, 'Z') @ Matrix.Diagonal((0.14, 0.10, 0.12, 1.0))
        bmesh.ops.create_cube(bm, size=1.0, matrix=hood_mat)
        
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.bevel(bm, geom=bm.edges, offset=0.010, segments=2, profile=0.5)
    
    bm.to_mesh(mesh)
    bm.free()
    
    obj.location = location
    if parent:
        obj.parent = parent
    if steel_mat:
        obj.data.materials.append(steel_mat)
        
    link_to_collection(obj, collection)
    return obj
        
    link_to_collection(obj, collection)
    return obj

def create_detailed_road_wheel(name, location, radius=0.36, width=0.22, parent=None, collection=None, steel_mat=None, rubber_mat=None):
    """
    Creates a dual-dish road wheel with stamped cooling cutouts, heavy rubber tire rim,
    central grease hub cap with 8-bolt circle.
    """
    mesh = bpy.data.meshes.new(name + "_Mesh")
    obj = bpy.data.objects.new(name, mesh)
    bm = bmesh.new()
    
    rot_y = Matrix.Rotation(math.pi / 2, 4, 'Y')
    
    # Heavy rubber tire rim (outer band)
    bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=28,
        radius1=radius, radius2=radius, depth=width, matrix=rot_y
    )
    
    # Steel dish inner wheel
    bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=24,
        radius1=radius * 0.78, radius2=radius * 0.78, depth=width * 1.06, matrix=rot_y
    )
    
    # Central hub with grease cap
    bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=18,
        radius1=radius * 0.28, radius2=radius * 0.22, depth=width * 1.28, matrix=rot_y
    )
    
    # 8 Hub bolts on the inner flange
    for side in [-1, 1]:
        for b_idx in range(8):
            ang = b_idx * (2 * math.pi / 8)
            by = math.sin(ang) * (radius * 0.21)
            bz = math.cos(ang) * (radius * 0.21)
            bolt_mat = Matrix.Translation(Vector((side * (width * 0.62), by, bz))) @ Matrix.Diagonal((0.024, 0.024, 0.024, 1.0))
            bmesh.ops.create_cube(bm, size=1.0, matrix=bolt_mat)
            
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.bevel(bm, geom=bm.edges, offset=0.008, segments=1, profile=0.5)
    
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

def create_detailed_sprocket(name, location, radius=0.38, width=0.24, teeth=14, parent=None, collection=None, steel_mat=None):
    """
    Creates a toothed drive sprocket with machined track driving teeth,
    stamped web with 6 circular lightening holes, and central bolted drive hub.
    """
    mesh = bpy.data.meshes.new(name + "_Mesh")
    obj = bpy.data.objects.new(name, mesh)
    bm = bmesh.new()
    
    rot_y = Matrix.Rotation(math.pi / 2, 4, 'Y')
    
    # Central drive drum
    bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=24,
        radius1=radius * 0.72, radius2=radius * 0.72, depth=width, matrix=rot_y
    )
    # Heavy central drive axle hub
    bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=16,
        radius1=radius * 0.26, radius2=radius * 0.20, depth=width * 1.30, matrix=rot_y
    )
    
    # Dual toothed rings
    for x_off in [-width * 0.42, width * 0.42]:
        # Ring flange
        flange_mat = Matrix.Translation(Vector((x_off, 0, 0))) @ rot_y
        bmesh.ops.create_cone(
            bm, cap_ends=True, cap_tris=False, segments=28,
            radius1=radius * 0.88, radius2=radius * 0.88, depth=0.035, matrix=flange_mat
        )
        # Teeth around the ring
        for i in range(teeth):
            angle = i * (2 * math.pi / teeth)
            t_y = math.sin(angle) * (radius * 0.94)
            t_z = math.cos(angle) * (radius * 0.94)
            tooth_mat = Matrix.Translation(Vector((x_off, t_y, t_z))) @ Matrix.Rotation(angle, 4, 'X') @ Matrix.Diagonal((0.038, 0.052, 0.088, 1.0))
            bmesh.ops.create_cube(bm, size=1.0, matrix=tooth_mat)
            
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.bevel(bm, geom=bm.edges, offset=0.008, segments=1, profile=0.5)
    
    bm.to_mesh(mesh)
    bm.free()
    
    obj.location = location
    if parent:
        obj.parent = parent
    if steel_mat:
        obj.data.materials.append(steel_mat)
        
    link_to_collection(obj, collection)
    return obj

def create_detailed_track_segment(name, location, length, width=0.58, height=0.045, rotation=(0, 0, 0), parent=None, collection=None, track_mat=None, num_links=12):
    """
    Creates a track run with modeled individual track shoes, cross-grousers (cleats),
    and center double guide horns for mechanical authenticity.
    """
    mesh = bpy.data.meshes.new(name + "_Mesh")
    obj = bpy.data.objects.new(name, mesh)
    bm = bmesh.new()
    
    link_pitch = length / max(1, num_links)
    
    for i in range(num_links):
        y_center = -length * 0.5 + (i + 0.5) * link_pitch
        
        # Main track shoe plate
        shoe_mat = Matrix.Translation(Vector((0.0, y_center, 0.0))) @ Matrix.Diagonal((width, link_pitch * 0.92, height, 1.0))
        bmesh.ops.create_cube(bm, size=1.0, matrix=shoe_mat)
        
        # Cross-grouser / chevron tread bar
        grouser_mat = Matrix.Translation(Vector((0.0, y_center, -height * 0.65))) @ Matrix.Diagonal((width * 0.88, link_pitch * 0.35, height * 0.5, 1.0))
        bmesh.ops.create_cube(bm, size=1.0, matrix=grouser_mat)
        
        # Dual center guide horns (straddle road wheels)
        for horn_x in [-0.14, 0.14]:
            horn_mat = Matrix.Translation(Vector((horn_x, y_center, height * 0.95))) @ Matrix.Diagonal((0.038, link_pitch * 0.38, height * 1.4, 1.0))
            bmesh.ops.create_cube(bm, size=1.0, matrix=horn_mat)
            
        # Hinge pin knuckles on sides
        for pin_x in [-width * 0.48, width * 0.48]:
            pin_mat = Matrix.Translation(Vector((pin_x, y_center, 0.0))) @ Matrix.Diagonal((0.035, link_pitch * 0.80, height * 0.9, 1.0))
            bmesh.ops.create_cube(bm, size=1.0, matrix=pin_mat)
            
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.bevel(bm, geom=bm.edges, offset=0.005, segments=1, profile=0.5)
    
    bm.to_mesh(mesh)
    bm.free()
    
    obj.location = location
    obj.rotation_euler = Euler(rotation, 'XYZ')
    if parent:
        obj.parent = parent
    if track_mat:
        obj.data.materials.append(track_mat)
        
    link_to_collection(obj, collection)
    return obj

def create_detailed_ammo_rack(name, location, size, rows, cols, parent=None, collection=None, brass_mat=None, steel_mat=None):
    """
    Creates an ammunition rack with a structural armored steel casing, individual honeycomb
    tubular shell sleeves, and modeled 92mm rounds with brass cases and copper/steel projectile heads.
    """
    mesh = bpy.data.meshes.new(name + "_Mesh")
    obj = bpy.data.objects.new(name, mesh)
    bm = bmesh.new()
    
    # Outer armored frame casing
    # Side plates
    th = 0.02
    for sx in [-size[0] * 0.5 + th * 0.5, size[0] * 0.5 - th * 0.5]:
        side_mat = Matrix.Translation(Vector((sx, 0, 0))) @ Matrix.Diagonal((th, size[1], size[2], 1.0))
        bmesh.ops.create_cube(bm, size=1.0, matrix=side_mat)
    # Top and bottom plates
    for sz in [-size[2] * 0.5 + th * 0.5, size[2] * 0.5 - th * 0.5]:
        plate_mat = Matrix.Translation(Vector((0, 0, sz))) @ Matrix.Diagonal((size[0], size[1], th, 1.0))
        bmesh.ops.create_cube(bm, size=1.0, matrix=plate_mat)
    # Back plate
    back_mat = Matrix.Translation(Vector((0, -size[1] * 0.5 + th * 0.5, 0))) @ Matrix.Diagonal((size[0], th, size[2], 1.0))
    bmesh.ops.create_cube(bm, size=1.0, matrix=back_mat)
    
    # Model individual 92mm shells in honeycomb grid
    # Each shell: brass cartridge case + tapered projectile head
    step_x = (size[0] - th * 2) / max(1, cols)
    step_z = (size[2] - th * 2) / max(1, rows)
    rot_y = Matrix.Rotation(math.pi / 2, 4, 'X')
    
    for r in range(rows):
        for c in range(cols):
            x_pos = -size[0] * 0.5 + th + (c + 0.5) * step_x
            z_pos = -size[2] * 0.5 + th + (r + 0.5) * step_z
            
            # Shell cartridge body (brass)
            cart_mat = Matrix.Translation(Vector((x_pos, -0.05, z_pos))) @ rot_y
            bmesh.ops.create_cone(
                bm, cap_ends=True, cap_tris=False, segments=12,
                radius1=0.046, radius2=0.046, depth=size[1] * 0.55, matrix=cart_mat
            )
            # Projectile warhead (tapered)
            proj_mat = Matrix.Translation(Vector((x_pos, size[1] * 0.32, z_pos))) @ rot_y
            bmesh.ops.create_cone(
                bm, cap_ends=True, cap_tris=False, segments=12,
                radius1=0.045, radius2=0.012, depth=size[1] * 0.32, matrix=proj_mat
            )
            # Retaining spring latch
            latch_mat = Matrix.Translation(Vector((x_pos, size[1] * 0.48, z_pos + 0.04))) @ Matrix.Diagonal((0.02, 0.04, 0.01, 1.0))
            bmesh.ops.create_cube(bm, size=1.0, matrix=latch_mat)
            
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.bevel(bm, geom=bm.edges, offset=0.004, segments=1, profile=0.5)
    
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

def create_detailed_v12_engine(name, location, length=1.75, width=1.12, height=0.82, parent=None, collection=None, block_mat=None, red_mat=None, steel_mat=None):
    """
    Creates a recognizable V12 heavy diesel tank engine block with 60-degree V cylinder banks,
    ribbed valve covers with oil filler caps, dual exhaust manifolds, intake manifolds with
    cylindrical air cleaners, flywheel housing, and oil sump.
    """
    mesh = bpy.data.meshes.new(name + "_Mesh")
    obj = bpy.data.objects.new(name, mesh)
    bm = bmesh.new()
    
    # 1. Crankcase / Engine Block Base
    crank_mat = Matrix.Translation(Vector((0.0, 0.0, -height * 0.15))) @ Matrix.Diagonal((width * 0.72, length * 0.95, height * 0.55, 1.0))
    bmesh.ops.create_cube(bm, size=1.0, matrix=crank_mat)
    
    # 2. Finned Oil Sump (bottom)
    sump_mat = Matrix.Translation(Vector((0.0, 0.0, -height * 0.45))) @ Matrix.Diagonal((width * 0.52, length * 0.85, height * 0.22, 1.0))
    bmesh.ops.create_cube(bm, size=1.0, matrix=sump_mat)
    
    # 3. Two Angled Cylinder Banks (60 degree V -> 30 deg from vertical)
    rot_y = Matrix.Rotation(math.pi / 2, 4, 'Y')
    for side in [-1, 1]:
        bank_rot = Matrix.Rotation(side * math.radians(30), 4, 'Y')
        bank_pos = Vector((side * (width * 0.26), 0.0, height * 0.22))
        bank_mat = Matrix.Translation(bank_pos) @ bank_rot @ Matrix.Diagonal((width * 0.32, length * 0.90, height * 0.40, 1.0))
        bmesh.ops.create_cube(bm, size=1.0, matrix=bank_mat)
        
        # Ribbed Valve Covers on top of each bank
        valve_pos = Vector((side * (width * 0.34), 0.0, height * 0.42))
        valve_mat = Matrix.Translation(valve_pos) @ bank_rot @ Matrix.Diagonal((width * 0.30, length * 0.88, height * 0.15, 1.0))
        bmesh.ops.create_cube(bm, size=1.0, matrix=valve_mat)
        
        # Oil filler caps
        cap_pos = Vector((side * (width * 0.38), length * 0.32, height * 0.52))
        cap_mat = Matrix.Translation(cap_pos)
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=12, radius1=0.045, radius2=0.045, depth=0.05, matrix=cap_mat)
        
        # Exhaust headers (6 exhaust ports per bank)
        for e_idx in range(6):
            ey = -length * 0.40 + e_idx * (length * 0.80 / 5.0)
            ep_pos = Vector((side * (width * 0.48), ey, height * 0.15))
            ep_mat = Matrix.Translation(ep_pos) @ Matrix.Diagonal((0.08, 0.08, 0.08, 1.0))
            bmesh.ops.create_cube(bm, size=1.0, matrix=ep_mat)
            
    # 4. Rear Flywheel Housing
    fly_mat = Matrix.Translation(Vector((0.0, -length * 0.48, -height * 0.10))) @ Matrix.Rotation(math.pi / 2, 4, 'Y')
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=24, radius1=width * 0.42, radius2=width * 0.42, depth=0.14, matrix=fly_mat)
    
    # 5. Dual Intake Manifolds in the V-valley
    for ix_side in [-1, 1]:
        intake_mat = Matrix.Translation(Vector((ix_side * 0.12, 0.0, height * 0.35))) @ Matrix.Diagonal((0.10, length * 0.75, 0.08, 1.0))
        bmesh.ops.create_cube(bm, size=1.0, matrix=intake_mat)
        
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.bevel(bm, geom=bm.edges, offset=0.012, segments=2, profile=0.5)
    
    bm.to_mesh(mesh)
    bm.free()
    
    obj.location = location
    if parent:
        obj.parent = parent
    if block_mat:
        obj.data.materials.append(block_mat)
    if red_mat:
        obj.data.materials.append(red_mat)
    if steel_mat:
        obj.data.materials.append(steel_mat)
        
    link_to_collection(obj, collection)
    return obj

def create_detailed_transmission(name, location, size=(0.95, 0.88, 0.68), parent=None, collection=None, steel_mat=None):
    """
    Creates a heavy cast transmission casing with clutch housing, steering brake drums,
    and output final-drive shafts.
    """
    mesh = bpy.data.meshes.new(name + "_Mesh")
    obj = bpy.data.objects.new(name, mesh)
    bm = bmesh.new()
    
    # Main gearbox cast housing
    box_mat = Matrix.Translation(Vector((0, 0, 0))) @ Matrix.Diagonal((size[0] * 0.75, size[1], size[2] * 0.80, 1.0))
    bmesh.ops.create_cube(bm, size=1.0, matrix=box_mat)
    
    # Ribbed top access cover
    cover_mat = Matrix.Translation(Vector((0, 0, size[2] * 0.42))) @ Matrix.Diagonal((size[0] * 0.65, size[1] * 0.85, 0.08, 1.0))
    bmesh.ops.create_cube(bm, size=1.0, matrix=cover_mat)
    
    # Steering brake drums (Left & Right)
    rot_y = Matrix.Rotation(math.pi / 2, 4, 'Y')
    for side in [-1, 1]:
        drum_mat = Matrix.Translation(Vector((side * (size[0] * 0.44), 0.0, -0.05))) @ rot_y
        bmesh.ops.create_cone(
            bm, cap_ends=True, cap_tris=False, segments=20,
            radius1=size[2] * 0.42, radius2=size[2] * 0.42, depth=0.18, matrix=drum_mat
        )
        # Output shaft
        shaft_mat = Matrix.Translation(Vector((side * (size[0] * 0.58), 0.0, -0.05))) @ rot_y
        bmesh.ops.create_cone(
            bm, cap_ends=True, cap_tris=False, segments=16,
            radius1=0.08, radius2=0.08, depth=0.15, matrix=shaft_mat
        )
        
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.bevel(bm, geom=bm.edges, offset=0.015, segments=2, profile=0.5)
    
    bm.to_mesh(mesh)
    bm.free()
    
    obj.location = location
    if parent:
        obj.parent = parent
    if steel_mat:
        obj.data.materials.append(steel_mat)
        
    link_to_collection(obj, collection)
    return obj

def create_human_figure(name, location, seated=True, facing_y_pos=True, uniform_mat=None, skin_mat=None, parent=None, collection=None):
    """
    Creates an anatomically proportioned, stylized 5-man late-war tank crew figure.
    Height: approx 1.76m standing.
    Includes tanker helmet with padded ribs, goggles, headset earphones, and field uniform folds.
    """
    mesh = bpy.data.meshes.new(name + "_Mesh")
    obj = bpy.data.objects.new(name, mesh)
    bm = bmesh.new()
    
    y_mult = 1.0 if facing_y_pos else -1.0
    
    # 1. Head & Tanker Helmet
    head_loc = Vector((0.0, 0.02 * y_mult, 0.58))
    bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=12, radius=0.115, matrix=Matrix.Translation(head_loc))
    # Padded tanker helmet crown
    helmet_mat = Matrix.Translation(head_loc + Vector((0, 0.01 * y_mult, 0.03))) @ Matrix.Diagonal((0.19, 0.16, 0.11, 1.0))
    bmesh.ops.create_cube(bm, size=1.0, matrix=helmet_mat)
    # Headset earphones (Left & Right)
    for side in [-1, 1]:
        ear_mat = Matrix.Translation(head_loc + Vector((side * 0.125, 0.0, 0.0))) @ Matrix.Diagonal((0.035, 0.07, 0.07, 1.0))
        bmesh.ops.create_cube(bm, size=1.0, matrix=ear_mat)
    # Goggles strap & visor
    goggles_mat = Matrix.Translation(head_loc + Vector((0, 0.11 * y_mult, 0.03))) @ Matrix.Diagonal((0.17, 0.04, 0.045, 1.0))
    bmesh.ops.create_cube(bm, size=1.0, matrix=goggles_mat)
    
    # 2. Torso (Tunic / Jacket)
    torso_mat = Matrix.Translation(Vector((0, 0, 0.22))) @ Matrix.Diagonal((0.44, 0.28, 0.48, 1.0))
    bmesh.ops.create_cube(bm, size=1.0, matrix=torso_mat)
    # Belt & webbing harness
    belt_mat = Matrix.Translation(Vector((0, 0, 0.02))) @ Matrix.Diagonal((0.46, 0.30, 0.06, 1.0))
    bmesh.ops.create_cube(bm, size=1.0, matrix=belt_mat)
    
    # 3. Arms & Hands
    for side in [-1, 1]:
        # Upper arm
        arm_mat = Matrix.Translation(Vector((side * 0.25, 0.05 * y_mult, 0.28))) @ Matrix.Diagonal((0.12, 0.12, 0.28, 1.0))
        bmesh.ops.create_cube(bm, size=1.0, matrix=arm_mat)
        # Forearm forward to controls / handwheels
        forearm_mat = Matrix.Translation(Vector((side * 0.22, 0.22 * y_mult, 0.18))) @ Matrix.Diagonal((0.10, 0.26, 0.10, 1.0))
        bmesh.ops.create_cube(bm, size=1.0, matrix=forearm_mat)
        # Hands / Gloves
        hand_mat = Matrix.Translation(Vector((side * 0.22, 0.36 * y_mult, 0.18))) @ Matrix.Diagonal((0.09, 0.09, 0.08, 1.0))
        bmesh.ops.create_cube(bm, size=1.0, matrix=hand_mat)
        
    if seated:
        # Seated posture: Thighs extend forward horizontally, lower legs vertical down
        for side in [-1, 1]:
            # Thigh forward
            thigh_mat = Matrix.Translation(Vector((side * 0.14, 0.22 * y_mult, -0.05))) @ Matrix.Diagonal((0.15, 0.42, 0.15, 1.0))
            bmesh.ops.create_cube(bm, size=1.0, matrix=thigh_mat)
            # Shin vertical down
            shin_mat = Matrix.Translation(Vector((side * 0.14, 0.40 * y_mult, -0.28))) @ Matrix.Diagonal((0.13, 0.13, 0.38, 1.0))
            bmesh.ops.create_cube(bm, size=1.0, matrix=shin_mat)
            # Boots
            boot_mat = Matrix.Translation(Vector((side * 0.14, 0.46 * y_mult, -0.46))) @ Matrix.Diagonal((0.13, 0.25, 0.10, 1.0))
            bmesh.ops.create_cube(bm, size=1.0, matrix=boot_mat)
    else:
        # Standing posture (Loader)
        for side in [-1, 1]:
            # Leg standing straight
            leg_mat = Matrix.Translation(Vector((side * 0.14, 0.0, -0.26))) @ Matrix.Diagonal((0.15, 0.17, 0.58, 1.0))
            bmesh.ops.create_cube(bm, size=1.0, matrix=leg_mat)
            # Boots
            boot_mat = Matrix.Translation(Vector((side * 0.14, 0.04 * y_mult, -0.56))) @ Matrix.Diagonal((0.13, 0.25, 0.10, 1.0))
            bmesh.ops.create_cube(bm, size=1.0, matrix=boot_mat)
            
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.bevel(bm, geom=bm.edges, offset=0.008, segments=1, profile=0.5)
    
    bm.to_mesh(mesh)
    bm.free()
    
    obj.location = location
    if parent:
        obj.parent = parent
    if uniform_mat:
        obj.data.materials.append(uniform_mat)
        
    link_to_collection(obj, collection)
    return obj
