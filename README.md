# NO DAWN

A Godot 4.7 turn-based armored-combat vertical slice. The previous action-game combat and hit-point code has been removed. Open `project.godot` and run the main scene.

## Play

You command one five-person tank against another in a dark industrial yard. Select orders, then press **EXECUTE**. Your tank executes five seconds of orders, then the enemy executes five seconds. Only the active tank moves, aims, reloads, or fires. Shots and impact replays finish before control passes; a knocked-out enemy cannot take a response turn. Playback defaults to half speed (twenty real seconds for a quiet round). Gunfire automatically slows the battlefield to 8% speed; armor impacts pause it for a 6.5-second cutaway, then hold a damage assessment until you press **Continue**. Pause/Resume, speed selection and replay/continue controls stay available during execution. **STOP / EDIT** pauses your action and unlocks the queue; resuming preserves the remaining budget. Assessment pauses movement, projectiles, detection, reloading, fires, crew transfers, and industrial machinery; the shot viewer remains interactive.

- **Queue actions:** add **MOVE**, **TURN HULL**, **AIM TURRET**, **AIM & FIRE**, **SCAN**, **RELOAD**, or **WAIT**. Actions execute from top to bottom during your five-second turn. Each row shows its estimated time, including hull/turret traversal and any reload delay. Amber rows extend into a later turn; unfinished actions remain queued.
- **Short actions:** the number beside each action is its time limit (0 = until complete). For example, set a move to 0.5 seconds, then add a fire action to stop and shoot in the same turn. Limits include time already spent on that action. **Next action limit** sets the limit for subsequently added actions.
- **Change your mind:** press **STOP / EDIT** or **PAUSE** during your turn. Remove any action with **×**, edit its limit, append another action, or **CLEAR ALL**, then **RESUME**. Cancellation never refunds spent time or removes an already-fired shell. Orders stay locked during enemy execution and impact reviews.
- **Move:** press **MOVE**, click clear ground, then **EXECUTE ORDERS**. Long moves without a limit continue across turns. Blocked straight routes are rejected; choose shorter waypoints around buildings. Movement holds the turret's separate world bearing.
- **Orient:** **AIM TURRET** turns the gun toward a clicked point without moving the hull or firing. **TURN HULL** pivots the chassis while keeping the gun's world bearing. The battlefield labels both directions.
- **Fire:** **AIM & FIRE** or **FIRE AT THIS ESTIMATE** appends a stationary shot action. It waits for the gun to aim and reload, then fires once. The red marker is a fixed world point; it does not secretly track an unseen tank.
- **Reload:** a live countdown shows actual remaining loader time. Reload progresses during your other actions and idle time. A **RELOAD** action waits until ready; an absent loader takes 3.8 times as long. Reload time freezes during enemy turns, pauses, and impact reviews.
- **Find the enemy:** press **SCAN FOR ENEMY**, then **EXECUTE ORDERS**. This appends an action that holds position, shuts the engine down, and observes the estimate with a two-second searchlight exposure. The light can reveal you. A later move order restarts the engine.
- **Read the battlefield:** blue identifies your tank and movement route. The labeled yellow dashed area is a possible enemy location, not the actual tank. Its width expresses uncertainty. A red exclamation mark means the crew currently sees the enemy. A “LAST SEEN” marker preserves a sighting after visual contact is lost.
- Ordinary acoustic samples are filtered and published to the display at turn boundaries, instead of making the area jump every half-second. Sightings and gun reports can update it immediately, with a smooth visual transition. Stale uncertainty continues to widen. **HELP** is open on first launch.
- Mouse wheel zooms. Escape or right-click cancels destination/target selection without deleting existing orders; **CLEAR ALL** removes queued actions.
- Manual bearing, range, hull pivot, reverse movement, engine and fire-fighting controls are under **Advanced orders**. Manual movement/firing orders apply when the action queue is empty; queued actions capture aim height and creep settings when added. Actions have finite movement and turret rates; the order summary warns when aiming or reloading will take longer than the turn. Reloads continue on that tank’s next action; shells finish before the turn changes.
- Sound bearings from separated observation positions can produce a cross-bearing fix. Both crews aim using their own estimates. Movement and stale reports can invalidate a solution.
- Before the first execution choose 25 or 40 rounds. Six rounds occupy the ready rack; 19 fit in floor storage; extra rounds fill the exposed overflow rack. Emptying the ready rack increases reload time.
- Open **CREW** to inspect individual states and assign a surviving member to an empty station. Transfers take ten execution seconds. A gunner without a loader loads slowly; losing the commander removes panoramic observation. The loader can stop reloading to extinguish an engine-compartment fire.
- Blue shot trails are yours; red trails are incoming. Direction arrows, muzzle flashes, shot numbers and shooter-to-target labels identify each side’s shots. Unseen enemy origins remain marked as estimates. The **TURN** report retains shots, misses, damage and movement after the action.
- Impacts queue instead of replacing one another. The cutaway stages the incoming shell, armor contact, internal travel/spall, and results. Components highlight only as the recorded rays reach them. The battlefield, reloads, fires and observations freeze during each impact review. **PAUSE** also pauses the replay; **REPLAY THIS SHOT** restarts its animation and **SHOW FULL REPORT** reveals the final assessment immediately; **CONTINUE** acknowledges it. The report names newly affected crew and systems, explains consequences, and lists movement, gun, reload, and spotting availability. Results remain available in **SHOT**; replay never reruns damage.
- Shot records persist for the engagement. Select a record, click the cutaway to replay it, or right-drag to orbit. Use **Restart engagement** in the orders panel.

