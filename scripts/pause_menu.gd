extends CanvasLayer
class_name PauseMenu
## Esc-toggled pause + Settings overlay. Processes ALWAYS so it still runs while the
## tree is paused. Toggles/sliders flip the `Settings` statics that the juice, audio
## and window code read. Skinned with the shared Franuka `UiKit` style (warm parchment
## "fantasy RPG" look) to match the HUD. The inner column is rebuilt every time the
## menu opens so the widgets always reflect the live Settings (e.g. fullscreen via F11).

var _box: VBoxContainer       # inner column; repopulated on every open

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	# pixel art stays crisp via project default texture filter = Nearest
	_build()
	visible = false

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# Parchment backing — a PanelContainer (auto-sizes to content) skinned with the
	# ornate Franuka frame. texture_margin 48 keeps each gold corner STUD inside its
	# 9-slice corner (the old 32 sliced through them, smearing the studs/border along
	# the edges as the panel stretched). content-margin 44 insets the column clear.
	var panel := UiKit.panel_container(UiKit.PANEL_ORNATE, 48, 44)
	panel.custom_minimum_size = Vector2(440, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP   # eat clicks so they don't fall through to the arena
	center.add_child(panel)

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 16)
	_box.custom_minimum_size = Vector2(360, 0)
	panel.add_child(_box)
	_populate()

## Fill (or refill) the inner column from the current Settings. Cheap enough to run
## on every open, which keeps every widget in sync with the live values.
func _populate() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.free()

	# --- PAUSED header (dark banner + centred gold text) ---
	var header := UiKit.title_banner("PAUSED", 34)
	header.custom_minimum_size = Vector2(0, 92)   # banner art is 144x96 — near-native height so the 9-slice doesn't squish
	_box.add_child(header)

	_section("DISPLAY")
	_box.add_child(_toggle_row("Fullscreen  (F11)", Settings.fullscreen, _on_fullscreen))
	_box.add_child(_toggle_row("VSync", Settings.vsync, _on_vsync))

	_section("AUDIO")
	_box.add_child(_slider_row("Master volume", Settings.master_volume, _on_master))
	_box.add_child(_slider_row("SFX volume", Settings.sfx_volume, _on_sfx))
	_box.add_child(_slider_row("Music volume", Settings.music_volume, _on_music))

	_section("GAMEPLAY")
	_box.add_child(_toggle_row("Screen shake", Settings.screen_shake, _on_shake))
	_box.add_child(_toggle_row("Hit-stop", Settings.hit_stop, _on_hitstop))

	_space(8)

	var resume := UiKit.button("Resume  (Esc)", UiKit.BTN_GOLD, 24, UiKit.INK)
	resume.pressed.connect(func() -> void: Sfx.play("ui_click"); _toggle())
	_box.add_child(resume)

	var restart := UiKit.button("Restart", UiKit.BTN_RED, 22, Color.WHITE)
	restart.pressed.connect(func() -> void: Sfx.play("ui_click"); _restart())
	_box.add_child(restart)

	var reset := UiKit.button("Reset to defaults", UiKit.BTN_TAN, 20, UiKit.INK)
	reset.pressed.connect(_on_reset)
	_box.add_child(reset)

## A clean section header (dark heading + divider) — no stretched banner.
func _section(text: String) -> void:
	_box.add_child(UiKit.section_header(text, 22))

func _space(h: int) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(s)

## A Franuka-skinned checkbox row (dark ink label on parchment). Wires `toggled` to `cb`.
func _toggle_row(label_text: String, value: bool, cb: Callable) -> CheckBox:
	var pair := UiKit.toggle(label_text, value)
	var box: CheckBox = pair[0]
	box.toggled.connect(cb)
	return box

## A labelled Franuka slider. The label uses dark ink so it reads on the parchment.
func _slider_row(label_text: String, value: float, cb: Callable) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	var l := UiKit.label(label_text, 18, UiKit.INK, false)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(l)
	var s := UiKit.slider(value, 0.0, 1.0, 0.05)
	s.custom_minimum_size = Vector2(300, 28)
	s.value_changed.connect(cb)
	col.add_child(s)
	return col

func _on_fullscreen(v: bool) -> void: Settings.fullscreen = v; Settings.apply_display(); Sfx.play("ui_toggle")
func _on_vsync(v: bool) -> void: Settings.vsync = v; Settings.apply_display(); Sfx.play("ui_toggle")
func _on_shake(v: bool) -> void: Settings.screen_shake = v; Sfx.play("ui_toggle")
func _on_hitstop(v: bool) -> void: Settings.hit_stop = v; Sfx.play("ui_toggle")
func _on_master(v: float) -> void: Settings.master_volume = v; Sfx.apply_volumes()
func _on_sfx(v: float) -> void: Settings.sfx_volume = v; Sfx.apply_volumes(); Sfx.play("ui_click")
func _on_music(v: float) -> void: Settings.music_volume = v; Sfx.apply_volumes()

func _on_reset() -> void:
	Settings.reset_defaults()     # restores statics + re-applies the window mode
	Sfx.apply_volumes()           # push the restored levels onto the buses
	Sfx.play("ui_click")
	_populate()                   # rebuild widgets so they show the defaults

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_ESCAPE:
			_toggle()
			get_viewport().set_input_as_handled()
		KEY_F11:
			Settings.toggle_fullscreen()
			Sfx.play("ui_toggle")
			if visible:
				_populate()       # keep the Fullscreen checkbox in sync while open
			get_viewport().set_input_as_handled()

func _toggle() -> void:
	visible = not visible
	if visible:
		_populate()               # re-sync widgets with the live Settings on open
	get_tree().paused = visible

func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
