extends RefCounted
class_name Settings
## Global, run-lifetime player options. Plain static vars so they survive a scene
## reload (R / "scheme again") without a save file. The pause menu (pause_menu.gd)
## flips these; juice code (Game.shake / Game.hitstop) reads them as gates, Sfx
## reads the volumes, and the window mode is pushed onto the OS via apply_display().

# --- display (pushed onto the OS window by apply_display) ---
static var fullscreen := false
static var vsync := true

# --- juice ---
static var screen_shake := true
static var hit_stop := true

# Audio levels (0..1), surfaced as pause-menu sliders. The Sfx helper pushes these
# onto the Master / SFX / Music buses via Sfx.apply_volumes(); a 0 mutes that bus.
static var master_volume := 1.0
static var sfx_volume := 1.0
static var music_volume := 0.7

## Push the display options onto the OS window. Idempotent, so it's safe to call on
## every scene load — that's what keeps fullscreen/vsync sticky across a restart (R).
## Works on desktop and on the HTML5 canvas (fullscreen needs a user gesture there,
## which the toggle/F11 press supplies; vsync is a harmless no-op on web).
##
## Only ever switches between FULLSCREEN and MAXIMIZED — never forces the small
## startup 1600x900 windowed size — so the play area always fills the screen and the
## arena (Game.arena, sized to the viewport) never collapses back to a letterbox.
static func apply_display() -> void:
	var cur := DisplayServer.window_get_mode()
	if fullscreen and cur != DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fullscreen and cur == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

## Flip fullscreen and apply it — the F11 hotkey and the pause-menu toggle share this.
static func toggle_fullscreen() -> void:
	fullscreen = not fullscreen
	apply_display()

## Restore every option to its shipped default and re-apply the display state. Audio
## is re-applied by the caller (pause_menu) to avoid a Settings<->Sfx cyclic reference.
static func reset_defaults() -> void:
	fullscreen = false
	vsync = true
	screen_shake = true
	hit_stop = true
	master_volume = 1.0
	sfx_volume = 1.0
	music_volume = 0.7
	apply_display()
