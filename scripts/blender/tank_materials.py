"""
A-47 Mastodon - Blender Materials Setup
Defines standard PBR materials compatible with Godot glTF import.
"""

import bpy

def get_or_create_material(name, base_color, metallic=0.0, roughness=0.5, specular=0.5, transmission=0.0):
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name=name)
        mat.use_nodes = True
    
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    if bsdf is None:
        bsdf = nodes.new(type="ShaderNodeBsdfPrincipled")
        output = nodes.get("Material Output")
        if output is None:
            output = nodes.new(type="ShaderNodeOutputMaterial")
        mat.node_tree.links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
    
    # In Blender 4.x / 5.x, Principled BSDF socket names:
    # "Base Color", "Metallic", "Roughness", "IOR", "Transmission Weight"
    if "Base Color" in bsdf.inputs:
        bsdf.inputs["Base Color"].default_value = base_color
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = metallic
    if "Roughness" in bsdf.inputs:
        bsdf.inputs["Roughness"].default_value = roughness
    if "Transmission Weight" in bsdf.inputs:
        bsdf.inputs["Transmission Weight"].default_value = transmission
    elif "Transmission" in bsdf.inputs:
        bsdf.inputs["Transmission"].default_value = transmission
    
    return mat

def create_all_materials():
    materials = {
        # Exterior rolled armor: desaturated dark slate-olive green
        "MAT_Armor_Exterior": get_or_create_material(
            "MAT_Armor_Exterior", (0.22, 0.26, 0.20, 1.0), metallic=0.74, roughness=0.52
        ),
        # Interior painted armor: Elfenbein (warm ivory white for maximum cutaway visibility)
        "MAT_Armor_Interior": get_or_create_material(
            "MAT_Armor_Interior", (0.88, 0.86, 0.80, 1.0), metallic=0.06, roughness=0.62
        ),
        # Cast armor steel: pitted, heavy texture for mantlet, cupola, and nose
        "MAT_Steel_Cast": get_or_create_material(
            "MAT_Steel_Cast", (0.18, 0.20, 0.21, 1.0), metallic=0.88, roughness=0.58
        ),
        # Gunmetal: dark blued gun steel for main barrel, breech block, recoil shafts
        "MAT_Gunmetal": get_or_create_material(
            "MAT_Gunmetal", (0.12, 0.13, 0.15, 1.0), metallic=0.94, roughness=0.28
        ),
        # Engine block: industrial cast iron
        "MAT_Engine_Block": get_or_create_material(
            "MAT_Engine_Block", (0.15, 0.17, 0.18, 1.0), metallic=0.82, roughness=0.48
        ),
        # Engine valve covers: primer red
        "MAT_Engine_Red": get_or_create_material(
            "MAT_Engine_Red", (0.50, 0.14, 0.12, 1.0), metallic=0.30, roughness=0.40
        ),
        # Radiator cooling fins: warm copper / brass
        "MAT_Copper_Radiator": get_or_create_material(
            "MAT_Copper_Radiator", (0.72, 0.42, 0.26, 1.0), metallic=0.90, roughness=0.38
        ),
        # Rubber: road wheel solid tires
        "MAT_Rubber": get_or_create_material(
            "MAT_Rubber", (0.08, 0.08, 0.09, 1.0), metallic=0.02, roughness=0.92
        ),
        # Track steel: manganese track links with friction sheen on guide horns
        "MAT_Track_Steel": get_or_create_material(
            "MAT_Track_Steel", (0.19, 0.20, 0.22, 1.0), metallic=0.88, roughness=0.55
        ),
        # Brass ammo: polished 92mm brass cartridge cases
        "MAT_Brass_Ammo": get_or_create_material(
            "MAT_Brass_Ammo", (0.82, 0.66, 0.26, 1.0), metallic=0.96, roughness=0.18
        ),
        # Optics: coated optical glass with subtle reflection and transmission
        "MAT_Optics_Glass": get_or_create_material(
            "MAT_Optics_Glass", (0.08, 0.22, 0.24, 1.0), metallic=0.10, roughness=0.12, transmission=0.80
        ),
        # Crew uniform: late-war khaki-drab canvas uniform
        "MAT_Crew_Uniform": get_or_create_material(
            "MAT_Crew_Uniform", (0.30, 0.32, 0.24, 1.0), metallic=0.02, roughness=0.85
        ),
        # Wood: pioneer tool handles (ash / walnut)
        "MAT_Wood": get_or_create_material(
            "MAT_Wood", (0.34, 0.21, 0.12, 1.0), metallic=0.02, roughness=0.72
        ),
    }
    return materials
