extends CanvasLayer
class_name Cutscene
## Reusable, data-driven story slideshow. Mirrors intro.gd's overlay pattern: it
## pauses the tree, runs while paused (PROCESS_MODE_ALWAYS), eats clicks with a dark
## dim, swallows all input, and queue_free()s itself on dismiss. Feed it `beats` (or
## use the Cutscene.opening() / Cutscene.victory() factories) and connect `finished`.
##
## Each beat is a Dictionary:
##   {
##     "title": String, "body": String,          # narration (text lives in Lines)
##     "char":  "" | "princess" | "squire",      # which game sprite to pose (Anim)
##     "char_tint": Color, "big": bool,           # tint / extra scale for the sprite
##     "icon":  String (path, "" for none),       # a Franuka symbol (crown / skull)
##     "amulet": bool,                            # show the glowing amulet
##     "tint":  Color,                            # mood wash over the backdrop
##   }
## The PROSE (title/body) lives in Lines.STORY_*; the per-beat VISUALS are chosen here.

signal finished

var beats: Array = []
var pause_tree := true
var mark_seen := false          # opening sets this so a quick R-restart won't replay

const CHAR_SCALE := 5.5          # Tiny RPG art fills little of its 100px frame, so scale up hard

var _i := -1
var _busy := false              # true mid-crossfade so a press can't double-advance
var _done := false
var _pause_menu: Node = null    # muted while we're up (matches intro.gd)

# Backdrop + faded content tree.
var _dim: ColorRect
var _content: Control            # everything that crossfades between beats
var _tint: ColorRect             # per-beat mood wash
var _stage: Control              # hosts the manually-positioned sprite/amulet/icon
var _title: Label
var _body: Label
var _prompt: Label

var _stage_items: Array = []     # [{n, ax, ay}] repositioned on viewport resize
var _pulse_tw: Tween             # the looping amulet-glow pulse (killed per beat)

# ------------------------------------------------------------------ factories
static func opening() -> Cutscene:
	var cs := Cutscene.new()
	cs.beats = _opening_beats()
	cs.pause_tree = true
	cs.mark_seen = true
	return cs

static func victory(_score := 0, _wave := 0) -> Cutscene:
	# score/wave are shown on the existing end card (revealed when this frees), not here.
	var cs := Cutscene.new()
	cs.beats = _victory_beats()
	cs.pause_tree = true
	return cs

# Zip the prose (from Lines) with the visual spec for each beat.
static func _opening_beats() -> Array:
	var vis := [
		{"char": "princess", "char_tint": Color(1.0, 0.96, 0.82), "icon": UiKit.IC_CROWN, "amulet": false, "tint": Color(0.22, 0.14, 0.03, 0.34)},
		{"char": "squire",   "char_tint": Color(0.70, 0.78, 0.95), "icon": "",             "amulet": false, "tint": Color(0.04, 0.06, 0.13, 0.42)},
		{"char": "",         "char_tint": Color.WHITE,             "icon": "",             "amulet": true,  "tint": Color(0.12, 0.03, 0.18, 0.46)},
		{"char": "squire",   "char_tint": Color(0.85, 0.70, 1.0),  "icon": UiKit.IC_SKULL, "amulet": true,  "tint": Color(0.18, 0.02, 0.06, 0.50)},
	]
	return _zip(Lines.STORY_OPENING, vis)

static func _victory_beats() -> Array:
	var vis := [
		{"char": "",       "char_tint": Color.WHITE,            "icon": "",             "amulet": true, "tint": Color(0.16, 0.03, 0.22, 0.52)},
		{"char": "squire", "char_tint": Color(1.0, 0.92, 0.66), "icon": UiKit.IC_CROWN, "amulet": false, "big": true, "tint": Color(0.24, 0.16, 0.03, 0.38)},
		{"char": "squire", "char_tint": Color(0.62, 0.70, 0.82),"icon": UiKit.IC_SKULL, "amulet": false, "tint": Color(0.03, 0.05, 0.10, 0.55)},
		{"char": "squire", "char_tint": Color(0.74, 0.92, 0.78),"icon": "",             "amulet": true,  "tint": Color(0.06, 0.08, 0.12, 0.48)},
	]
	return _zip(Lines.STORY_VICTORY, vis)

static func _zip(text: Array, vis: Array) -> Array:
	var out: Array = []
	for i in mini(text.size(), vis.size()):
		var b: Dictionary = (vis[i] as Dictionary).duplicate()
		b["title"] = text[i]["title"]
		b["body"] = text[i]["body"]
		out.append(b)
	return out

