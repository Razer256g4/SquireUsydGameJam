extends CanvasLayer
class_name PauseMenu
## Esc-toggled pause + Settings overlay. Processes ALWAYS so it still runs while the
## tree is paused. Toggles/sliders flip the `Settings` statics that the juice, audio
## and window code read. Uses real Control nodes (Buttons/CheckButtons/HSliders) for
## robust, clickable widgets. The inner column is rebuilt every time the menu opens
## so the widgets always reflect the live Settings (e.g. fullscreen toggled via F11).

var _box: VBoxContainer       # inner column; repopulated on every open

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
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

	var panel := PanelContainer.new()
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 12)
	_box.custom_minimum_size = Vector2(320, 0)
	margin.add_child(_box)
	_populate()

## Fill (or refill) the inner column from the current Settings. Cheap enough to run
## on every open, which keeps every widget in sync with the live values.
func _populate() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.free()

	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)

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

	var resume := Button.new()
	resume.text = "Resume  (Esc)"
	resume.pressed.connect(func() -> void: Sfx.play("ui_click"); _toggle())
	_box.add_child(resume)

	var restart := Button.new()
	restart.text = "Restart"
	restart.pressed.connect(func() -> void: Sfx.play("ui_click"); _restart())
	_box.add_child(restart)

	var reset := Button.new()
	reset.text = "Reset to defaults"
	reset.pressed.connect(_on_reset)
	_box.add_child(reset)

func _section(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color(1.0, 0.82, 0.4))
	_box.add_child(l)

func _space(h: int) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	_box.add_child(s)

func _toggle_row(label: String, value: bool, cb: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.text = label
	c.button_pressed = value
	c.toggled.connect(cb)
	return c

func _slider_row(label: String, value: float, cb: Callable) -> Control:
	var col := VBoxContainer.new()
	var l := Label.new()
	l.text = label
	col.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(280, 0)
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
