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
        "MAT_Armor_Exterior": get_or_create_material(
            "MAT_Armor_Exterior", (0.28, 0.33, 0.26, 1.0), metallic=0.72, roughness=0.55
        ),
        "MAT_Armor_Interior": get_or_create_material(
            "MAT_Armor_Interior", (0.88, 0.87, 0.82, 1.0), metallic=0.08, roughness=0.60
        ),
        "MAT_Steel_Cast": get_or_create_material(
            "MAT_Steel_Cast", (0.22, 0.24, 0.25, 1.0), metallic=0.85, roughness=0.48
        ),
        "MAT_Gunmetal": get_or_create_material(
            "MAT_Gunmetal", (0.14, 0.15, 0.17, 1.0), metallic=0.92, roughness=0.32
        ),
        "MAT_Engine_Block": get_or_create_material(
            "MAT_Engine_Block", (0.17, 0.19, 0.20, 1.0), metallic=0.82, roughness=0.45
        ),
        "MAT_Engine_Red": get_or_create_material(
            "MAT_Engine_Red", (0.55, 0.16, 0.14, 1.0), metallic=0.35, roughness=0.42
        ),
        "MAT_Copper_Radiator": get_or_create_material(
            "MAT_Copper_Radiator", (0.72, 0.42, 0.26, 1.0), metallic=0.88, roughness=0.40
        ),
        "MAT_Rubber": get_or_create_material(
            "MAT_Rubber", (0.10, 0.10, 0.11, 1.0), metallic=0.05, roughness=0.88
        ),
        "MAT_Track_Steel": get_or_create_material(
            "MAT_Track_Steel", (0.20, 0.21, 0.23, 1.0), metallic=0.86, roughness=0.58
        ),
        "MAT_Brass_Ammo": get_or_create_material(
            "MAT_Brass_Ammo", (0.78, 0.63, 0.28, 1.0), metallic=0.94, roughness=0.22
        ),
        "MAT_Optics_Glass": get_or_create_material(
            "MAT_Optics_Glass", (0.10, 0.22, 0.25, 1.0), metallic=0.15, roughness=0.15, transmission=0.7
        ),
        "MAT_Crew_Uniform": get_or_create_material(
            "MAT_Crew_Uniform", (0.33, 0.35, 0.27, 1.0), metallic=0.05, roughness=0.82
        ),
        "MAT_Wood": get_or_create_material(
            "MAT_Wood", (0.36, 0.23, 0.13, 1.0), metallic=0.02, roughness=0.75
        ),
    }
    return materials
