extends CanvasLayer
class_name PauseMenu
## Esc-toggled pause + options overlay. Processes ALWAYS so it still runs while the
## tree is paused. Toggles flip the `Settings` statics that the juice code reads.
## Uses real Control nodes (Buttons/CheckButtons) for robust, clickable widgets.

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

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	box.add_child(_toggle_row("Screen shake", Settings.screen_shake, _on_shake))
	box.add_child(_toggle_row("Hit-stop", Settings.hit_stop, _on_hitstop))
	box.add_child(_slider_row("Master volume", Settings.master_volume, _on_master))
	box.add_child(_slider_row("SFX volume", Settings.sfx_volume, _on_sfx))
	box.add_child(_slider_row("Music volume", Settings.music_volume, _on_music))

	var resume := Button.new()
	resume.text = "Resume  (Esc)"
	resume.pressed.connect(func() -> void: Sfx.play("ui_click"); _toggle())
	box.add_child(resume)

	var restart := Button.new()
	restart.text = "Restart"
	restart.pressed.connect(func() -> void: Sfx.play("ui_click"); _restart())
	box.add_child(restart)

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

func _on_shake(v: bool) -> void: Settings.screen_shake = v; Sfx.play("ui_toggle")
func _on_hitstop(v: bool) -> void: Settings.hit_stop = v; Sfx.play("ui_toggle")
func _on_master(v: float) -> void: Settings.master_volume = v; Sfx.apply_volumes()
func _on_sfx(v: float) -> void: Settings.sfx_volume = v; Sfx.apply_volumes(); Sfx.play("ui_click")
func _on_music(v: float) -> void: Settings.music_volume = v; Sfx.apply_volumes()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_toggle()
		get_viewport().set_input_as_handled()

func _toggle() -> void:
	visible = not visible
	get_tree().paused = visible

func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