# ------------------------------------------------------------------ lifecycle
func _ready() -> void:
	layer = 30                                  # above HUD (10), pause (20), intro (25)
	process_mode = Node.PROCESS_MODE_ALWAYS
	if mark_seen:
		IntroScreen.seen = true                 # once-per-session: R won't replay the opening
	for sib in get_parent().get_children():     # mute the pause menu while we're up
		if sib is PauseMenu:
			_pause_menu = sib
			sib.process_mode = Node.PROCESS_MODE_DISABLED
	_build_ui()
	if pause_tree:
		get_tree().paused = true
	get_viewport().size_changed.connect(_relayout)
	if beats.is_empty():
		_finish()
		return
	_content.modulate.a = 0.0
	_show_beat(0)
	create_tween().tween_property(_content, "modulate:a", 1.0, 0.5)

func _build_ui() -> void:
	# Near-opaque dark backing — also eats clicks behind the panel.
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.02, 0.04, 0.96)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	# Everything below crossfades together between beats.
	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	_tint = ColorRect.new()
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.color = Color(0, 0, 0, 0)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_tint)

	_stage = Control.new()                      # sprite/amulet/icon positioned by hand
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_stage)

	# Text panel, parked in the lower-centre (the stage art fills the space above it).
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.anchor_top = 0.50
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(center)

	var panel := UiKit.panel_container(UiKit.PANEL, 44, 40)
	panel.custom_minimum_size = Vector2(880, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(box)

	# Title banner (gold on the dark Franuka banner) — built inline so the Label is
	# ours to retarget each beat (UiKit.title_banner buries its label).
	var banner := Control.new()
	banner.custom_minimum_size = Vector2(0, 84)
	banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bn := UiKit.nine(UiKit.BANNER, 22)
	bn.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner.add_child(bn)
	_title = UiKit.label("", 32, UiKit.GOLD, true)
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_child(_title)
	box.add_child(banner)

	box.add_child(UiKit.divider())

	_body = UiKit.label("", 24, UiKit.INK, false)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_body)

	# "Press to continue" prompt — light so it reads on the dark dim; gently pulses.
	_prompt = UiKit.label("Press  Space  ·  click   to continue   (Esc skips)", 19, UiKit.GREEN, false)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.anchor_left = 0.0
	_prompt.anchor_right = 1.0
	_prompt.offset_top = -56
	_prompt.offset_bottom = -24
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(_prompt)
	var pt := create_tween().set_loops()
	pt.tween_property(_prompt, "modulate:a", 0.45, 0.7)
	pt.tween_property(_prompt, "modulate:a", 1.0, 0.7)

# ------------------------------------------------------------------ beats
func _show_beat(idx: int) -> void:
	if idx < 0 or idx >= beats.size():
		return
	_i = idx
	var b: Dictionary = beats[idx]
	_title.text = String(b.get("title", ""))
	_body.text = String(b.get("body", ""))
	_tint.color = b.get("tint", Color(0, 0, 0, 0))
	_build_stage(b)
	_relayout()

func _build_stage(b: Dictionary) -> void:
	if _pulse_tw:
		_pulse_tw.kill()
		_pulse_tw = null
	for c in _stage.get_children():
		c.queue_free()
	_stage_items.clear()

	var ch: String = b.get("char", "")
	var has_amulet: bool = b.get("amulet", false)

	if ch != "":
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = Anim.swordsman() if ch == "princess" else Anim.priest()
		spr.animation = "idle"
		spr.play("idle")
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var s := CHAR_SCALE * (1.25 if b.get("big", false) else 1.0)
		spr.scale = Vector2(s, s)
		spr.modulate = b.get("char_tint", Color.WHITE)
		_add_stage(spr, 0.5, 0.27)

	if has_amulet:
		var am := _make_amulet()
		# beside the character if one is present, otherwise centred as the focal point
		if ch != "":
			_add_stage(am, 0.66, 0.31)
		else:
			_add_stage(am, 0.5, 0.27)
		_start_pulse(am.get_node("glow") as Node2D)

	var icon_path: String = b.get("icon", "")
	if icon_path != "":
		var t := UiKit.tex(icon_path)
		if t:
			var ic := Sprite2D.new()
			ic.texture = t
			ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			ic.scale = Vector2(3.0, 3.0)
			_add_stage(ic, 0.5, 0.13)        # floats above the character's head

