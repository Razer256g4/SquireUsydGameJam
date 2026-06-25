extends CanvasLayer
class_name IntroScreen
## Start-of-run briefing: the betrayal premise + controls. Pauses the game until
## dismissed, and shows only once per session so quick restarts (R) don't nag.
## Built from real Control nodes like PauseMenu, so it's crisp at any resolution.

static var seen := false

var _done := false
var _pause_menu: Node = null      # muted while we're up so Esc can't fight the overlay

func _ready() -> void:
	layer = 25                                  # above HUD (10) and the pause menu (20)
	process_mode = Node.PROCESS_MODE_ALWAYS
	for sib in get_parent().get_children():
		if sib is PauseMenu:
			_pause_menu = sib
			sib.process_mode = Node.PROCESS_MODE_DISABLED
	_build()
	get_tree().paused = true

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.9)
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
		margin.add_theme_constant_override("margin_" + side, 36)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	_label(box, "ROYAL ASSISTANT", 46, Color(1.0, 0.55, 0.72), true)
	_label(box, "Serve the Princess.   Betray the Princess.", 18, Color(1, 1, 1, 0.55), true)
	_label(box, "You are her devoted squire — and her undoing.", 17, Color(0.92, 0.92, 0.96))

	_space(box, 8)
	_label(box, "PHASE 1 · SERVE & SABOTAGE", 19, Color(1.0, 0.82, 0.4))
	_label(box, "Grab supplies off the floor and hand them over by bumping into her.\n" +
		"Press Ctrl to TAMPER a gift first — cursed items quietly weaken her but\n" +
		"raise her SUSPICION (a genuine gift calms it). Tip off the horde (E) and\n" +
		"spark chaos (Q) to wound her, at the cost of more suspicion.", 17, Color(0.9, 0.9, 0.95))

	_space(box, 8)
	_label(box, "PHASE 2 · BETRAYAL", 19, Color(1.0, 0.82, 0.4))
	_label(box, "Fill the Suspicion meter and she turns on you — but every monster you\n" +
		"befriended defects to your side, and she is only as strong as whatever\n" +
		"you left her. This is the payoff: bring her down.", 17, Color(0.9, 0.9, 0.95))

	_space(box, 8)
	_label(box, "CONTROLS", 19, Color(1.0, 0.82, 0.4))
	_label(box, "Move — WASD / Arrows       Dash — Space       Tamper — Ctrl\n" +
		"Give — bump the Princess       Tip off — E       Scheme — Q\n" +
		"Pause — Esc       Restart — R       Fullscreen — F11", 17, Color(0.82, 0.92, 1.0))

	_space(box, 14)
	_label(box, "Press  Space · Enter · click  to begin", 20, Color(0.6, 1.0, 0.7), true)

func _label(box: VBoxContainer, text: String, size: int, col: Color, center := false) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)

func _space(box: VBoxContainer, h: int) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	box.add_child(s)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_SPACE or k == KEY_ENTER or k == KEY_KP_ENTER:
			_dismiss()
		get_viewport().set_input_as_handled()       # swallow ALL keys while the briefing is up
	elif event is InputEventMouseButton and event.pressed:
		_dismiss()
		get_viewport().set_input_as_handled()

func _dismiss() -> void:
	if _done:
		return
	_done = true
	seen = true
	if _pause_menu:
		_pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	Sfx.play("ui_click")
	queue_free()
