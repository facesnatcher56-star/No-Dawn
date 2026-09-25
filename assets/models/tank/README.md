# A-47 Mastodon Heavy Cruiser Tank Asset

**Vehicle Designation:** A-47 Mastodon  
**Type:** Fictional Alternate-History Heavy Cruiser Tank (~1944–1947 era)  
**Combat Weight:** 52.0 Metric Tonnes  
**Crew:** 5 (Commander, Gunner, Loader, Driver, Radio Operator)  
**Primary Armament:** 92mm L/58 High-Velocity Cannon (70 rounds onboard)  
**Secondary Armament:** 7.92mm Coaxial MG, 7.92mm Bow MG, Anti-Aircraft Cupola Pintle  

---

## 1. Project Files & Directory Structure

```text
assets/models/tank/
├── A47_Mastodon.blend         # Full procedural/authored Blender 5 source asset
├── A47_Mastodon.glb           # glTF 2.0 binary asset with preserved pivots & hierarchy
├── mastodon_metadata.json     # Machine-readable specifications (armor, HP, ammo, crew)
├── mastodon_exterior.png      # Godot viewport capture (Normal exterior mode)
├── mastodon_xray.png          # Godot viewport capture (X-Ray translucent armor mode)
├── mastodon_cutaway.png       # Godot viewport capture (Cutaway mode with hatches open)
├── mastodon_front.png         # Front 3/4 beauty angle of vehicle & 92mm cannon
└── README.md                  # This technical manual

scenes/tank/
├── A47_Mastodon_Player.tscn   # Simulation-ready player tank scene (A47_Mastodon_Vehicle.gd)
└── TankInspection.tscn        # Interactive 3D technical inspection & test harness

scripts/tank/
├── A47_Mastodon_Vehicle.gd         # Primary vehicle root controller
├── MastodonAnimationController.gd  # Kinematics: turret traverse, gun pitch, recoil, hatches, wheels
├── MastodonVisualController.gd     # Visual modes: X-Ray, cutaway, crew focus, armor color analysis
├── MastodonMetadata.gd             # Metadata manager & technical query engine
└── TankInspection.gd               # Orbit camera, interactive UI sliders, and inspector cards

tests/
└── mastodon_tank_test.gd     # Automated verification test suite (54 checks, 0 failures)
```

---

## 2. Technical Vehicle Dimensions

| Dimension | Real-World Value | Godot Coordinate Equivalent |
|---|---|---|
| **Hull Length** | 7.00 m | 7.00 m along Z axis |
| **Total Length (with Gun)** | 9.05 m (9.34m incl. muzzle brake) | 9.34 m |
| **Hull Width** | 3.40 m (3.61m incl. track skirts) | 3.61 m along X axis |
| **Hull Height** | 1.95 m | 1.95 m |
| **Total Height (Cupola)** | 2.85 m (3.87m with 2.5m whip antennas) | 3.87 m along Y axis |
| **Ground Clearance** | 0.45 m | 0.45 m |
| **Turret Ring Diameter** | 2.15 m | 2.15 m |

---

## 3. Physical Internal Compartments & Architecture

The vehicle is partitioned into three distinct functional compartments:

1. **Front Driving Compartment:**
   - **Driver Station (Left):** Seated driver figure (`CREW_Driver`), twin driving levers, clutch/brake pedals, instrument dash, driver periscope, and articulated overhead escape hatch (`HATCH_Driver`).
   - **Radio Operator Station (Right):** Seated radio operator figure (`CREW_RadioOperator`), high-frequency radio transceiver (`CMP_Radio`), power supply (`CMP_BatteryBank`), and ball-mounted 7.92mm bow machine gun (`MKR_HullMG_Muzzle`).
   - **Powertrain Forward Section:** Heavy 5-speed synchromesh front transmission (`CMP_Transmission`) connected to left and right final drives (`CMP_LeftFinalDrive`, `CMP_RightFinalDrive`) and drive sprockets.

2. **Central Fighting Compartment & Turret:**
   - **Turret Basket:** 2.15m ball-race turret ring (`CMP_TurretRing`), hydraulic turret drive motor (`CMP_TurretDrive`), suspended anti-slip basket floor (`CMP_TurretBasketFloor`), and protective perimeter tubular stanchions.
   - **Gun Crew:**
     - **Commander (Right Rear):** Seated in cupola basket (`CREW_Commander`), rotating cupola with 8 vision blocks, articulated hatch (`HATCH_Commander`), and dual-position kinematics (seated buttoned vs. standing exposed in open hatch).
     - **Gunner (Right Front):** Seated in front of commander (`CREW_Gunner`), direct-fire telescopic optic (`CMP_GunnerOptics`), traverse handwheels, and trigger linkage.
     - **Loader (Left):** Standing loader figure (`CREW_Loader`), articulated loading hatch (`HATCH_Loader`), and unhindered access to ready and hull racks.
   - **Armament & Recoil System:**
     - 92mm high-velocity gun breech block (`CMP_MainGunBreech`).
     - Dual hydraulic recoil dampers (`CMP_MainGunRecoilLeft`, `CMP_MainGunRecoilRight`) and top pneumatic recuperator cylinder (`CMP_GunRecuperator`).
     - True physical recoil stroke of **350mm** with spent casing deflector cage (`VIS_SpentCasingCage`).
     - Gun trunnion pivot with **-8° depression to +20° elevation** limits.
   - **Ammunition Storage (70 rounds total):**
     - Turret Bustle Ready Rack (`AMMO_ReadyRack`): 12 ready rounds with protective blast doors.
     - Left Sponson Rack (`AMMO_HullRack_Left`): 24 rounds in double tiers.
     - Right Sponson Rack (`AMMO_HullRack_Right`): 18 rounds.
     - Hull Floor Bin (`AMMO_FloorRack`): 16 reserve rounds.

