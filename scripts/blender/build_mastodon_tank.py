"""
A-47 Mastodon Heavy Cruiser - Master Tank Builder
Constructs the complete technical simulation-ready tank asset in Blender,
sets up armor and component metadata, saves .blend, and exports .glb for Godot.
"""

import bpy
import bmesh
import os
import sys
import json
import math
from mathutils import Vector, Matrix, Euler

# Add script directory to sys.path so helper modules can be imported
script_dir = os.path.dirname(os.path.abspath(__file__))
if script_dir not in sys.path:
    sys.path.append(script_dir)

from tank_spec import SPEC
from tank_materials import create_all_materials
from tank_geometry import (
    ensure_collection,
    link_to_collection,
    create_box,
    create_cylinder,
    create_empty,
    create_human_figure,
    create_detailed_road_wheel,
    create_detailed_sprocket,
    create_detailed_track_segment,
    create_detailed_ammo_rack,
    create_detailed_v12_engine,
    create_detailed_transmission,
    create_detailed_turret_shell,
    create_cast_mantlet,
    create_detailed_cupola,
)

def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    
    # Remove orphan meshes, materials, collections
    for block in bpy.data.meshes:
        if block.users == 0:
            bpy.data.meshes.remove(block)
    for block in bpy.data.materials:
        if block.users == 0:
            bpy.data.materials.remove(block)
            
    bpy.context.scene.unit_settings.system = 'METRIC'
    bpy.context.scene.unit_settings.scale_length = 1.0

