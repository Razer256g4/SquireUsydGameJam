# Squire — Audio Commission Brief (for the music composer / sound designer)

> Hand this whole document to the composer. It is an analytical inventory of the game's current
> audio, a critique of where it falls short, and an itemized commission list with creative
> direction and technical specs. The audio **engine** is finished (see
> [scripts/sfx.gd](../../scripts/sfx.gd)); only the **content** is placeholder.

## The game in one paragraph

`Squire` is a darkly comic *Princess Paladin* tribute where you play the **traitor sidekick**. You
fetch potions/weapons for an auto-battling Princess Paladin across waves — but you can also
**sabotage** her (cursed gifts), **tip off** monsters, and **scheme**. A **suspicion meter** rises
until she snaps — **"SHE KNOWS."** — and Phase 2 becomes a boss fight where she hunts *you* and
monsters defect to your side. Win = the hero dies ("LONG LIVE THE SQUIRE"). Lose = you die
("EXECUTED FOR TREASON").

**Scope of this commission:** original audio for **everything** — a full **adaptive,
suspicion-reactive score** plus **bespoke replacements for all 37 SFX keys** (combat, events, UI,
ambient).

---

## Tonal North Star (read this first)

Subversive fairy-tale told from the **villain's** seat. Pixel-art Godot tribute → a **heroic
chiptune × orchestral hybrid** fits (chip leads/arps over orchestral pads & percussion), but the
palette is the composer's call. The through-line across the whole score:

> **A bright, dutiful hero's theme that slowly curdles into menace as you betray her, snaps into
> operatic dread at the turn, and resolves into a hollow, morally-ambiguous coronation.**

Phase tones: **Serving** = deceptively bright/dutiful with a mischievous undercurrent (you are
scheming under the fanfare). **Betrayal** = the mask drops, tragic-but-furious. **Boss** = frantic
underdog-villain being hunted, driving and desperate. **Win** = dark, hollow triumph. **Lose** =
tragicomic failure.

---

## Part A — Current audio inventory (what's used today)

**Music (2 tracks, both placeholder CC0):**

| Logical name | Where it plays | Trigger |
| --- | --- | --- |
| `serving` | Whole wave/serving phase (loops) | game start |
| `boss` | After betrayal, the hunt (loops) | the betrayal |

Music runs on a dedicated **Music** bus, default **−7 dB**, sitting *under* SFX as a bed. Volume is
player-controllable (pause-menu slider). No reactivity, no other tracks.

**SFX — all 37 keys (every one a Kenney placeholder).** This *is* the replacement work-list:

| Key | Fires on | Current placeholder |
| --- | --- | --- |
| `swing` | Princess melee cleave (very frequent) | rpg knifeSlice ×3 |
| `enemy_swing` | Orc attack | rpg chop/knifeSlice |
| `enemy_hurt` | Monster takes a hit | impact Punch_medium ×5 |
| `enemy_die` | Monster dies | impact Soft_heavy ×5 |
| `player_hurt` | **Squire** hit (non-lethal) | impact Punch_heavy ×5 |
| `player_die` | **Squire OR Princess** death (shared!) | impact Glass_heavy ×5 |
| `boom` | AoE blast (meteor/nova/shower/nuke) | scifi explosionCrunch ×5 |
| `zap` | Beam / charge / smite | scifi laserLarge ×5 |
| `cast` | Spell wind-up whoosh (very frequent, −16 dB) | rpg cloth ×4 |
| `dash` | Squire dash | rpg cloth ×2 |
| `pickup` | Grab floor loot | rpg handleCoins ×2 |
| `princess_drink` | Hand a potion | rpg metalPot ×3 |
| `princess_arm` | Hand a weapon | rpg drawKnife ×3 |
| `gift_curse` | Hand a **cursed** item (your sabotage tell) | rpg creak ×3 |
| `tipoff` | Tip off monsters (E) | rpg metalClick/Latch |
| `enrage` | Monsters enrage *en masse* (one swell) | impact Soft_medium ×5 |
| `defect` | Monsters defect to you *en masse* | rpg metalLatch/belt |
| `explosion_big` | Plane crash | scifi lowFrequency_explosion ×2 |
| `crowd` | Peasant revolt | impact footstep_concrete ×5 |
| `infighting` | Monsters brawl each other | impact Generic_light ×5 |
| `swarm` | The "**67**" tiny-minion gag | impact Tin_medium ×5 |
| `trap_spawn` | Trap telegraphs | impact Wood_heavy ×5 |
| `trap_hit` | Trap strikes a target | impact Metal_light ×5 |
| `angel` | Divine-retribution laser | scifi laserLarge ×5 |
| `wave_start` | Wave begins | ui switch20 |
| `wave_clear` | Wave cleared ("grows stronger!") | ui switch21 |
| `levelup` | Princess levels up | ui switch15 |
| `betray_sting` | **THE turn** — deep WHOOM | scifi lowFrequency_explosion ×2 |
| `betray_roar` | Princess's roar as she turns | impact Metal_heavy ×5 |
| `win` | Victory end-card | ui switch31 |
| `lose` | Defeat end-card | impact Glass_heavy |
| `ui_click` | Button press | ui click ×5 |
| `ui_hover` | Button hover | ui rollover ×3 |
| `ui_toggle` | Checkbox/setting toggle | ui switch1 |

**Engine facts the composer must respect** (from [scripts/sfx.gd](../../scripts/sfx.gd)):
- **Variants per key:** the engine picks a random variant + jitters pitch ±6% each play. Deliver
  **3–5 short variants** for any repeating SFX (combat, footsteps, hits) — that's what keeps a horde
  from sounding like one looped sample. One-shots (win/lose/betrayal) can be single files.
- **Gain-staging is already dialed in** per key (e.g. `cast` −16 dB & 110 ms gap; `betray_sting`
  −2 dB & 500 ms gap). Deliver clips at a **consistent, healthy level**; do *not* pre-bake these
  trims — the engine applies them. Master bus has a **−1 dB hard limiter**; leave headroom.
- **Throttle gaps** collapse bursts to one voice — design mass-event sounds (`enrage`, `defect`,
  `swarm`, `crowd`) to read as **one collective swell**, not a single tiny tick multiplied.

---

## Part B — Critical analysis (the gaps & weaknesses)

1. **Music doesn't know the game is happening.** No reactivity to suspicion, no menu/intro track,
   no victory/defeat music, no breather. Biggest miss → the decided model is an **adaptive score**.
2. **`betray_sting` / `betray_roar` are a sci-fi explosion + a metal clang.** The game's whole
   climax — its title-drop "**SHE KNOWS.**" — currently sounds like a door slamming. Deserves a
   composed **transition stinger**, not an SFX.
3. **`levelup`, `wave_clear`, `win` are literally UI *click* switches.** "The Princess grows
   stronger!" resolves with a menu blip. These (`wave_start`, `wave_clear`, `levelup`, `win`)
   should be **musical stings**, written in the score's key, not sound effects.
4. **`player_die` is overloaded for two opposite outcomes.** Same clip plays when the **Squire dies**
   (your failure) and when the **Princess dies** (your triumph / win condition). Narrative opposites.
   **Recommend splitting** into `squire_die` (tragic thud) and `princess_fall` (big, reverent — her
   fall is the win).
5. **The Princess has no non-lethal hurt sound.** No `princess_hurt` key — when she takes damage
   she's silent (only `player_hurt` exists, and that's the Squire). She's the co-lead; her getting
   hurt should register. **New key needed.**
6. **`gift_curse` (your sabotage tell) is a wooden creak.** The player's most important *moral*
   feedback — the sound of doing the bad thing. Should be a deliberate, sinister signature.