func _add_stage(node: Node2D, ax: float, ay: float) -> void:
	_stage.add_child(node)
	_stage_items.append({"n": node, "ax": ax, "ay": ay})
	_place(node, ax, ay)

func _place(node: Node2D, ax: float, ay: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	node.position = Vector2(vp.x * ax, vp.y * ay)

func _relayout() -> void:
	for it in _stage_items:
		if is_instance_valid(it["n"]):
			_place(it["n"], it["ax"], it["ay"])

# A glowing violet amulet, drawn procedurally (no art asset) — on-theme with the
# game's cursed-gift visuals (UiKit.POISON). A pulsing additive glow under a faceted gem.
func _make_amulet() -> Node2D:
	var root := Node2D.new()

	var glow := Polygon2D.new()
	glow.name = "glow"
	glow.polygon = _circle(74.0, 28)
	glow.color = Color(UiKit.POISON.r, UiKit.POISON.g, UiKit.POISON.b, 0.30)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	root.add_child(glow)

	# chain bail (a small ring on a short V) so it reads as an amulet, not just a gem
	var chain := Line2D.new()
	chain.points = PackedVector2Array([Vector2(-15, -56), Vector2(0, -42), Vector2(15, -56)])
	chain.width = 3.0
	chain.default_color = Color(0.78, 0.64, 0.98, 0.9)
	root.add_child(chain)
	var bail := Polygon2D.new()
	bail.polygon = _circle(7.0, 14)
	bail.position = Vector2(0, -62)
	bail.color = Color(0.72, 0.58, 0.96, 1.0)
	root.add_child(bail)

	var back := Polygon2D.new()                 # dark outline diamond
	back.polygon = _diamond(34.0, 46.0)
	back.color = Color(0.12, 0.04, 0.18, 1.0)
	root.add_child(back)
	var face := Polygon2D.new()                 # bright violet gem face
	face.polygon = _diamond(28.0, 40.0)
	face.color = Color(0.80, 0.55, 1.0, 1.0)
	root.add_child(face)
	var core := Polygon2D.new()                 # brighter inner core
	core.polygon = _diamond(13.0, 20.0)
	core.color = Color(0.97, 0.90, 1.0, 1.0)
	root.add_child(core)

	return root

func _start_pulse(glow: Node2D) -> void:
	if glow == null:
		return
	_pulse_tw = create_tween().set_loops()
	_pulse_tw.tween_property(glow, "scale", Vector2(1.2, 1.2), 0.9).set_trans(Tween.TRANS_SINE)
	_pulse_tw.tween_property(glow, "scale", Vector2(0.88, 0.88), 0.9).set_trans(Tween.TRANS_SINE)

static func _circle(r: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts

static func _diamond(hw: float, hh: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, -hh), Vector2(hw, 0), Vector2(0, hh), Vector2(-hw, 0)])

# ------------------------------------------------------------------ input / flow
func _input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_SPACE or k == KEY_ENTER or k == KEY_KP_ENTER:
			_advance()
		elif k == KEY_ESCAPE:
			_finish()                            # Esc skips the whole cutscene
		get_viewport().set_input_as_handled()    # swallow ALL keys while we're up
	elif event is InputEventMouseButton and event.pressed:
		_advance()
		get_viewport().set_input_as_handled()

func _advance() -> void:
	if _done or _busy:
		return
	# NOTE: the cutscene is now the FIRST in-canvas gesture. The web-audio unlock gate
	# (Sfx.unlock) is currently reverted out of the tree while audio is being debugged,
	# so we just click like intro.gd does. If Sfx.unlock() is restored, call it here too.
	Sfx.play("ui_click")
	if _i >= beats.size() - 1:
		_finish()
		return
	_busy = true
	var t := create_tween()
	t.tween_property(_content, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE)
	t.tween_callback(_next_beat)
	t.tween_property(_content, "modulate:a", 1.0, 0.34).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func() -> void: _busy = false)

func _next_beat() -> void:
	_show_beat(_i + 1)

func _finish() -> void:
	if _done:
		return
	_done = true
	if _pulse_tw:
		_pulse_tw.kill()
	if _pause_menu:
		_pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	# NOTE: we leave the tree paused — the receiver decides (opening hands off to the
	# still-paused intro; the victory hook unpauses before showing the end card).
	finished.emit()
	queue_free()