def build_mastodon():
    clear_scene()
    mats = create_all_materials()
    
    # Collections
    col_exterior = ensure_collection("EXTERIOR")
    col_armor = ensure_collection("ARMOR")
    col_interior = ensure_collection("INTERIOR")
    col_crew = ensure_collection("CREW")
    col_components = ensure_collection("COMPONENTS")
    col_ammo = ensure_collection("AMMUNITION")
    col_running_gear = ensure_collection("RUNNING_GEAR")
    col_markers = ensure_collection("MARKERS")
    
    # -------------------------------------------------------------
    # 1. HIERARCHY ROOTS
    # -------------------------------------------------------------
    tank_root = create_empty("TankRoot", (0, 0, 0), collection=col_exterior)
    hull = create_empty("Hull", (0, 0, 0), parent=tank_root, collection=col_exterior)
    
    # -------------------------------------------------------------
    # 2. HULL ARMOR PLATES (ARM_*)
    # -------------------------------------------------------------
    # Upper Glacis (90mm, 55 deg slope) - thick interlocking sloped plate
    arm_ug = create_box(
        "ARM_UpperGlacis", (2.14, 1.45, 0.09), (0.0, 2.55, 1.42),
        rotation=(-math.radians(55), 0, 0), bevel_radius=0.012,
        material=mats["MAT_Armor_Exterior"], parent=hull, collection=col_armor
    )
    arm_ug["armor_thickness_mm"] = 90
    arm_ug["armor_material"] = "RHA"
    arm_ug["armor_zone"] = "upper_glacis"
    arm_ug["spall_coefficient"] = 1.0
    
    # Lower Glacis (75mm, -45 deg slope)
    arm_lg = create_box(
        "ARM_LowerGlacis", (2.14, 1.05, 0.075), (0.0, 3.25, 0.78),
        rotation=(math.radians(45), 0, 0), bevel_radius=0.012,
        material=mats["MAT_Armor_Exterior"], parent=hull, collection=col_armor
    )
    arm_lg["armor_thickness_mm"] = 75
    arm_lg["armor_material"] = "RHA"
    arm_lg["armor_zone"] = "lower_glacis"
    arm_lg["spall_coefficient"] = 1.0

    # Upper Hull Sponsons / Sides (70mm, 15 deg slope)
    for side, side_str in [(-1, "Left"), (1, "Right")]:
        arm_su = create_box(
            f"ARM_Hull{side_str}Upper", (0.07, 4.80, 0.85), (side * 1.66, 0.10, 1.55),
            rotation=(0, side * math.radians(15), 0), bevel_radius=0.012,
            material=mats["MAT_Armor_Exterior"], parent=hull, collection=col_armor
        )
        arm_su["armor_thickness_mm"] = 70
        arm_su["armor_material"] = "RHA"
        arm_su["armor_zone"] = f"hull_{side_str.lower()}_upper"
        arm_su["spall_coefficient"] = 1.0
        
        # Lower Hull Tub Sides (60mm, vertical)
        arm_sl = create_box(
            f"ARM_Hull{side_str}Lower", (0.06, 5.80, 0.78), (side * 1.04, -0.15, 0.82),
            bevel_radius=0.010,
            material=mats["MAT_Armor_Exterior"], parent=hull, collection=col_armor
        )
        arm_sl["armor_thickness_mm"] = 60
        arm_sl["armor_material"] = "RHA"
        arm_sl["armor_zone"] = f"hull_{side_str.lower()}_lower"
        arm_sl["spall_coefficient"] = 1.0
        
        # Sponson floor plates
        create_box(
            f"VIS_SponsonFloor_{side_str}", (0.62, 4.80, 0.03), (side * 1.35, 0.10, 1.15),
            material=mats["MAT_Armor_Interior"], parent=hull, collection=col_armor
        )

    # Hull Rear (55mm, 20 deg slope)
    arm_rear = create_box(
        "ARM_HullRear", (2.14, 1.25, 0.055), (0.0, -3.42, 1.25),
        rotation=(-math.radians(20), 0, 0), bevel_radius=0.012,
        material=mats["MAT_Armor_Exterior"], parent=hull, collection=col_armor
    )
    arm_rear["armor_thickness_mm"] = 55
    arm_rear["armor_material"] = "RHA"
    arm_rear["armor_zone"] = "hull_rear"
    arm_rear["spall_coefficient"] = 1.0

    # Hull Roof (30mm, deck)
    arm_roof = create_box(
        "ARM_HullRoof", (3.38, 5.20, 0.03), (0.0, -0.30, 1.95),
        bevel_radius=0.010,
        material=mats["MAT_Armor_Exterior"], parent=hull, collection=col_armor
    )
    arm_roof["armor_thickness_mm"] = 30
    arm_roof["armor_material"] = "RHA"
    arm_roof["armor_zone"] = "hull_roof"
    arm_roof["spall_coefficient"] = 1.0

    # Hull Floor / Belly (25mm)
    arm_floor = create_box(
        "ARM_HullFloor", (2.14, 5.80, 0.025), (0.0, -0.15, 0.44),
        bevel_radius=0.008,
        material=mats["MAT_Armor_Exterior"], parent=hull, collection=col_armor
    )
    arm_floor["armor_thickness_mm"] = 25
    arm_floor["armor_material"] = "RHA"
    arm_floor["armor_zone"] = "hull_floor"
    arm_floor["spall_coefficient"] = 1.0

    # -------------------------------------------------------------
    # 3. FRONT HULL MECHANICAL & OPTICAL DETAIL
    # -------------------------------------------------------------
    # Driver Armored Visor Hood on Upper Glacis
    create_box(
        "VIS_DriverVisorHood", (0.34, 0.22, 0.18), (-0.55, 2.65, 1.58),
        rotation=(-math.radians(25), 0, 0), bevel_radius=0.012,
        material=mats["MAT_Steel_Cast"], parent=hull, collection=col_exterior
    )
    # Driver armored slit flap
    create_box(
        "VIS_DriverSlitFlap", (0.24, 0.04, 0.06), (-0.55, 2.76, 1.58),
        material=mats["MAT_Gunmetal"], parent=hull, collection=col_exterior
    )
    
    # Bow MG Cast Armored Ball Mount (Kugelblende)
    create_cylinder(
        "VIS_BowMGBallMount", 0.16, 0.14, (0.55, 2.82, 1.45),
        rotation=(math.pi / 2, 0, 0),
        material=mats["MAT_Steel_Cast"], parent=hull, collection=col_exterior
    )
    # Hull Machine Gun Barrel
    create_cylinder(
        "CMP_HullMG", 0.038, 0.48, (0.55, 2.96, 1.45), rotation=(math.pi / 2, 0, 0),
        material=mats["MAT_Gunmetal"], parent=hull, collection=col_exterior
    )
    create_empty("MKR_HullMG_Muzzle", (0.55, 3.20, 1.45), parent=hull, collection=col_markers)

    # Cast Final-Drive Armored Housings on Lower Glacis Sides
    for side in [-1, 1]:
        create_cylinder(
            f"VIS_FinalDriveCover_{'L' if side < 0 else 'R'}", 0.38, 0.28,
            (side * 1.25, 3.10, 0.65), rotation=(0, math.pi / 2, 0),
            material=mats["MAT_Steel_Cast"], parent=hull, collection=col_exterior
        )

    # Heavy Towing C-Shackles & Brackets (Front & Rear)
    for fx in [-0.85, 0.85]:
        # Front clevis brackets and shackles
        create_box(
            f"VIS_TowHookFront_{'L' if fx < 0 else 'R'}", (0.12, 0.26, 0.18), (fx, 3.65, 0.72),
            bevel_radius=0.015, material=mats["MAT_Steel_Cast"], parent=hull, collection=col_exterior
        )
        create_cylinder(
            f"VIS_TowShackleFront_{'L' if fx < 0 else 'R'}", 0.06, 0.16, (fx, 3.76, 0.68),
            rotation=(0, math.pi / 2, 0), material=mats["MAT_Steel_Cast"], parent=hull, collection=col_exterior
        )
        # Rear clevis brackets and shackles
        create_box(
            f"VIS_TowHookRear_{'L' if fx < 0 else 'R'}", (0.12, 0.26, 0.18), (fx, -3.58, 0.72),
            bevel_radius=0.015, material=mats["MAT_Steel_Cast"], parent=hull, collection=col_exterior
        )
        create_cylinder(
            f"VIS_TowShackleRear_{'L' if fx < 0 else 'R'}", 0.06, 0.16, (fx, -3.68, 0.68),
            rotation=(0, math.pi / 2, 0), material=mats["MAT_Steel_Cast"], parent=hull, collection=col_exterior
        )

    # Crane Lifting Lugs on Upper Hull
    for lx, ly in [(-1.58, 2.45), (1.58, 2.45), (-1.58, -2.85), (1.58, -2.85)]:
        create_cylinder(
            f"VIS_HullLiftLug_{'L' if lx < 0 else 'R'}_{'F' if ly > 0 else 'R'}", 0.05, 0.08,
            (lx, ly, 1.96), material=mats["MAT_Steel_Cast"], parent=hull, collection=col_exterior
        )

    # Armored Blackout Headlight on Left Fender
    create_cylinder(
        "VIS_Headlight_L", 0.11, 0.16, (-1.35, 3.35, 1.38),
        rotation=(math.pi / 2, 0, 0),
        material=mats["MAT_Gunmetal"], parent=hull, collection=col_exterior
    )
    # Headlight mounting bracket
    create_box(
        "VIS_HeadlightBracket_L", (0.04, 0.12, 0.18), (-1.35, 3.28, 1.28),
        material=mats["MAT_Steel_Cast"], parent=hull, collection=col_exterior
    )

    # -------------------------------------------------------------
    # 4. INTERNAL POWERTRAIN & MECHANICAL COMPONENTS (CMP_*)
    # -------------------------------------------------------------
    # Transmission (Front cast casing between Driver and Radio Operator)
    cmp_trans = create_detailed_transmission(
        "CMP_Transmission", (0.0, 2.75, 0.78), size=(0.96, 0.88, 0.66),
        parent=hull, collection=col_components, steel_mat=mats["MAT_Steel_Cast"]
    )
    
    # Final Drives (Left and Right)
    cmp_fd_l = create_cylinder(
        "CMP_LeftFinalDrive", 0.32, 0.38, (-1.22, 3.10, 0.65),
        rotation=(0, math.pi / 2, 0),
        material=mats["MAT_Steel_Cast"], parent=hull, collection=col_components
    )
    cmp_fd_r = create_cylinder(
        "CMP_RightFinalDrive", 0.32, 0.38, (1.22, 3.10, 0.65),
        rotation=(0, math.pi / 2, 0),
        material=mats["MAT_Steel_Cast"], parent=hull, collection=col_components
    )
    
    # Driveshaft (enclosed in protective steel tunnel through fighting compartment)
    cmp_driveshaft = create_cylinder(
        "CMP_Driveshaft", 0.065, 3.80, (0.0, 0.75, 0.52),
        rotation=(math.pi / 2, 0, 0),
        material=mats["MAT_Gunmetal"], parent=hull, collection=col_components
    )
    # Protective driveshaft tunnel cover
    create_box(
        "VIS_DriveshaftTunnel", (0.24, 3.80, 0.16), (0.0, 0.75, 0.52),
        material=mats["MAT_Steel_Cast"], parent=hull, collection=col_components
    )
    
    # Firewall (Between Fighting Compartment & Engine Bay)
    cmp_firewall = create_box(
        "CMP_Firewall", (2.08, 0.04, 1.48), (0.0, -1.25, 1.20),
        bevel_radius=0.01,
        material=mats["MAT_Steel_Cast"], parent=hull, collection=col_components
    )
    # Firewall inspection door
    create_box(
        "VIS_FirewallDoor", (0.65, 0.02, 0.85), (0.0, -1.22, 1.15),
        material=mats["MAT_Gunmetal"], parent=hull, collection=col_components
    )
    
    # V12 Heavy Diesel Engine
    cmp_engine = create_detailed_v12_engine(
        "CMP_Engine", (0.0, -2.25, 0.95), length=1.75, width=1.12, height=0.82,
        parent=hull, collection=col_components,
        block_mat=mats["MAT_Engine_Block"], red_mat=mats["MAT_Engine_Red"], steel_mat=mats["MAT_Gunmetal"]
    )
    
    # Dual Air Cleaner / Carburetor Units
    create_cylinder(
        "VIS_AirCleaner_L", 0.17, 0.32, (-0.24, -1.65, 1.65),
        material=mats["MAT_Gunmetal"], parent=hull, collection=col_components
    )
    create_cylinder(
        "VIS_AirCleaner_R", 0.17, 0.32, (0.24, -1.65, 1.65),
        material=mats["MAT_Gunmetal"], parent=hull, collection=col_components
    )
    
    # Radiators (Left and Right sponsons in engine bay)
    cmp_rad_l = create_box(
        "CMP_RadiatorLeft", (0.38, 1.40, 0.65), (-1.35, -2.25, 1.48),
        material=mats["MAT_Copper_Radiator"], parent=hull, collection=col_components
    )
    cmp_rad_r = create_box(
        "CMP_RadiatorRight", (0.38, 1.40, 0.65), (1.35, -2.25, 1.48),
        material=mats["MAT_Copper_Radiator"], parent=hull, collection=col_components
    )
    
    # Engine Cooling Fans (horizontal under deck grilles)
    cmp_fan_l = create_cylinder(
        "CMP_EngineFan_L", 0.36, 0.08, (-0.50, -2.75, 1.82),
        material=mats["MAT_Gunmetal"], parent=hull, collection=col_components
    )
    cmp_fan_r = create_cylinder(
        "CMP_EngineFan_R", 0.36, 0.08, (0.50, -2.75, 1.82),
        material=mats["MAT_Gunmetal"], parent=hull, collection=col_components
    )
    
    # Fuel Tanks (Lower sponsons forward of engine)
    cmp_fuel_l = create_box(
        "CMP_LeftFuelTank", (0.48, 1.55, 0.65), (-1.38, -0.35, 1.48),
        bevel_radius=0.02,
        material=mats["MAT_Steel_Cast"], parent=hull, collection=col_components
    )
    cmp_fuel_r = create_box(
        "CMP_RightFuelTank", (0.48, 1.55, 0.65), (1.38, -0.35, 1.48),
        bevel_radius=0.02,
        material=mats["MAT_Steel_Cast"], parent=hull, collection=col_components
    )
    # Fuel tank mounting straps
    for f_side in [-1, 1]:
        for f_y in [-0.85, 0.15]:
            create_box(
                f"VIS_FuelStrap_{'L' if f_side < 0 else 'R'}_{abs(f_y):.2f}",
                (0.50, 0.04, 0.67), (f_side * 1.38, f_y, 1.48),
                material=mats["MAT_Gunmetal"], parent=hull, collection=col_components
            )
            
    # Electrical Batteries
    cmp_battery = create_box(
        "CMP_BatteryBank", (0.55, 0.42, 0.38), (0.75, 0.70, 0.65),
        material=mats["MAT_Gunmetal"], parent=hull, collection=col_components
    )
    
    # Radio & Intercom (Front right / Radio Operator station)
    cmp_radio = create_box(
        "CMP_Radio", (0.45, 0.38, 0.52), (0.65, 2.75, 1.40),
        bevel_radius=0.015,
        material=mats["MAT_Gunmetal"], parent=hull, collection=col_components
    )
    cmp_intercom = create_box(
        "CMP_Intercom", (0.24, 0.18, 0.22), (0.35, 2.70, 1.62),
        material=mats["MAT_Gunmetal"], parent=hull, collection=col_components
    )

    # -------------------------------------------------------------
    # 5. HULL AMMUNITION STORAGE (AMMO_*)
    # -------------------------------------------------------------
    # Floor Rack (16 rounds)
    create_detailed_ammo_rack(
        "AMMO_FloorRack", (0.0, 0.25, 0.62), (0.90, 0.65, 0.32),
        rows=2, cols=8, parent=hull, collection=col_ammo,
        brass_mat=mats["MAT_Brass_Ammo"], steel_mat=mats["MAT_Gunmetal"]
    )
    # Hull Rack Left (24 rounds)
    create_detailed_ammo_rack(
        "AMMO_HullRack_Left", (-0.72, 0.25, 1.10), (0.42, 0.65, 0.64),
        rows=4, cols=6, parent=hull, collection=col_ammo,
        brass_mat=mats["MAT_Brass_Ammo"], steel_mat=mats["MAT_Gunmetal"]
    )
    # Hull Rack Right (18 rounds)
    create_detailed_ammo_rack(
        "AMMO_HullRack_Right", (0.72, -0.35, 1.10), (0.42, 0.65, 0.48),
        rows=3, cols=6, parent=hull, collection=col_ammo,
        brass_mat=mats["MAT_Brass_Ammo"], steel_mat=mats["MAT_Gunmetal"]
    )

    # -------------------------------------------------------------
    # 6. HULL CREW (CREW_Driver, CREW_RadioOperator)
    # -------------------------------------------------------------
    crew_driver = create_human_figure(
        "CREW_Driver", (-0.55, 2.15, 0.88), seated=True, facing_y_pos=True,
        uniform_mat=mats["MAT_Crew_Uniform"], parent=hull, collection=col_crew
    )
    crew_radio = create_human_figure(
        "CREW_RadioOperator", (0.55, 2.15, 0.88), seated=True, facing_y_pos=True,
        uniform_mat=mats["MAT_Crew_Uniform"], parent=hull, collection=col_crew
    )
    
    # Driver Controls (steering tillers, pedals, dashboard)
    for x_off in [-0.68, -0.42]:
        create_cylinder(
            f"VIS_SteeringTiller_{'L' if x_off < -0.5 else 'R'}", 0.02, 0.42,
            (x_off, 2.45, 0.95), rotation=(math.radians(20), 0, 0),
            material=mats["MAT_Gunmetal"], parent=hull, collection=col_interior
        )
    create_box(
        "VIS_DriverDashboard", (0.38, 0.12, 0.22), (-0.55, 2.52, 1.25),
        material=mats["MAT_Gunmetal"], parent=hull, collection=col_interior
    )

    # Driver Hatch & Pivot
    hatch_driver_pivot = create_empty("DriverHatchPivot", (-0.55, 2.50, 1.96), parent=hull, collection=col_exterior)
    hatch_driver = create_box(
        "HATCH_Driver", (0.54, 0.46, 0.045), (0.0, -0.23, 0.02),
        bevel_radius=0.01,
        material=mats["MAT_Armor_Exterior"], parent=hatch_driver_pivot, collection=col_exterior
    )
    # Driver Hatch Hinge bracket
    create_cylinder(
        "VIS_DriverHatchHinge", 0.035, 0.38, (-0.55, 2.50, 1.98),
        rotation=(0, math.pi / 2, 0),
        material=mats["MAT_Steel_Cast"], parent=hull, collection=col_exterior
    )
    
    # Driver Vision Optics
    create_box(
        "OPT_Driver_Periscope", (0.28, 0.14, 0.16), (-0.55, 2.65, 1.82),
        material=mats["MAT_Optics_Glass"], parent=hull, collection=col_exterior
    )
    
    # Driver & Front Markers
    create_empty("MKR_Driver_Seat", (-0.55, 2.15, 0.70), parent=hull, collection=col_markers)
    create_empty("MKR_Driver_Eyes", (-0.55, 2.15, 1.46), parent=hull, collection=col_markers)
    create_empty("MKR_Driver_Hatch_View", (-0.55, 2.25, 2.10), parent=hull, collection=col_markers)

    # -------------------------------------------------------------
    # 7. RUNNING GEAR & TRACKS (6 Paired Stations per Side)
    # -------------------------------------------------------------
    wheel_y_positions = [-2.30, -1.40, -0.50, 0.40, 1.30, 2.20]
    for side_idx, (side, side_str) in enumerate([(-1, "L"), (1, "R")]):
        # 6 Dual Road Wheel Stations
        for w_idx, y_pos in enumerate(wheel_y_positions):
            w_name = f"CMP_Wheel_{side_str}_{w_idx+1:02d}"
            w_loc = (side * 1.36, y_pos, 0.45)
            wheel = create_detailed_road_wheel(
                w_name, w_loc, radius=0.36, width=0.22,
                parent=hull, collection=col_running_gear,
                steel_mat=mats["MAT_Steel_Cast"], rubber_mat=mats["MAT_Rubber"]
            )
            # Torsion bar swing arm
            arm_angle = math.radians(25) if side < 0 else -math.radians(25)
            create_box(
                f"VIS_SuspArm_{side_str}_{w_idx+1:02d}", (0.09, 0.28, 0.09),
                (side * 1.18, y_pos - 0.12, 0.52), rotation=(arm_angle, 0, 0),
                bevel_radius=0.01,
                material=mats["MAT_Steel_Cast"], parent=hull, collection=col_running_gear
            )
            # Rubber suspension bump stop
            create_cylinder(
                f"VIS_BumpStop_{side_str}_{w_idx+1:02d}", 0.05, 0.08,
                (side * 1.12, y_pos + 0.05, 0.62), rotation=(0, math.pi / 2, 0),
                material=mats["MAT_Rubber"], parent=hull, collection=col_running_gear
            )
        
        # Drive Sprocket (Front)
        sprocket = create_detailed_sprocket(
            f"CMP_DriveSprocket_{side_str}", (side * 1.36, 3.10, 0.65), radius=0.38, width=0.24, teeth=14,
            parent=hull, collection=col_running_gear, steel_mat=mats["MAT_Steel_Cast"]
        )
        
        # Idler Wheel (Rear)
        idler = create_detailed_road_wheel(
            f"CMP_Idler_{side_str}", (side * 1.36, -3.05, 0.70), radius=0.34, width=0.22,
            parent=hull, collection=col_running_gear, steel_mat=mats["MAT_Steel_Cast"], rubber_mat=mats["MAT_Steel_Cast"]
        )
        # Idler eccentric tensioner arm
        create_box(
            f"VIS_IdlerTensionArm_{side_str}", (0.08, 0.22, 0.08),
            (side * 1.18, -2.92, 0.70), bevel_radius=0.01,
            material=mats["MAT_Steel_Cast"], parent=hull, collection=col_running_gear
        )
        
        # Return Rollers (4 per side)
        for r_idx, r_y in enumerate([-1.85, -0.60, 0.65, 1.90]):
            roller = create_detailed_road_wheel(
                f"CMP_Roller_{side_str}_{r_idx+1:02d}", (side * 1.36, r_y, 1.05), radius=0.14, width=0.18,
                parent=hull, collection=col_running_gear, steel_mat=mats["MAT_Steel_Cast"], rubber_mat=mats["MAT_Steel_Cast"]
            )
            # Roller mounting pedestal
            create_cylinder(
                f"VIS_RollerMount_{side_str}_{r_idx+1:02d}", 0.04, 0.16,
                (side * 1.20, r_y, 1.05), rotation=(0, math.pi / 2, 0),
                material=mats["MAT_Steel_Cast"], parent=hull, collection=col_running_gear
            )

        # Track Sections with Modeled Links, Grousers, and Catenary Sag
        # Bottom ground-contact run (straight)
        create_detailed_track_segment(
            f"CMP_Track_{side_str}_Bottom", (side * 1.36, -0.05, 0.09),
            length=5.20, width=0.58, height=0.045, num_links=28,
            parent=hull, collection=col_running_gear, track_mat=mats["MAT_Track_Steel"]
        )
        # Top return run (with subtle realistic catenary sag between support rollers)
        create_detailed_track_segment(
            f"CMP_Track_{side_str}_Top", (side * 1.36, -0.05, 1.19),
            length=5.20, width=0.58, height=0.045, num_links=28,
            parent=hull, collection=col_running_gear, track_mat=mats["MAT_Track_Steel"]
        )
        # Front slant up to sprocket
        create_detailed_track_segment(
            f"CMP_Track_{side_str}_Front", (side * 1.36, 2.80, 0.65),
            length=1.18, width=0.58, height=0.045, rotation=(-math.radians(35), 0, 0), num_links=6,
            parent=hull, collection=col_running_gear, track_mat=mats["MAT_Track_Steel"]
        )
        # Rear slant up to idler
        create_detailed_track_segment(
            f"CMP_Track_{side_str}_Rear", (side * 1.36, -2.85, 0.65),
            length=1.18, width=0.58, height=0.045, rotation=(math.radians(35), 0, 0), num_links=6,
            parent=hull, collection=col_running_gear, track_mat=mats["MAT_Track_Steel"]
        )
        
        # Track Guards / Fenders with stiffener ribs
        create_box(
            f"VIS_TrackFender_{side_str}", (0.64, 6.80, 0.025), (side * 1.36, 0.0, 1.26),
            bevel_radius=0.005,
            material=mats["MAT_Armor_Exterior"], parent=hull, collection=col_exterior
        )
        # Fender triangular support brackets (4 per side)
        for b_y in [-2.4, -0.8, 0.8, 2.4]:
            create_box(
                f"VIS_FenderBracket_{side_str}_{abs(b_y):.1f}", (0.28, 0.04, 0.14),
                (side * 1.20, b_y, 1.20),
                material=mats["MAT_Steel_Cast"], parent=hull, collection=col_exterior
            )
        # Front mudguard curved lip
        create_box(
            f"VIS_FrontMudguard_{side_str}", (0.64, 0.35, 0.025), (side * 1.36, 3.52, 1.15),
            rotation=(math.radians(35), 0, 0),
            material=mats["MAT_Armor_Exterior"], parent=hull, collection=col_exterior
        )

    # -------------------------------------------------------------
    # 8. TURRET HIERARCHY & REMODELED SHAPED TURRET
    # -------------------------------------------------------------
    # Turret Ring Center at X=0, Y=0.25, Z=1.95
    turret_pivot = create_empty("TurretPivot", (0.0, 0.25, 1.95), parent=tank_root, collection=col_exterior)
    
    # Heavy Forged Turret Ring
    cmp_turret_ring = create_cylinder(
        "CMP_TurretRing", 1.08, 0.12, (0.0, 0.0, 0.06),
        material=mats["MAT_Steel_Cast"], parent=turret_pivot, collection=col_components
    )
    
    # Remodeled Turret Body with Sloped Cheeks & Bustle
    turret_body = create_detailed_turret_shell(
        "Turret", length=3.35, width=2.45, height=0.92,
        parent=turret_pivot, collection=col_exterior, armor_mat=mats["MAT_Armor_Exterior"]
    )
    
    # Turret Armor Plates (ARM_*)
    # Turret Front Plate (110mm, 25 deg slope)
    arm_tf = create_box(
        "ARM_TurretFront", (2.28, 0.11, 0.86), (0.0, 1.55, 0.50),
        rotation=(-math.radians(25), 0, 0), bevel_radius=0.015,
        material=mats["MAT_Steel_Cast"], parent=turret_pivot, collection=col_armor
    )
    arm_tf["armor_thickness_mm"] = 110
    arm_tf["armor_material"] = "CastArmor"
    arm_tf["armor_zone"] = "turret_front"
    arm_tf["spall_coefficient"] = 1.0

    # Turret Sides (75mm, 20 deg slope)
    for side, side_str in [(-1, "Left"), (1, "Right")]:
        arm_ts = create_box(
            f"ARM_Turret{side_str}", (0.075, 3.10, 0.85), (side * 1.18, 0.05, 0.50),
            rotation=(0, side * math.radians(20), 0), bevel_radius=0.012,
            material=mats["MAT_Armor_Exterior"], parent=turret_pivot, collection=col_armor
        )
        arm_ts["armor_thickness_mm"] = 75
        arm_ts["armor_material"] = "RHA"
        arm_ts["armor_zone"] = f"turret_{side_str.lower()}"
        arm_ts["spall_coefficient"] = 1.0

    # Turret Rear Bustle (65mm, 10 deg slope)
    arm_tr = create_box(
        "ARM_TurretRear", (2.15, 0.065, 0.82), (0.0, -1.52, 0.50),
        rotation=(math.radians(10), 0, 0), bevel_radius=0.012,
        material=mats["MAT_Armor_Exterior"], parent=turret_pivot, collection=col_armor
    )
    arm_tr["armor_thickness_mm"] = 65
    arm_tr["armor_material"] = "RHA"
    arm_tr["armor_zone"] = "turret_rear"
    arm_tr["spall_coefficient"] = 1.0

    # Turret Roof (30mm)
    arm_troof = create_box(
        "ARM_TurretRoof", (2.36, 3.10, 0.03), (0.0, 0.05, 0.94),
        bevel_radius=0.010,
        material=mats["MAT_Armor_Exterior"], parent=turret_pivot, collection=col_armor
    )
    arm_troof["armor_thickness_mm"] = 30
    arm_troof["armor_material"] = "RHA"
    arm_troof["armor_zone"] = "turret_roof"
    arm_troof["spall_coefficient"] = 1.0

    # Commander Cupola (80mm cast armor ring with 8 vision blocks)
    arm_cupola = create_detailed_cupola(
        "ARM_CommanderCupola", (0.62, -0.45, 1.08), radius=0.44, height=0.28,
        parent=turret_pivot, collection=col_armor, steel_mat=mats["MAT_Steel_Cast"], glass_mat=mats["MAT_Optics_Glass"]
    )
    arm_cupola["armor_thickness_mm"] = 80
    arm_cupola["armor_material"] = "CastArmor"
    arm_cupola["armor_zone"] = "cupola"
    arm_cupola["spall_coefficient"] = 1.0

    # Cupola Optical Periscopes (6 vision blocks preserving exact test naming)
    for p_idx in range(6):
        angle = p_idx * (2 * math.pi / 6)
        px = 0.62 + math.cos(angle) * 0.38
        py = -0.45 + math.sin(angle) * 0.38
        create_box(
            f"OPT_Commander_Periscope_{p_idx+1:02d}", (0.12, 0.08, 0.10),
            (px, py, 1.08), rotation=(0, 0, angle),
            material=mats["MAT_Optics_Glass"], parent=turret_pivot, collection=col_exterior
        )

    # Commander Hatch & Pivot
    hatch_cmd_pivot = create_empty("CommanderHatchPivot", (0.62, -0.68, 1.22), parent=turret_pivot, collection=col_exterior)
    hatch_cmd = create_cylinder(
        "HATCH_Commander", 0.34, 0.045, (0.0, 0.23, 0.02),
        material=mats["MAT_Armor_Exterior"], parent=hatch_cmd_pivot, collection=col_exterior
    )
    # Commander Hatch Torsion Hinge
    create_cylinder(
        "VIS_CmdHatchHinge", 0.035, 0.28, (0.62, -0.68, 1.24),
        rotation=(0, math.pi / 2, 0), material=mats["MAT_Steel_Cast"], parent=turret_pivot, collection=col_exterior
    )

    # Loader Hatch & Pivot (Left side of turret roof)
    hatch_loader_pivot = create_empty("LoaderHatchPivot", (-0.62, -0.48, 0.96), parent=turret_pivot, collection=col_exterior)
    hatch_loader = create_box(
        "HATCH_Loader", (0.52, 0.44, 0.04), (0.0, 0.22, 0.02),
        bevel_radius=0.01,
        material=mats["MAT_Armor_Exterior"], parent=hatch_loader_pivot, collection=col_exterior
    )
    # Loader Hatch Hinge
    create_cylinder(
        "VIS_LoaderHatchHinge", 0.03, 0.32, (-0.62, -0.48, 0.98),
        rotation=(0, math.pi / 2, 0), material=mats["MAT_Steel_Cast"], parent=turret_pivot, collection=col_exterior
    )

    # Turret Roof Ventilator Mushroom Domes
    create_cylinder(
        "VIS_TurretVent_01", 0.18, 0.08, (0.0, -0.75, 1.02),
        material=mats["MAT_Steel_Cast"], parent=turret_pivot, collection=col_exterior
    )
    create_cylinder(
        "VIS_TurretVent_02", 0.16, 0.08, (-0.62, 0.45, 1.02),
        material=mats["MAT_Steel_Cast"], parent=turret_pivot, collection=col_exterior
    )

    # Turret Basket (Suspended floor and tubular frame)
    create_cylinder(
        "CMP_TurretBasketFloor", 0.98, 0.04, (0.0, 0.0, -0.92),
        material=mats["MAT_Steel_Cast"], parent=turret_pivot, collection=col_components
    )
    for angle in [0, math.pi / 2, math.pi, 3 * math.pi / 2]:
        create_cylinder(
            f"VIS_BasketStanchion_{int(math.degrees(angle))}", 0.03, 0.98,
            (math.cos(angle) * 0.95, math.sin(angle) * 0.95, -0.45),
            material=mats["MAT_Gunmetal"], parent=turret_pivot, collection=col_components
        )

    # Turret Traverse Drive Unit
    cmp_traverse = create_box(
        "CMP_TurretDrive", (0.32, 0.35, 0.42), (0.78, 0.72, 0.25),
        bevel_radius=0.015,
        material=mats["MAT_Gunmetal"], parent=turret_pivot, collection=col_components
    )

    # Ready Ammo Rack (Turret bustle, 12 rounds in honeycomb sleeves)
    create_detailed_ammo_rack(
        "AMMO_ReadyRack", (0.0, -1.15, 0.52), (1.65, 0.65, 0.42),
        rows=2, cols=6, parent=turret_pivot, collection=col_ammo,
        brass_mat=mats["MAT_Brass_Ammo"], steel_mat=mats["MAT_Gunmetal"]
    )

    # Turret Radio & Intercom
    create_box(
        "CMP_TurretRadio", (0.42, 0.32, 0.42), (0.72, -1.05, 0.65),
        bevel_radius=0.01,
        material=mats["MAT_Gunmetal"], parent=turret_pivot, collection=col_components
    )

    # -------------------------------------------------------------
    # 9. TURRET CREW (Gunner, Commander, Loader)
    # -------------------------------------------------------------
    crew_gunner = create_human_figure(
        "CREW_Gunner", (0.58, 0.45, -0.42), seated=True, facing_y_pos=True,
        uniform_mat=mats["MAT_Crew_Uniform"], parent=turret_pivot, collection=col_crew
    )
    crew_commander = create_human_figure(
        "CREW_Commander", (0.62, -0.45, -0.15), seated=True, facing_y_pos=True,
        uniform_mat=mats["MAT_Crew_Uniform"], parent=turret_pivot, collection=col_crew
    )
    crew_loader = create_human_figure(
        "CREW_Loader", (-0.62, -0.15, -0.32), seated=False, facing_y_pos=True,
        uniform_mat=mats["MAT_Crew_Uniform"], parent=turret_pivot, collection=col_crew
    )

    # Gunner Controls (Traverse & Elevation Handwheels)
    create_cylinder(
        "VIS_GunnerTraverseWheel", 0.12, 0.03, (0.52, 0.72, -0.10),
        rotation=(math.pi / 2, 0, 0), material=mats["MAT_Gunmetal"], parent=turret_pivot, collection=col_interior
    )
    create_cylinder(
        "VIS_GunnerElevWheel", 0.12, 0.03, (0.42, 0.72, -0.10),
        rotation=(0, math.pi / 2, 0), material=mats["MAT_Gunmetal"], parent=turret_pivot, collection=col_interior
    )

    # Commander Markers
    create_empty("MKR_Commander_Seat", (0.62, -0.45, -0.35), parent=turret_pivot, collection=col_markers)
    create_empty("MKR_Commander_Buttoned_Eyes", (0.62, -0.45, 0.88), parent=turret_pivot, collection=col_markers)
    create_empty("MKR_Commander_Hatch_View", (0.62, -0.45, 1.35), parent=turret_pivot, collection=col_markers)
    create_empty("MKR_Commander_Exposed_Torso", (0.62, -0.45, 1.05), parent=turret_pivot, collection=col_markers)

    # -------------------------------------------------------------
    # 10. MAIN ARMAMENT & ELEVATION ASSEMBLY
    # -------------------------------------------------------------
    # Gun Elevation Trunnion Pivot at X=0, Y=1.10, Z=0.42 relative to TurretPivot
    gun_elev_pivot = create_empty("GunElevationPivot", (0.0, 1.10, 0.42), parent=turret_pivot, collection=col_exterior)
    
    # Gun Assembly Root under Elevation Pivot
    gun_assembly = create_empty("GunAssembly", (0.0, 0.0, 0.0), parent=gun_elev_pivot, collection=col_exterior)
    
    # Cast Gun Mantlet (120mm armor with curved profile, trunnion caps, optics brows)
    arm_mantlet = create_cast_mantlet(
        "ARM_GunMantlet", parent=gun_assembly, collection=col_armor, steel_mat=mats["MAT_Steel_Cast"]
    )
    arm_mantlet["armor_thickness_mm"] = 120
    arm_mantlet["armor_material"] = "CastArmor"
    arm_mantlet["armor_zone"] = "gun_mantlet"
    arm_mantlet["spall_coefficient"] = 1.0

    # Breech Block & Ring (Inside Turret)
    cmp_breech = create_box(
        "CMP_MainGunBreech", (0.36, 0.72, 0.40), (0.0, -0.38, 0.0),
        bevel_radius=0.015,
        material=mats["MAT_Gunmetal"], parent=gun_assembly, collection=col_components
    )
    # Breech block vertical sliding wedge
    create_box(
        "VIS_BreechWedge", (0.28, 0.22, 0.36), (0.0, -0.36, 0.0),
        material=mats["MAT_Steel_Cast"], parent=gun_assembly, collection=col_components
    )
    # Breech actuating handle
    create_cylinder(
        "VIS_BreechHandle", 0.02, 0.32, (0.22, -0.25, 0.12),
        rotation=(0, 0, math.radians(35)),
        material=mats["MAT_Gunmetal"], parent=gun_assembly, collection=col_components
    )

    # Recoil Cylinders (Left, Right, and Top Recuperator)
    cmp_recoil_l = create_cylinder(
        "CMP_MainGunRecoilLeft", 0.07, 0.65, (-0.24, -0.32, 0.0),
        rotation=(math.pi / 2, 0, 0),
        material=mats["MAT_Steel_Cast"], parent=gun_assembly, collection=col_components
    )
    cmp_recoil_r = create_cylinder(
        "CMP_MainGunRecoilRight", 0.07, 0.65, (0.24, -0.32, 0.0),
        rotation=(math.pi / 2, 0, 0),
        material=mats["MAT_Steel_Cast"], parent=gun_assembly, collection=col_components
    )
    cmp_recup = create_cylinder(
        "CMP_GunRecuperator", 0.08, 0.62, (0.0, -0.32, 0.24),
        rotation=(math.pi / 2, 0, 0),
        material=mats["MAT_Steel_Cast"], parent=gun_assembly, collection=col_components
    )
    # Spent Casing Deflector Cage
    create_box(
        "VIS_SpentCasingCage", (0.38, 0.45, 0.35), (0.0, -0.85, -0.05),
        material=mats["MAT_Gunmetal"], parent=gun_assembly, collection=col_components
    )

    # 92mm L/58 Main Cannon Barrel
    # Base reinforcement sleeve (chamber area)
    create_cylinder(
        "VIS_BarrelReinforcement", 0.13, 1.20, (0.0, 1.15, 0.0),
        rotation=(math.pi / 2, 0, 0),
        material=mats["MAT_Gunmetal"], parent=gun_assembly, collection=col_exterior
    )
    # Barrel collar flange
    create_cylinder(
        "VIS_BarrelCollar", 0.145, 0.08, (0.0, 1.68, 0.0),
        rotation=(math.pi / 2, 0, 0),
        material=mats["MAT_Steel_Cast"], parent=gun_assembly, collection=col_exterior
    )
    # Main tube (tapered)
    create_cylinder(
        "VIS_BarrelMainTube", 0.088, 3.40, (0.0, 3.25, 0.0),
        rotation=(math.pi / 2, 0, 0),
        material=mats["MAT_Gunmetal"], parent=gun_assembly, collection=col_exterior
    )
    # Bore evacuator (fume extractor)
    create_cylinder(
        "VIS_BoreEvacuator", 0.115, 0.65, (0.0, 2.95, 0.0),
        rotation=(math.pi / 2, 0, 0),
        material=mats["MAT_Gunmetal"], parent=gun_assembly, collection=col_exterior
    )
    # Multi-baffle Muzzle Brake (T-shaped double baffle)
    create_cylinder(
        "VIS_MuzzleBrake", 0.14, 0.55, (0.0, 5.05, 0.0),
        rotation=(math.pi / 2, 0, 0),
        material=mats["MAT_Steel_Cast"], parent=gun_assembly, collection=col_exterior
    )
    # Side baffle ports on muzzle brake
    for side in [-1, 1]:
        create_box(
            f"VIS_MuzzlePort_{'L' if side < 0 else 'R'}", (0.08, 0.32, 0.16),
            (side * 0.13, 5.05, 0.0),
            material=mats["MAT_Gunmetal"], parent=gun_assembly, collection=col_exterior
        )

    # Coaxial Machine Gun (7.92mm)
    create_cylinder(
        "CMP_CoaxMG", 0.035, 0.85, (-0.28, 0.85, 0.06),
        rotation=(math.pi / 2, 0, 0),
        material=mats["MAT_Gunmetal"], parent=gun_assembly, collection=col_exterior
    )
    
    # Gunner Primary Telescopic Sight
    create_cylinder(
        "OPT_Gunner_Sight", 0.045, 0.65, (0.32, 0.75, 0.08),
        rotation=(math.pi / 2, 0, 0),
        material=mats["MAT_Optics_Glass"], parent=gun_assembly, collection=col_exterior
    )

    # Armament Markers
    create_empty("MKR_MainGun_Chamber", (0.0, -0.05, 0.0), parent=gun_assembly, collection=col_markers)
    create_empty("MKR_MainGun_Muzzle", (0.0, 5.35, 0.0), parent=gun_assembly, collection=col_markers)
    create_empty("MKR_Gunner_Sight", (0.32, 1.10, 0.08), parent=gun_assembly, collection=col_markers)
    create_empty("MKR_Coax_Muzzle", (-0.28, 1.30, 0.06), parent=gun_assembly, collection=col_markers)
    create_empty("MKR_Recoil_Start", (0.0, 0.0, 0.0), parent=gun_assembly, collection=col_markers)
    create_empty("MKR_Recoil_End", (0.0, -0.35, 0.0), parent=gun_assembly, collection=col_markers)

    # -------------------------------------------------------------
    # 11. EXTERNAL STOWAGE, TOOLS, EXHAUST, DETAILS
    # -------------------------------------------------------------
    # Armored Engine Deck Louvered Grilles
    for y_grille in [-1.75, -2.40]:
        create_box(
            f"VIS_DeckGrille_{abs(y_grille):.2f}", (1.45, 0.55, 0.06), (0.0, y_grille, 1.98),
            bevel_radius=0.008,
            material=mats["MAT_Gunmetal"], parent=hull, collection=col_exterior
        )
        # Slat louvers inside grille
        for s_idx in range(5):
            sy = y_grille - 0.20 + s_idx * 0.10
            create_box(
                f"VIS_DeckSlat_{abs(y_grille):.2f}_{s_idx}", (1.40, 0.04, 0.02),
                (0.0, sy, 2.00), rotation=(math.radians(35), 0, 0),
                material=mats["MAT_Steel_Cast"], parent=hull, collection=col_exterior
            )

    # Engine deck central maintenance hatch
    create_box(
        "VIS_EngineAccessHatch", (1.10, 1.15, 0.04), (0.0, -2.10, 1.97),
        bevel_radius=0.008,
        material=mats["MAT_Armor_Exterior"], parent=hull, collection=col_exterior
    )

    # Dual Rear Exhaust Shrouds & Mufflers
    for side, side_str in [(-1, "L"), (1, "R")]:
        # Armored muffler drum
        create_cylinder(
            f"VIS_ExhaustMuffler_{side_str}", 0.16, 0.85, (side * 0.75, -3.52, 1.25),
            material=mats["MAT_Steel_Cast"], parent=hull, collection=col_exterior
        )
        # Curved down-turned tailpipe
        create_cylinder(
            f"VIS_ExhaustPipe_{side_str}", 0.065, 0.45, (side * 0.75, -3.62, 0.85),
            rotation=(math.radians(35), 0, 0),
            material=mats["MAT_Gunmetal"], parent=hull, collection=col_exterior
        )
        # Muffler heat deflection shield
        create_box(
            f"VIS_MufflerHeatShield_{side_str}", (0.36, 0.02, 0.82), (side * 0.75, -3.42, 1.25),
            material=mats["MAT_Armor_Exterior"], parent=hull, collection=col_exterior
        )

    # Sponson Sheet-Metal Stowage Boxes
    create_box(
        "VIS_StowageBox_L", (0.42, 1.20, 0.35), (-1.45, 1.10, 1.45),
        bevel_radius=0.01,
        material=mats["MAT_Armor_Exterior"], parent=hull, collection=col_exterior
    )
    create_box(
        "VIS_StowageBox_R", (0.42, 1.20, 0.35), (1.45, 1.10, 1.45),
        bevel_radius=0.01,
        material=mats["MAT_Armor_Exterior"], parent=hull, collection=col_exterior
    )

    # Pioneer Tools (Field Shovel, Felling Axe, Pickaxe, 20-Ton Screw Jack)
    create_box(
        "VIS_PioneerShovel", (0.12, 1.10, 0.04), (-1.45, -0.65, 1.30),
        material=mats["MAT_Wood"], parent=hull, collection=col_exterior
    )
    create_box(
        "VIS_PioneerAxe", (0.18, 0.85, 0.04), (1.45, -0.65, 1.30),
        material=mats["MAT_Wood"], parent=hull, collection=col_exterior
    )
    create_box(
        "VIS_PioneerPick", (0.22, 0.90, 0.05), (1.45, -1.65, 1.30),
        material=mats["MAT_Wood"], parent=hull, collection=col_exterior
    )
    create_box(
        "VIS_ScrewJack", (0.24, 0.38, 0.22), (-1.45, -1.65, 1.40),
        bevel_radius=0.01,
        material=mats["MAT_Steel_Cast"], parent=hull, collection=col_exterior
    )

    # Spare Track Links (Mounted on lower glacis and turret sides)
    create_box(
        "VIS_SpareTracksGlacis", (1.40, 0.08, 0.28), (0.0, 3.25, 0.85),
        rotation=(math.radians(45), 0, 0),
        material=mats["MAT_Track_Steel"], parent=hull, collection=col_exterior
    )
    create_box(
        "VIS_SpareTracksTurret_L", (0.08, 0.65, 0.28), (-1.22, -0.65, 0.55),
        material=mats["MAT_Track_Steel"], parent=turret_pivot, collection=col_exterior
    )
    create_box(
        "VIS_SpareTracksTurret_R", (0.08, 0.65, 0.28), (1.22, -0.65, 0.55),
        material=mats["MAT_Track_Steel"], parent=turret_pivot, collection=col_exterior
    )

    # Braided Steel Tow Cables along sponson edges
    for side in [-1, 1]:
        create_cylinder(
            f"VIS_TowCable_{'L' if side < 0 else 'R'}", 0.025, 3.80, (side * 1.62, 0.0, 1.32),
            rotation=(math.pi / 2, 0, 0),
            material=mats["MAT_Gunmetal"], parent=hull, collection=col_exterior
        )

    # Turret Crane Lifting Eyes (4 corners)
    for lx, ly in [(-1.05, 1.10), (1.05, 1.10), (-0.95, -1.25), (0.95, -1.25)]:
        create_cylinder(
            f"VIS_TurretLiftEye_{'L' if lx < 0 else 'R'}_{'F' if ly > 0 else 'R'}",
            0.045, 0.08, (lx, ly, 0.98),
            material=mats["MAT_Steel_Cast"], parent=turret_pivot, collection=col_exterior
        )

    # Radio Whip Antennas
    create_cylinder(
        "VIS_Antenna_Turret", 0.012, 1.85, (0.85, -1.35, 1.85),
        material=mats["MAT_Gunmetal"], parent=turret_pivot, collection=col_exterior
    )
    create_cylinder(
        "VIS_Antenna_Hull", 0.012, 1.65, (1.55, -0.45, 2.10),
        material=mats["MAT_Gunmetal"], parent=hull, collection=col_exterior
    )

    print("A-47 Mastodon vehicle hierarchy constructed successfully!")
    return tank_root