7. **Comedy is unscored.** The "**67**" swarm gag and the peasant revolt are played straight
   (tin/footstep impacts). The game is funny; the audio isn't in on the joke.
8. **Several live moments are fully silent** (no key at all): **pause/unpause**, **curse-toggle
   (Ctrl)**, **poison ticks** on the cursed Princess, **loot drop** from a killed monster, the
   **between-wave intermission**. Listed as additions in Part C-3.

---

## Part C — The commission list

### C-1. Adaptive score (music) — the centerpiece

**The serving theme is delivered as 3 synchronized STEMS**, not one file. All three must be **same
BPM, same key, same length, loop-aligned** so the game can crossfade between them in real time as the
suspicion meter climbs (game exposes `suspicion` 0–100; >85% trips the on-screen "SHE'S ONTO YOU"
warning).

| Deliverable | File(s) | Intensity / cue | Direction |
| --- | --- | --- | --- |
| **Title / briefing theme** | `menu.ogg` (loop) | Intro & briefing screen — *currently silent* | Inviting heroic fairy-tale with a sly wink. Sets up the bait-and-switch. |
| **Serving — Layer A (calm bed)** | `serving_calm.ogg` | Suspicion 0–~33% | Bright, dutiful, storybook-heroic. The "good squire" mask. |
| **Serving — Layer B (tension)** | `serving_tension.ogg` | Fades in ~33–75% | Same theme, soured — dissonance, a ticking/heartbeat pulse, minor-mode shading. |
| **Serving — Layer C (dread)** | `serving_dread.ogg` | Fades in ~75–100% (peaks at "SHE'S ONTO YOU") | Near-breaking. Low brass/choral menace over the theme, on the edge of snapping. |
| **Betrayal transition** | `betrayal.ogg` (one-shot, ~3–6 s) | The turn — replaces `betray_sting`/`betray_roar` | The mask shatters. Deep WHOOM → the hero's theme inverted/weaponized. Bridges into the boss loop. |
| **Boss loop** | `boss.ogg` (loop, *replace*) | Phase 2, she hunts you | Frantic, driving, underdog-villain desperation. Quote the hero theme, now monstrous. |
| **Victory** | `victory.ogg` (loop or long one-shot) | "LONG LIVE THE SQUIRE" — *currently a UI click* | Hollow, dark coronation. Triumphant but *wrong* — you killed the hero. |
| **Defeat** | `defeat.ogg` (one-shot) | "EXECUTED FOR TREASON" / "A POINTLESS DEATH" — *currently a glass break* | Tragicomic collapse. The schemer caught. |

Optional: a short **between-wave breather** variant, or let `serving_calm` carry the 6 s intermission.

> **Engineering note (for whoever wires this in, after stems arrive):** add `Sfx.play_layers([...])`
> (one looping `AudioStreamPlayer` per stem on the Music bus, all started in the same frame so they
> stay sample-aligned; layer A audible, B/C at −80 dB) and `Sfx.set_intensity(frac)` (crossfade by
> 0–1); call `Sfx.set_intensity(suspicion / 100.0)` each frame in the serving phase; at betrayal
> stop the layers, play `betrayal.ogg`, then loop `boss.ogg`. Existing `play_music()` /
> `stop_music()` stay for the single-track cues (menu/victory/defeat).

### C-2. Replace all 37 SFX keys with originals

Same keys, same engine, original content. **Deliver 3–5 variants** for every repeating key; single
files are fine for one-shots. The world is fantasy — steer *away* from the current sci-fi clips.

