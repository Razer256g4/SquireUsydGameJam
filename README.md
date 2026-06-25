# Squire — a *Princess Paladin* tribute

A **reversed dungeon crawler**: you are **not** the hero. The **Princess** auto-battles
the forces of evil all on her own. You are her measly **Squire** — you can't fight, you
*fetch*. Scavenge potions and weapons off the floor and get them to her before she falls,
all while dodging monsters and watching your own health and stamina.

If the **Princess dies** or **you die**, it's game over.

## Controls

| Action | Keys |
| --- | --- |
| Move | `WASD` or `Arrow keys` |
| Dash (burst + brief invulnerability) | `Space` |
| Hand carried item to the Princess | **bump into her** |
| Use carried item | `Ctrl` — drink a **potion** yourself (heal), or **yeet** a **weapon** at the Princess (ranged upgrade) |
| Restart | `R` |
| Pause / Settings | `Esc` |
| Toggle fullscreen | `F11` |

Press `Esc` for the **Settings** menu (Display: fullscreen & vsync · Audio: master/SFX/music
volume · Gameplay: screen shake & hit-stop · plus *Reset to defaults*), then **Resume** or **Restart**.

You can only carry **one item at a time**. Walk over loot to pick it up.

- **Potion** → handed to the Princess heals *her* (`Ctrl` drinks it to heal *you* instead).
- **Weapon** → handed (or yeeted with `Ctrl`) upgrades the Princess: more damage, range,
  attack speed, and at weapon Lv.3+ she starts **cleaving** all nearby monsters.

## Monsters

- **Grunt** — standard orc, chases the Princess.
- **Scout** — a quick spectral **werewolf**; fragile but fast, likes to harass *you*.
- **Brute** — a towering **werebear**; very slow, very tanky, hits like a truck. Best loot drops.
- Plus a **slime** "minion" swarm and human "protestor" peasants stirred up by your schemes.

Each cleared room raises the difficulty. Survive as long as you can for a high score.

## Assets

Uses two free packs you dropped into the project:

- **Tiny RPG Character Asset Pack** (`tiny rpg/`) — sprites for every character. From the
  *Full 20-character* pack (copied into `tiny rpg/full/`): **Swordsman** (Princess), **Priest**
  (Squire), **Werewolf** (scout), **Werebear** (brute), **Slime** (minion), and the **Wizard**'s
  magic-projectile art layered onto the Princess's spell casts. From the free pack: the **Orc**
  (grunt) and **Soldier** (human "protestor") sheets, plus the arrow for thrown weapons.
- **Tiny Swords** (`tiny  swords terrain/`) — buildings used as darkened backdrop scenery.
- **RPG UI pack by Franuka** (`assets/ui/franuka/`) — the HUD skin (item-slot ability bar,
  pixel fonts, panels, banners, icons). © Franuka — used under its licence; see
  <https://franuka.itch.io/rpg-ui-pack>. *(Required attribution — do not remove.)*

> **Note:** the Princess (Swordsman) and the Squire (Priest) now have distinct sprites; the
> Squire is still scaled down and tinted green, and the Princess wears a floating crown. The
> Swordsman ships three attack clips that the Princess rotates through for her telegraphed
> spells; the Priest's *heal* clip plays as a flourish when the Squire hands over a genuine
> gift. To swap any character, point its `Anim.*()` call in `scripts/anim.gd` at another sheet.

Animations are sliced from the 100×100 strip sheets at runtime in [scripts/anim.gd](scripts/anim.gd)
(`SpriteFrames` built and cached in code) — no `.tres` resources to manage by hand.

## How to run

1. Install **Godot 4.x** (this project was created with 4.7) — <https://godotengine.org/download>.
2. Clone this repo, then in Godot click **Import** and select the project folder (the one
   containing `project.godot`).
3. Press **F5** (Run) — `Main.tscn` is the main scene.

The two sprite packs in `tiny rpg/` and `tiny  swords terrain/` are **required**: the
Princess, Squire, orcs, thrown weapon and backdrop scenery all render from them. Only the
HUD, item pickups, the Princess's crown, and the health/stamina bars are drawn procedurally
in code. (Without those folders the game still runs, but those sprites are invisible.)

## Project layout

```
project.godot          # engine config (main scene, window, renderer)
Main.tscn              # root scene -> scripts/game.gd
scripts/
  game.gd              # arena, wave/room spawning, score, game state, scenery, HUD wiring
  actor.gd             # shared base: AnimatedSprite2D body + play/flip/overlay/timer helpers
  anim.gd              # builds + caches SpriteFrames from the Tiny RPG strip sheets
  princess.gd          # Actor: the autonomous hero (Swordsman sprite; targets/moves/attacks/upgrades)
  squire.gd            # Actor: YOU (Priest sprite) — movement, dash, stamina, carry, hand/drink/yeet
  monster.gd           # Actor: grunt / scout / brute orcs (Orc sprite) + death anim
  pickup.gd            # potion / weapon floor loot (procedural)
  weapon_throw.gd      # homing thrown-weapon projectile (arrow sprite, Ctrl yeet)
  hud.gd               # all on-screen UI (bars, room/score, announcements)
```

## Ideas to build on

- True room-to-room dungeon: the Princess walks through doors; you must keep up.
- Different weapon *types* (bow, staff) instead of just numeric upgrades.
- Sound + music, particle hit effects, screen shake.
- A shop / between-room upgrade screen for the Squire (carry 2 items, faster dash).
