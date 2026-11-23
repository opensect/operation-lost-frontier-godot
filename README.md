# Operation: Lost Frontier - Godot 4.4.1

2D side-scrolling run-and-gun, 1-4 player LAN co-op, 20 missions in 4 acts.
Ported to Godot 4.4.1 (GDScript) from the design doc and the uploaded art.
No personal info anywhere. Package: com.lostfrontier.game, version 1.0.

## Run it
- Open this folder in Godot 4.4.1 (or run the binary in ~/workspace/tools/godot).
- Press Play. Main menu appears: pick a character (Ranger / Scout /
  Engineer / Medic), pick a mission, press START MISSION.
- Keyboard: A/D move, Space jump, J fire, K reload, L grenade, E interact /
  revive, Q switch weapon, F ability, Esc pause, N next mission, R retry.
- Touch (Android): left/right, JUMP, FIRE, E, ABILITY buttons appear after START.
- LAN: HOST LAN on one device, FIND HOST or JOIN by IP on the others,
  same Wi-Fi. Host is authoritative. ENet on port 7777, discovery on UDP 8888.

## What is in it
- 4 characters with abilities + passives, 9 weapons (exact design values),
  gadgets, power-ups, health/armor/downed/revive, 11 enemy types with a
  Patrol -> Detect -> Approach -> Attack -> Reposition/Search/Return AI,
  5 bosses with phases, all 20 missions playable with objectives,
  checkpoints, extraction and results, progression/unlocks/save,
  Easy/Normal/Hard/Extreme, touch controls, good 2D physics (coyote time,
  jump buffering, solid ground, one-way platforms, knockback).

## Structure (modular, SOLID - see SOLID.md)
- scripts/core/    GameData (data tables), SpriteLoader
- scripts/player/  Player, PlayerMovement, PlayerHealth
- scripts/weapons/ WeaponResource, WeaponController, Bullet, Grenade, Combat
- scripts/enemies/ Enemy (base), Boss (extends Enemy)
- scripts/missions/ MissionManager
- scripts/world/   LevelBuilder, Pickup, Station, Hazard
- scripts/lan/     LanManager, LanDiscovery, RemotePlayer, LanSync (host snapshot protocol)
- scripts/ui/      Hud, MainMenu, TouchControls
- scripts/save/    SaveManager
- scripts/audio/   AudioManager (silent placeholder - no audio was uploaded)
- scripts/main.gd  Thin coordinator - wires the modules together.

## Art sources (all uploaded batches, one consistent style)
See ART_STYLE.md. In short: batch 1+2 individual PNGs for characters,
enemies, bosses, weapons, props and UI; batch 6 atlas for one
background per mission (mission N = cell N) and the menu backdrop;
batch 3 logo on the menu; batch 4 "MISSION COMPLETE!" panel on
results; generated Ranger/Aether icon as the app icon (`icon.png`).
Batches 3-5 sheets are kept in `assets/sheets/` as reference - only
rectangular crops are used from them, since their backgrounds are
baked in with no clean alpha.

## Honest limits
- LAN was not tested live on two phones in this sandbox.
- No audio (no audio files were uploaded).
- Survival / Horde / Versus / Time Attack / Boss Rush are not separate modes.
- No host migration; join only in the lobby.
- Ice missions now have damaging ice-spike hazards (batch 10);
  wind / conveyor effects are still visual-only.
- Scout's reveal-hidden-pickups passive has no hidden-pickup system behind it.
