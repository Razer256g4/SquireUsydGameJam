extends CanvasLayer
class_name IntroScreen
## Start-of-run briefing: the betrayal premise + controls. Pauses the game until
## dismissed, and shows only once per session so quick restarts (R) don't nag.
## Restyled with the shared Franuka UiKit (parchment panel + gold banners) to match
## the HUD, pause menu and end screen.

static var seen := false

var _done := false
var _pause_menu: Node = null      # muted while we're up so Esc can't fight the overlay

func _ready() -> void:
	layer = 25                                  # above HUD (10) and the pause menu (20)
	process_mode = Node.PROCESS_MODE_ALWAYS
	# pixel art stays crisp via project default texture filter = Nearest
	for sib in get_parent().get_children():
		if sib is PauseMenu:
			_pause_menu = sib
			sib.process_mode = Node.PROCESS_MODE_DISABLED
	_build()
	get_tree().paused = true

func _build() -> void:
	# Dark translucent backing — also eats clicks behind the panel.
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# Parchment panel — a PanelContainer (auto-sizes to content) skinned with the
	# Franuka frame. texture_margin 44 keeps each ornate corner GEM inside its 9-slice
	# corner (BGbox_01A's gems reach ~38px in; the old 26 sliced through them, smearing
	# the border along the edges). content-margin 44 insets the briefing clear of the
	# ~27px border + corner gems so no text touches the frame.
	var panel := UiKit.panel_container(UiKit.PANEL, 44, 44)
	panel.custom_minimum_size = Vector2(720, 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(box)

	# --- Title banner (light/gold on dark) ---
	_banner(box, "ROYAL ASSISTANT", 34, 88)

	# --- Premise (dark ink on parchment; emphasis = dark red, NOT gold-on-parchment) ---
	_text(box, "Serve the Princess.   Betray the Princess.", 24, UiKit.EMPH, true)
	_text(box, "You are her devoted squire — and her undoing.", 20, UiKit.INK, true)

	_divider(box)

	# --- Phase 1 ---
	box.add_child(UiKit.section_header("PHASE 1 · SERVE & SABOTAGE"))
	_text(box, "Grab supplies off the floor and hand them over by bumping into her. " +
		"Press Ctrl to TAMPER a gift first — cursed items quietly weaken her but " +
		"raise her SUSPICION (a genuine gift calms it). Tip off the horde (E) and " +
		"spark chaos (Q) to wound her, at the cost of more suspicion.", 20, UiKit.INK)

	_spacer(box, 4)

	# --- Phase 2 ---
	box.add_child(UiKit.section_header("PHASE 2 · BETRAYAL"))
	_text(box, "Fill the Suspicion meter and she turns on you — but every monster you " +
		"befriended defects to your side, and she is only as strong as whatever " +
		"you left her. This is the payoff: bring her down.", 20, UiKit.INK)

	_divider(box)

	# --- Controls (mini-icons mirror the HUD ability bar) ---
	box.add_child(UiKit.section_header("CONTROLS"))
	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 6)
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(controls)
	_ctrl(controls, "", "Move", "WASD / Arrows")
	_ctrl(controls, UiKit.IC_BOOT, "Dash", "Space")
	_ctrl(controls, "", "Give", "bump the Princess")
	_ctrl(controls, UiKit.IC_FLASK, "Tamper", "Ctrl")
	_ctrl(controls, UiKit.IC_ALERT, "Tip off", "E")
	_ctrl(controls, UiKit.IC_WAND, "Scheme", "Q")
	_ctrl(controls, "", "Pause", "Esc")
	_ctrl(controls, "", "Restart", "R")
	_ctrl(controls, "", "Fullscreen", "F11")

	_spacer(box, 8)

	# --- Begin button (same dismiss path as Space / Enter / click) ---
	var begin := UiKit.button("Begin", UiKit.BTN_GOLD, 24, UiKit.INK)
	begin.custom_minimum_size = Vector2(200, 56)
	begin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	begin.focus_mode = Control.FOCUS_NONE   # don't steal the swallow-all key handling
	begin.pressed.connect(_dismiss)
	box.add_child(begin)

	_text(box, "Press  Space · Enter · click  to begin", 19, UiKit.INK_GREEN, true)

# A dark gold-text title/section banner with a fixed height.
func _banner(box: VBoxContainer, text: String, font_size: int, height: int) -> void:
	var b := UiKit.title_banner(text, font_size)
	b.custom_minimum_size = Vector2(0, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(b)

# Dark-ink body/premise text on parchment, word-wrapped to the panel width.
func _text(box: VBoxContainer, text: String, size: int, col: Color, center := false) -> void:
	var l := UiKit.label(text, size, col, false)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)

# One control line: optional ability icon · action name · key(s).
func _ctrl(box: VBoxContainer, icon_path: String, action: String, keys: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var ic := UiKit.icon(icon_path, 22) if icon_path != "" else null
	if ic != null and ic.texture != null:
		row.add_child(ic)
	else:
		var pad := Control.new()
		pad.custom_minimum_size = Vector2(22, 22)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pad)

	var name_l := UiKit.label(action, 20, UiKit.INK, false)
	name_l.custom_minimum_size = Vector2(150, 0)
	row.add_child(name_l)

	var key_l := UiKit.label(keys, 20, UiKit.INK_KEY, false)
	key_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(key_l)

	box.add_child(row)

func _divider(box: VBoxContainer) -> void:
	box.add_child(UiKit.divider())

func _spacer(box: VBoxContainer, h: int) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	Sfx.serving_music(0.0)       # gameplay begins — crossfade the menu theme into the calm serving track
	Sfx.play("ui_click")
	queue_free()