**Combat / actors:** `swing` light clean heroic blade-swish · `enemy_swing` cruder/heavier orcish
swipe · `enemy_hurt` meaty orc grunt+thwack · `enemy_die` squelchy grunt + poof · `player_hurt`
sharp pained thud (you're squishy) · `boom` **arcane** concussive blast (not sci-fi) · `zap`
crackling **holy** lightning/smite (not laser) · `cast` soft arcane shimmer-whoosh (very frequent —
keep it tiny). **Split `player_die`** → `squire_die` (tragic, final) + new `princess_fall` (big,
reverent — the win). Add new `princess_hurt` (soft pained cue for her non-lethal hits).

**Squire actions / gifts:** `dash` quick whoosh + footfall burst · `pickup` satisfying loot
chime/clink · `princess_drink` glug + heal shimmer · `princess_arm` metallic equip/power-up ·
**`gift_curse`** *signature dark sting* (the sound of sabotage, low and sinister) · `tipoff` sneaky
conspiratorial snap/whistle · `enrage` collective monstrous growl-swell · `defect` an
allegiance-flip cue (a turning chord).

**Events / chaos:** `explosion_big` enormous deep boom + debris · `crowd` murmuring angry-mob swell ·
`infighting` chaotic scuffle/clatter · **`swarm`** lean into the **"67" comedy** (tiny squeaks /
absurd horde patter) · `trap_spawn` mechanical warning clank · `trap_hit` sharp metallic jab ·
`angel` **choral/holy** descending beam.

**System / UI stings** (write *in the score's key* so they sit with the music): `wave_start` brief
announce/horn · `wave_clear` triumphant resolve · `levelup` ascending power-up · `betray_sting` +
`betray_roar` → the composed `betrayal.ogg` · `win` / `lose` → victory/defeat tracks · `ui_click`
clean tick · `ui_hover` subtle tick · `ui_toggle` toggle click.

### C-3. New keys for currently-silent moments (additions)

| New key | Moment | Direction |
| --- | --- | --- |
| `pause` | Open/close pause menu | Soft muffle/whoosh; world recedes |
| `curse_toggle` | Ctrl toggles curse on carried item | Dark magical shimmer (arming the sabotage) |
| `poison_tick` | Cursed-potion damage tick on Princess | Faint sickly bubble (throttle long — ticks often) |
| `loot_drop` | Item drops from a killed monster | Light sparkle/clink |

---

## Part D — Technical delivery spec

- **Format:** OGG Vorbis, **44.1 kHz, stereo**. Music loops are flagged in code, so deliver
  **seamlessly loopable** loops (clean head/tail).
- **Adaptive stems (`serving_calm/tension/dread`):** **identical length, BPM, key**, bar-aligned
  loop points — non-negotiable, or the crossfade drifts.
- **Levels:** consistent, healthy peaks with headroom (master has a −1 dB limiter). **Do not**
  pre-bake the per-key trims or the −7 dB music bed — the engine does that.
- **SFX variants:** the loader expects either an **exact-name set** or a **numbered run**
  `base_000 … base_00N`. Cleanest integration: deliver originals into `assets/audio/orig/<group>/`
  with clean names; the `_build_library()` map in [scripts/sfx.gd](../../scripts/sfx.gd) is then
  re-pointed **once** (single source of truth). Music goes in `assets/audio/music/` by the exact
  names in C-1.
- **Counts:** ~8 music items (C-1) + 37 SFX keys × 3–5 variants (C-2) + 4 new keys (C-3).

---

## Delivery checklist for the composer

- [ ] `menu.ogg`, `boss.ogg`, `victory.ogg`, `defeat.ogg`, `betrayal.ogg` (loops/one-shots)
- [ ] `serving_calm.ogg` + `serving_tension.ogg` + `serving_dread.ogg` (same BPM/key/length, loop-aligned)
- [ ] 37 SFX keys × 3–5 variants each (fantasy palette, healthy unprocessed levels)
- [ ] Split-out: `squire_die`, `princess_fall`, `princess_hurt`
- [ ] New: `pause`, `curse_toggle`, `poison_tick`, `loot_drop`
- [ ] All OGG, 44.1 kHz stereo, seamless loops where looped