## Simulation and replay contract

`ArmorModel.gd` owns oriented armor plate volumes, spatial crew stations and components, categorical states, ammunition occupancy, and damage resolution. The battlefield draws the same armor definitions used by the solver. There is no tank or crew hit-point pool.

Swept projectile travel checks industrial cover and actual plate volumes. Impact normals determine obliquity and line-of-sight armor thickness. The prototype's energy budget determines penetration, stopping, or ricochet. Penetrations emit seeded fragment rays. Primary projectiles and fragments intersect internal volumes in geometric order, lose energy, and stop or exit. An ammunition strike can end an engagement in one shot; empty racks do not absorb projectiles or detonate.

Each shot records the tank's local geometry at impact, plate intersections and normals, incoming and residual energy, projectile segments, fragment segments, exact component strikes, and resulting effects. `ShotViewer.gd` only reads this snapshot. It does not rerun ballistics, choose victims, or generate random replay fragments. Incoming paths are clipped to three metres before impact for framing; impact points and internal paths are unchanged. Detailed enemy damage is deliberately available in the forensic viewer.

## Current boundaries

This is a playable foundation, not a validated historical simulator. Both tanks currently share one fictional layout and a single solid-shot APCBC configuration. Armor resistance uses a simplified energy relation; there is no projectile shatter, explosive filler/fuse model, spaced-armor behavior, external air drag, or ammunition selection yet. Primary rays that exit a vehicle stop being simulated beyond its cutaway record. Crew transfers are timed station changes rather than animated bodies moving through compartments. Fire uses a compartment timer and firewall condition rather than thermal propagation. Wounded states and incapacitation are categorical; abandonment and recovery are not implemented. No illumination rounds or AT gun are included yet. Acoustic estimates and dispersion are simplified, and the tactical camera is intentionally abstract.

## Validation

Run with a Godot executable (on this machine: `/home/deck/.local/bin/godot-flatpak`):

```sh
godot --headless --path . --script res://tests/armor_test.gd
godot --headless --path . --script res://tests/engagement_test.gd
godot --headless --path . --script res://tests/usability_test.gd
godot --headless --path . --script res://tests/playback_test.gd
godot --headless --path . --script res://tests/actions_test.gd
```

The armor suite checks intersections, slope, deterministic spall records, penetration versus stopping, ricochet, driver loss, reassignment timing, fire, and ammunition storage. The engagement suite runs two complete execution phases and checks planning freezes, order locking, ammunition use, physical impacts, reload carryover, and replay equality. The usability suite exercises action selection, projected battlefield clicks, movement, turning, blocked routes, persistent destinations, stable acoustic display, and world-anchored firing points. A rendered capture is available by running the engagement suite without `--headless` and appending `-- --capture`.

Combat advances in fixed 1/60-second steps, independently of playback speed. The playback suite verifies slow motion, pause, chronological impact queuing, staged highlights, sequential firing and shooter attribution, and identical ballistic records at different viewing speeds. Run it with `-- --capture` in a rendered Godot session to capture shot flight, the large impact viewer, and the turn report.

The action suite verifies independent turret/hull rotation, estimated and limited action durations, move-then-fire sequencing, pause/edit/resume budgets, irreversible fired shells, reload carryover, and damage assessments that require acknowledgement. Its `-- --capture` option saves queue and damage UI captures under the ignored `.godot/` directory.