def export_tank_assets(output_blend_path, output_glb_path, output_meta_path):
    # Save .blend file
    os.makedirs(os.path.dirname(output_blend_path), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=output_blend_path)
    print(f"Saved Blender file to: {output_blend_path}")
    
    # Export glTF / GLB
    os.makedirs(os.path.dirname(output_glb_path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=output_glb_path,
        export_format='GLB',
        export_extras=True,          # Export custom properties (armor thickness, materials)
        export_yup=True,             # Standard glTF Y-up convention
        export_apply=False,          # Preserve individual object pivots for animation!
        export_materials='EXPORT',
        export_cameras=False,
        export_lights=False
    )
    print(f"Exported GLB asset to: {output_glb_path}")
    
    # Write companion structured metadata JSON
    os.makedirs(os.path.dirname(output_meta_path), exist_ok=True)
    with open(output_meta_path, 'w', encoding='utf-8') as f:
        json.dump(SPEC, f, indent=2)
    print(f"Saved metadata JSON to: {output_meta_path}")

if __name__ == "__main__":
    tank_root = build_mastodon()
    
    # Resolve file paths inside project
    base_dir = os.path.dirname(os.path.dirname(script_dir))
    blend_path = os.path.join(base_dir, "assets", "models", "tank", "A47_Mastodon.blend")
    glb_path = os.path.join(base_dir, "assets", "models", "tank", "A47_Mastodon.glb")
    meta_path = os.path.join(base_dir, "assets", "models", "tank", "mastodon_metadata.json")
    
    export_tank_assets(blend_path, glb_path, meta_path)
    print("Tank generation, .blend save, and GLB export completed without errors!")
