extends RefCounted
class_name Settings
## Global, run-lifetime player options. Plain static vars so they survive a scene
## reload (R / "scheme again") without a save file. The pause menu (pause_menu.gd)
## flips these; juice code (Game.shake / Game.hitstop) reads them as gates.

static var screen_shake := true
static var hit_stop := true

# Placeholders for when audio lands (the deferred music/SFX pass). Wired into the
# pause-menu sliders now so they're ready; nothing reads them until buses exist.
static var master_volume := 1.0
static var sfx_volume := 1.0
