# Animation — Operation: Lost Frontier (Godot)

Characters, enemies, bosses and effects actually animate in-game.
Free tools only: built-in Godot (`AnimatedSprite2D` + `SpriteFrames`,
`AnimationPlayer`, `Tween`). No paid tools, no API keys.

## What animates

| Thing | How | Source |
|---|---|---|
| Grunt, Engineer (enemy) | 14-frame walk cycle | Batch-04 Atlas 2, green soldier row |
| Scout (enemy) | 8-frame walk cycle | Batch-04 Atlas 2, red-ponytail female row |
| Sniper, EliteGuard | 14-frame walk cycle | Batch-04 Atlas 2, blue soldier row |
| Heavy, RocketSoldier, ShieldTrooper | 14-frame walk cycle | Batch-04 Atlas 2, bearded soldier row |
| Drone | Hover bob (velocity sine, already in `enemy.gd`) | Static batch-1 art |
| Turret | Stationary (no motion by design) | Static batch-1 art |
| Beast | Lunge scale pulse on attack | Static batch-1 art |
| Bosses (all 5) | Slow hover bob + attack pulse | Static batch-1 mech art |
| Player (all 4 characters) | Procedural Tween: run bob, squash-and-stretch on jump/land, recoil on fire | Existing batch-1 sprite |
| Explosions (rocket / grenade) | 4-frame one-shot animation | Batch-04 Atlas 2, explosion row |

When an enemy is not moving it holds the first frame (standing pose);
when it moves the cycle plays at 12 fps. Facing flips with the
movement direction.

## How the frames were sliced (verified, not guessed)

Batch-04 Atlas 2 (`Character_Animation_UI_Background_Atlas.png`,
1536×1024) has real walk-cycle rows. The frame grid was found
programmatically (column-ink analysis) and verified with a contact
sheet before any code used it:

- Walk rows are a regular **48 px grid starting at x=60**:
  green soldier y=13–125 (14 frames), red-ponytail female y=135–230
  (8 frames), blue soldier y=238–317 (14 frames), bearded soldier
  y=326–415 (14 frames). Each cell holds one clean character.
- Explosion row: **4 frames, 135 px wide from x=8, y=595–695**
  (fireball → star-burst → debris → flame swirl).
- The baked checkerboard is removed with the same bright-desaturated
  key used for the batch-10 hazards: pixels with max(R,G,B) > 205 and
  (max−min) < 22 → transparent. Characters are dark/saturated and
  survive; skin tones (~220,180,150, saturation ~70) survive too.
  Verified on the contact sheet: every frame is one intact character,
  no background, no clipped limbs.

Frames are cleaned and saved at build time by the generator
(`assets/anim/<name>/frame_XX.png`), so the project never depends on
the atlas layout at runtime. `CharacterAnimator.build_frames()`
loads them into a `SpriteFrames` ("walk", 12 fps, looped) and scales
them with the same uniform-height rule as `SpriteLoader`
(height = target, width follows the aspect ratio).

## Modules

- `scripts/core/character_animator.gd` (`CharacterAnimator`) — owns one
  `AnimatedSprite2D` (walk mode) or drives a static `Sprite2D`
  (bob/pulse mode). `setup_walk()`, `setup_static()`, `update(moving,
  delta)`, `set_facing()`, `pulse()`. It never touches AI, health or
  physics.
- `scripts/player/player_animator.gd` (`PlayerAnimator`) — procedural
  Tween animation for the player sprite: `update(moving, on_floor,
  delta)`, `on_jump()`, `on_land()`, `on_fire()`.
- `scripts/world/explosion.gd` (`Explosion`) — one-shot 4-frame
  explosion; `Explosion.spawn(parent, pos, size_px)`. Called from
  `Main.explode()`. Damage is still done by `Combat.explode`.

## Why the free addons were NOT installed

Vijay approved the free addons (Aseprite Wizard, Dot Aseprite
Importer, Gator Sprite Studio, AI Sprite Maker's free converter) where
they help. They do not fit these inputs:

- **Aseprite Wizard / Dot Aseprite Importer** import `.aseprite`
  files. No `.aseprite` file exists in any uploaded batch — the art is
  PNG atlases.
- **Gator Sprite Studio** imports sprite-studio data. No such data
  exists either.
- **AI Sprite Maker's converter** converts a PNG + JSON sheet
  description into `SpriteFrames`. No JSON sheet description exists;
  the frame grid was found by analysis instead (see above).

So the built-in slicing + runtime `SpriteFrames` covers the whole job
with zero dependencies and zero cost. If a future batch ships
`.aseprite` or JSON files, the matching addon can be added then —
nothing in the animator depends on how the frames were produced.

## What is NOT animated (honest)

- The four player characters use procedural Tween motion, not atlas
  frames: no batch-04 row matches their batch-1 appearance, and
  swapping their art mid-walk would change what the player looks like.
- Weapons have no separate reload / muzzle-flash sprite animation;
  the fire recoil and the bullet tracers carry the feedback.
- The batch-04 portraits, UI panels and biome backgrounds are static
  art (menu / results / backdrops), not animated.
