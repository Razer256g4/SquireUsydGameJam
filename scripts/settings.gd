extends RefCounted
class_name Settings
## Global, run-lifetime player options. Plain static vars so they survive a scene
## reload (R / "scheme again") without a save file. The pause menu (pause_menu.gd)
## flips these; juice code (Game.shake / Game.hitstop) reads them as gates.

static var screen_shake := true
static var hit_stop := true

# Audio levels (0..1), surfaced as pause-menu sliders. The Sfx helper pushes these
# onto the Master / SFX / Music buses via Sfx.apply_volumes(); a 0 mutes that bus.
static var master_volume := 1.0
static var sfx_volume := 1.0
static var music_volume := 0.7