3. **Rear Engine Compartment:**
   - Separated from the fighting compartment by an armored steel firewall (`CMP_Firewall`).
   - **V12 Liquid-Cooled Diesel Engine (`CMP_Engine`):** 650 HP output with dual cylinder banks, cast valve covers, intake/exhaust manifolds, and longitudinal driveshaft (`CMP_Driveshaft`) running along hull floor to front transmission.
   - **Cooling System:** Dual heavy radiators (`CMP_RadiatorLeft`, `CMP_RadiatorRight`) and twin cooling fans (`CMP_EngineFan_L`, `CMP_EngineFan_R`) beneath armored roof louvers.
   - **Fuel Supply:** Sponson-protected fuel cells (`CMP_LeftFuelTank`, `CMP_RightFuelTank`) with 840L combined diesel capacity.

---

## 4. Running Gear & Suspension

- **Suspension:** Independent torsion bar suspension with 6 dual-dish road wheel pairs per side (12 road wheels total, `CMP_Wheel_L1` to `L6`, `CMP_Wheel_R1` to `R6`).
- **Drive:** Front-mounted drive sprockets (`CMP_DriveSprocket_L`, `CMP_DriveSprocket_R`) driven by the final drives.
- **Idlers & Rollers:** Rear idlers with track tensioning adjustment (`CMP_Idler_L`, `CMP_Idler_R`) and 4 top return rollers per side (`CMP_ReturnRoller_L1` to `L4`, `R1` to `R4`).
- **Tracks:** Heavy double-pin steel tracks (`VIS_Track_L`, `VIS_Track_R`) with mud guards and rear debris deflectors.

---

## 5. Hierarchy and Naming Conventions

All objects strictly follow prefix conventions for runtime simulation queries and rendering passes:

| Prefix | Category | Example Nodes |
|---|---|---|
| `ARM_` | Logical Armor Plates | `ARM_UpperGlacis`, `ARM_LowerGlacis`, `ARM_TurretFront`, `ARM_GunMantlet` |
| `CMP_` | Damagable Components | `CMP_Engine`, `CMP_Transmission`, `CMP_MainGunBreech`, `CMP_Radio` |
| `CREW_`| Crew Figures | `CREW_Driver`, `CREW_Commander`, `CREW_Gunner`, `CREW_Loader` |
| `AMMO_`| Ammunition Racks | `AMMO_ReadyRack`, `AMMO_HullRack_Left`, `AMMO_FloorRack` |
| `HATCH_`| Articulated Hatches | `HATCH_Commander`, `HATCH_Loader`, `HATCH_Driver` |
| `MKR_` | Gameplay Simulation Markers | `MKR_MainGun_Muzzle`, `MKR_Commander_Buttoned_Eyes`, `MKR_HullMG_Muzzle` |
| `VIS_` | Visual Props & Secondary Shells | `VIS_BarrelMainTube`, `VIS_MuzzleBrake`, `VIS_Track_L` |

---

## 6. How to Run the Inspection Suite & Automated Tests

### Launching Technical Inspection Suite
Run the interactive 3D inspection harness directly from Godot:
```powershell
& "path/to/Godot_v4.8-console.exe" scenes/tank/TankInspection.tscn
```

### Controls in Inspection Mode
- **Mouse Right-Drag:** Orbit camera around vehicle
- **Mouse Wheel:** Zoom in / out (4m to 20m)
- **Keys 1–5:** Toggle display modes
  - `1`: Normal exterior mode
  - `2`: X-Ray view (translucent blue glass armor, opaque internals)
  - `3`: Cutaway view (exterior armor hidden)
  - `4`: Crew focus mode
  - `5`: Mechanical components & ammunition focus
- **Turret / Gun Sliders:** Traverse turret ±180° and elevate cannon -8° to +20°
- **Spacebar:** Fire 92mm cannon (triggers 350mm physical recoil stroke and recuperation)
- **Key C:** Articulate commander hatch open/closed
- **Key E:** Articulate commander between buttoned seated posture and standing exposed observing posture
- **Key L:** Articulate loader hatch open/closed
- **Key D:** Articulate driver hatch open/closed
- **Key W:** Toggle road wheel and drive sprocket spin

### Running Headless Automated Test Suite
```powershell
& "path/to/Godot_v4.8-console.exe" --headless -s tests/mastodon_tank_test.gd
```
Result: **54 passing checks, 0 failures**.
