# Art style - one consistent look (batches 1-6)

Chosen style: **detailed painted pixel-art** - humanoids ~150-250 px tall,
dark navy + jungle green + gold/red/blue UI. Every batch the user
uploaded is the same style family, so nothing clashes. Where a batch
offered the same art twice, only ONE copy is used in game.

## What is used where
- **Characters (4):** batch 1 named PNGs - ranger, scout, engineer,
  medic (`assets/characters/`). Same scale, same style.
- **Enemies (11):** batch 1 solid sprites where good (black_veil_grunt,
  red_heavy_trooper, mutant_brute, shield_trooper art) + batch 2
  cutouts where batch 1 was broken (see below). One distinct sprite
  per enemy - no duplicates.
- **Bosses (5):** one distinct mech/beast each - Jungle Walker
  (armored_mech_boss), Dune Destroyer (cutout 036, orange mech),
  Frost Warden (cutout 027, white mech), Abyssal Core (cutout 021),
  Commander Voss (cutout 028). All ~1.5-2x humanoid scale.
- **Weapons / gadgets / power-ups / props / environment tiles:**
  batch 1 named PNGs (`assets/weapons/`, `assets/powerups/`,
  `assets/props/`, `assets/environment/`).
- **Backgrounds (all 20 missions + menu):** batch 6 atlas, one cell
  per mission (mission N = cell N). Menu backdrop = cell 1 (Jungle).
  This is the single background source, so every mission and the menu
  share one look.
- **Logo:** batch 3 sheet 2 "OPERATION LOST FRONTIER" logo, main menu.
- **Results panel:** batch 4 atlas 2 "MISSION COMPLETE!" panel.
- **App icon:** generated Ranger + Aether crystal art (approved by
  Vijay), `icon.png` (512 px), also shown on the main menu.
- **UI theme:** one palette everywhere (navy panels, gold borders and
  titles, red health / blue armour / orange ammo) - see
  `scripts/ui/ui_theme.gd`. It matches the uploaded blue/gold UI art.

## What was NOT used, and why
- **Fragments (batch 1):** blue_tech_guard, combat_drone,
  crawler_drone, mutant_runner - only ~100-240 strongly-opaque pixels
  each, near-invisible in game. Replaced by batch-2 cutouts above.
- **Duplicates:** RocketSoldier re-used Heavy's sprite; all 5 bosses
  re-used one mech sprite. Both fixed with distinct cutouts.
- **Master sheets (batches 03/04/05) as character sprites:** their
  backgrounds are baked checkerboard / dark gradients with no clean
  alpha (verified: batch 04 atlas 1 has no fully-opaque pixel, batch
  03/05 are RGB). Cropping a single character out would show the
  background in game. Only rectangular crops are used (logo, panels,
  background cells). The full sheets are kept in `assets/sheets/`
  as reference.
- **Batch 05 environment banners:** evaluated - good art, but they
  duplicate batch 06's purpose-built 20 mission backgrounds. Batch 06
  is the single background source; batch 05 is kept as reference.
  Its blue button / bar art informed the UI theme instead.
- **Batch 04 animation frames:** real walk-cycle frames exist, but
  frame boundaries are unverified - slicing them wrong would show
  half-characters. Not used; players/enemies use single-frame art
  with bob/scale motion. (Future work: verify frame grid, then swap
  in as animated sprites.)
- **Batch 12 interactive objects:** the blue energy portal IS the
  extraction beacon (it fills its cell, glow dominates, dark backing
  reads as a frame) and the blue console terminal IS the generic
  objective station (stations whose data sprite is metal_supply_box).
  Doors, elevators, traps, platforms and decor from batch 12 are NOT
  used: no door/elevator/moving-platform mechanic exists, and batch-1
  hazard/prop PNGs already cover traps and crates with clean alpha.
  The full atlas is kept in `assets/sheets/` as reference.
- **Batch 10 environmental hazards:** six crops are cleaned in the
  generator (bright-desaturated key removes the baked checkerboard;
  the hazard art is dark/saturated so it survives) and saved as
  transparent PNGs in `assets/hazards/`: spikes, lava (cracked
  lava earth), toxic pool, saw, laser beams, ice spikes. Hazard zones
  use them with damage on touch + a pulsing red warning (see
  `scripts/world/hazard.gd`). Placed where the mission data supports
  them: spike/laser/toxic zones from layout hazard props, ice spikes
  in ice-flag missions (11, 12, 15), saw in the crusher factory
  (mission 8), laser in the unstable reactor (mission 18). Lava and
  fire art is cleaned and available but NOT forced into any mission
  (no mission data mentions lava). Water, wind, weather and explosion
  art is effects-only and not used as ground hazards.
- **Batch 04 portraits / HUD card / score panels:** contain baked
  fake numbers ("Lv. 10", "99999", "P1 1500") or checkerboard
  corners - not used as live UI images.

## Scale rules
- Humanoid sprites are drawn at the same world height (~110 px tall
  on screen) via SpriteLoader's size-based scaling; bosses ~1.8x.
- Ground/platform tiles come only from batch 1 environment art.
