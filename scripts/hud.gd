extends CanvasLayer
class_name HUD
## All on-screen UI, built as a Control-node tree and skinned with the Franuka RPG
## UI pack (assets/ui/franuka) + its pixel font. The SUSPICION meter is the loud,
## unmistakable centerpiece, and an ABILITY BAR shows every action (Space/Ctrl/E/Q)
## with its keycap and a radial cooldown sweep.
##
## Public API is UNCHANGED so game.gd / events.gd call sites don't move:
##   announce(), princess_say(), squire_say(), big_flash(), betray(),
##   show_end(), update_state().

const UI := "res://assets/ui/franuka/"
const FONT_TEXT := UI + "fonts/FantasyRPGtext (size 8).ttf"
const FONT_TITLE := UI + "fonts/FantasyRPGtitle (size 11).ttf"
const SLOT_TEX := UI + "slots/Slot_01_Empty.png"
const ABILITY_SLOT := 84.0       # ability bar slot size (px); radial veil is sized to match

# --- bottom-centre CONSOLE --------------------------------------------------
# Everything that used to live in the four corners + top-centre is now one
# console pinned to the bottom-centre (where the ability bar already sat). It
# reads as a SINGLE unit: one dark framed tray, internal compartments split by
# subtle dividers (no more clashing per-box borders), and every orb/slot sharing
# one baseline. The tray's own border is what flares red as Suspicion climbs.
# Layout (local coords inside the dock, y=0 at its top):
#   • SUSPICION  = a full-width meter across the top (the loud centerpiece),
#     then a divider line.
#   • a baseline-aligned row beneath, left→right, divider-separated:
#       SQUIRE vitals │ PRINCESS │ ability bar │ CARRYING slot.
const DOCK_W := 1026.0
const DOCK_H := 220.0
const PAD := 16.0                # inner padding inside the tray frame
const BASELINE := 192.0          # shared bottom edge of every row orb / slot
const HEADER_Y := 102.0          # cluster caption band (SQUIRE / PRINCESS / CARRY)
const X_SQUIRE := 16.0           # two 64px orbs at 16 and 88
const X_PRINCESS := 208.0        # crowned 64px orb, text to its right
const X_ABILITIES := 514.0       # 4*84 + 3*12 = 372 wide
const X_CARRY := 916.0           # one 84px slot, centred in its compartment

# Ability bar: id drives the cooldown/availability wiring in update_state().
# icon = a Franuka mini-icon so each slot reads at a glance.
const ABILITIES := [
	{"id": "dash",   "key": "SPACE", "name": "Dash",    "icon": "res://assets/ui/franuka/icons/Icon_11.png"},
	{"id": "tamper", "key": "CTRL",  "name": "Tamper",  "icon": "res://assets/ui/franuka/icons/Icon_17.png"},
	{"id": "tip",    "key": "E",     "name": "Tip-off", "icon": "res://assets/ui/franuka/icons/Icon_07.png"},
	{"id": "scheme", "key": "Q",     "name": "Scheme",  "icon": "res://assets/ui/franuka/icons/Icon_13.png"},
]

# --- fonts / generated textures ---
var _font: Font
var _font_title: Font
var _white: Texture2D            # 1px white, stretched for the radial cooldown bars

# --- roots ---
var _root: Control
var _dock: Control                # bottom-centre console that holds every gauge
var _dock_sb: StyleBoxFlat        # the tray's frame; its border flares red with Suspicion

# --- suspicion (focal point) ---
var _sus_bar: ProgressBar
var _sus_fill: StyleBoxFlat       # fill colour (green -> red)
var _sus_pct: Label
var _sus_legend: Label
var _boss_banner: Label           # replaces the meter in the boss phase
var _sus_floor_marker: ColorRect  # tick marking the doubt floor — suspicion can't be calmed below it
# rotating fourth-wall asides shown under the meter while she's calm/doubtful
const LEGEND_SWAP := 5.5          # seconds each witty line lingers before the next
var _legend_t := 0.0              # counts down to the next swap
var _legend_line := ""            # the line currently shown (picked from Lines.META_LEGEND)

# --- run info (top-left WAVE + SCORE readout) ---
var _run_info: Label

# --- princess ---
var _pr_title: Label
var _pr_orb: Dictionary           # crowned red HP orb (liquid clip-reveals bottom→top)
var _pr_hp: Label
var _pr_notes: Label

# --- squire ---
var _sq_hp_orb: Dictionary        # red HP orb (steps in quarters = hits left)
var _sq_stam_orb: Dictionary      # blue stamina orb
var _carry_slot: TextureRect
var _carry_label: Label

# --- ability bar ---
var _slots := {}                  # id -> { cd_bar, cd_label, dim, key_panel, name_label, cd_max }

# --- transient banners ---
var _announce: Label
var _big: Label
var _betray_root: Control
var _betray_vignette: ColorRect
var _betray_title: Label
var _betray_sub: Label
var _end_root: Control
var _end_title: Label
var _end_sub: Label
var _end_stats: Label
var _end_restart: Label

# cached Franuka textures (carry slot variants + HP hearts)
var _slot_empty: Texture2D
var _slot_potion: Texture2D
var _slot_weapon: Texture2D

func _ready() -> void:
	layer = 10
	# Clean, readable font (the Franuka pixel font is too hard to read at HUD sizes).
	_font = UiKit.font_text()
	_font_title = UiKit.font_title()
	_white = _make_white(int(ABILITY_SLOT))
	_slot_empty = UiKit.tex(UiKit.SLOT)
	_slot_potion = UiKit.tex(UiKit.SLOT_POTION)
	_slot_weapon = UiKit.tex(UiKit.SLOT_WEAPON)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # crisp pixel art (children inherit)
	add_child(_root)

	# The dock pins the whole gauge cluster to the bottom-centre; everything below
	# is positioned with offsets *local* to it, so the group moves/centres as one.
	_dock = Control.new()
	_dock.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dock.offset_left = -DOCK_W * 0.5
	_dock.offset_right = DOCK_W * 0.5
	_dock.offset_top = -8.0 - DOCK_H
	_dock.offset_bottom = -8.0
	_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dock)

	_build_dock_bg()       # the tray frame — first, so every gauge sits on top of it
	_build_suspicion()
	_build_princess()
	_build_squire()
	_build_ability_bar()
	_build_carry()
	_build_dividers()      # subtle compartment separators (after content, drawn over the gap)
	_build_runinfo()
	_build_banners()
	_build_end()

# ============================================================ build helpers

func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		return load(path)
	return ThemeDB.fallback_font

## A solid white square. The radial cooldown bars draw it at native size, so it
## must be the slot size for the dark "clock wipe" to actually cover the slot.
func _make_white(size: int) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)

func _label(text: String, size: int, color: Color, title := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font_title if title else _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", maxi(2, size / 8))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _panel(bg: Color, border: Color, border_w := 2.0, radius := 6) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(int(border_w))
	sb.border_color = border
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

## A clean, precise-colour progress bar (StyleBox themed). Returns the bar; the
## caller keeps the returned fill StyleBox to recolour it later.
func _bar(fill_col: Color) -> Array:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 1.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.04, 0.04, 0.06, 0.85)
	bg.set_corner_radius_all(4)
	bg.set_border_width_all(2)
	bg.border_color = Color(0, 0, 0, 0.65)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_col
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return [bar, fill]

## A Franuka liquid ORB gauge that fills bottom→top. Built by hand (TextureProgressBar
## won't do a clean linear vertical reveal with these round sphere textures): a dark
## socket+ring (ORB_EMPTY) under a clipped liquid sphere whose level rises with value.
## At value 1 it equals the shipped framed orb (socket + full liquid). Returns a dict
## of the parts — position with _place_orb(), drive with _orb_set(), add ["cell"].
func _orb(fill_path: String, diameter: float) -> Dictionary:
	var cell := Control.new()
	cell.custom_minimum_size = Vector2(diameter, diameter)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var socket := TextureRect.new()
	socket.texture = UiKit.tex(UiKit.ORB_EMPTY)
	socket.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	socket.stretch_mode = TextureRect.STRETCH_SCALE
	socket.offset_right = diameter
	socket.offset_bottom = diameter
	socket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(socket)

	# clip window (a bottom strip whose height == fill) reveals part of the liquid
	var clip := Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(clip)

	var liquid := TextureRect.new()
	liquid.texture = UiKit.tex(fill_path)
	liquid.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	liquid.stretch_mode = TextureRect.STRETCH_SCALE
	liquid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(liquid)

	var orb := {"cell": cell, "clip": clip, "liquid": liquid, "diam": diameter}
	_orb_set(orb, 1.0)
	return orb

## Sets an orb's fill (0..1): the clip strip rises from the bottom while the liquid
## sphere stays pinned to the cell, so only its lower `value` portion shows.
func _orb_set(orb: Dictionary, value: float) -> void:
	var d: float = orb["diam"]
	var h: float = d * clampf(value, 0.0, 1.0)
	var clip: Control = orb["clip"]
	var liquid: TextureRect = orb["liquid"]
	clip.offset_left = 0
	clip.offset_right = d
	clip.offset_top = d - h
	clip.offset_bottom = d
	liquid.offset_left = 0
	liquid.offset_right = d
	liquid.offset_top = -(d - h)   # keep the sphere fixed in cell space
	liquid.offset_bottom = h

## Positions an orb's cell at (x, y) within its parent (offsets in on-screen px).
func _place_orb(orb: Dictionary, x: float, y: float) -> void:
	var cell: Control = orb["cell"]
	var d: float = orb["diam"]
	cell.offset_left = x
	cell.offset_top = y
	cell.offset_right = x + d
	cell.offset_bottom = y + d

# ---------------------------------------------------------------- TRAY FRAME
# One dark, warm-bordered tray behind the whole console so every gauge reads as a
# single unit instead of separate floating boxes. The border is bronze at rest
# and flares toward red as Suspicion climbs (driven in update_state).
func _build_dock_bg() -> void:
	var bg := Panel.new()
	_dock_sb = StyleBoxFlat.new()
	_dock_sb.bg_color = Color(0.09, 0.07, 0.10, 0.93)
	_dock_sb.set_border_width_all(3)
	_dock_sb.border_color = Color(0.64, 0.47, 0.30, 0.95)   # warm bronze
	_dock_sb.set_corner_radius_all(12)
	_dock_sb.shadow_color = Color(0, 0, 0, 0.5)
	_dock_sb.shadow_size = 10
	bg.add_theme_stylebox_override("panel", _dock_sb)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock.add_child(bg)

# ---------------------------------------------------------------- SUSPICION
# The loud centerpiece: a full-width meter across the top of the console (no box
# of its own — it's part of the tray). Fill runs green→red; the tray border flares.
func _build_suspicion() -> void:
	var inner_r := DOCK_W - PAD

	var skull := UiKit.icon(UiKit.IC_SKULL, 28)
	skull.offset_left = PAD + 2
	skull.offset_top = 12
	skull.offset_right = PAD + 30
	skull.offset_bottom = 40
	_dock.add_child(skull)

	var title := _label("SUSPICION", 26, Color(1.0, 0.86, 0.5), true)
	title.offset_left = PAD + 40
	title.offset_top = 10
	title.offset_right = inner_r
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_dock.add_child(title)

	_sus_pct = _label("0%", 26, Color.WHITE, true)
	_sus_pct.offset_left = inner_r - 140
	_sus_pct.offset_right = inner_r
	_sus_pct.offset_top = 10
	_sus_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_dock.add_child(_sus_pct)

	var made := _bar(Color(0.35, 0.85, 0.45))
	_sus_bar = made[0]
	_sus_fill = made[1]
	_sus_bar.offset_left = PAD
	_sus_bar.offset_right = inner_r
	_sus_bar.offset_top = 44
	_sus_bar.offset_bottom = 64
	_dock.add_child(_sus_bar)

	# Doubt-floor tick on the meter: the minimum your treachery has permanently worn her
	# trust down to — suspicion can never be calmed below it. Positioned live in update_state.
	_sus_floor_marker = ColorRect.new()
	_sus_floor_marker.color = Color(1.0, 0.32, 0.32, 0.9)
	_sus_floor_marker.anchor_top = 0.0
	_sus_floor_marker.anchor_bottom = 1.0
	_sus_floor_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sus_floor_marker.visible = false
	_sus_bar.add_child(_sus_floor_marker)

	_legend_line = Lines.pick(Lines.META_LEGEND)
	_sus_legend = _label(_legend_line, 15, Color(1, 1, 1, 0.8))
	_sus_legend.offset_left = PAD
	_sus_legend.offset_right = inner_r
	_sus_legend.offset_top = 66
	_sus_legend.offset_bottom = 86
	_sus_legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dock.add_child(_sus_legend)

	_boss_banner = _label("BRING HER DOWN", 30, Color(1.0, 0.35, 0.4), true)
	_boss_banner.offset_left = PAD
	_boss_banner.offset_right = inner_r
	_boss_banner.offset_top = 20
	_boss_banner.offset_bottom = 64
	_boss_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_banner.visible = false
	_dock.add_child(_boss_banner)

# ---------------------------------------------------------------- PRINCESS
# Second compartment: a crowned red HP orb (the boss you're sizing up) sharing the
# row baseline, with her level / HP / status in a text column to the right. The
# crown badge marks it as royalty so it never reads as your own HP orb.
func _build_princess() -> void:
	var oy := BASELINE - 64.0
	_pr_orb = _orb(UiKit.ORB_HP, 64.0)
	_place_orb(_pr_orb, X_PRINCESS, oy)
	_dock.add_child(_pr_orb["cell"])

	# crown badge perched on the orb so the boss reads as royalty at a glance
	var crown := UiKit.icon(UiKit.IC_CROWN, 28)
	crown.offset_left = X_PRINCESS + 20
	crown.offset_top = oy - 14.0
	crown.offset_right = X_PRINCESS + 48
	crown.offset_bottom = oy + 14.0
	_dock.add_child(crown)

	var tx := X_PRINCESS + 76.0    # text column, right of the orb
	var tr := 480.0                # stops short of the divider
	_pr_title = _label("PRINCESS  Lv.1", 18, Color(1.0, 0.6, 0.8), true)
	_pr_title.offset_left = tx
	_pr_title.offset_top = 124
	_pr_title.offset_right = tr
	_dock.add_child(_pr_title)

	_pr_hp = _label("0 / 0", 16, Color(1, 1, 1, 0.98))
	_pr_hp.offset_left = tx
	_pr_hp.offset_top = 150
	_pr_hp.offset_right = tr
	_pr_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_dock.add_child(_pr_hp)

	_pr_notes = _label("", 14, Color(0.7, 1.0, 0.6))
	_pr_notes.offset_left = tx
	_pr_notes.offset_top = 174
	_pr_notes.offset_right = tr
	_dock.add_child(_pr_notes)

# ---------------------------------------------------------------- SQUIRE
# First compartment: your vitals as two liquid orbs sharing the row baseline —
# red HP (steps in quarters, one per hit, so the fill IS your hits-left) and a
# blue stamina orb that drains/refills live. Captions under each, header above.
func _build_squire() -> void:
	var title := _label("SQUIRE  (you)", 18, Color(0.7, 1.0, 0.72), true)
	title.offset_left = X_SQUIRE - 8
	title.offset_right = X_SQUIRE + 160
	title.offset_top = HEADER_Y
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dock.add_child(title)

	var oy := BASELINE - 64.0
	_sq_hp_orb = _orb(UiKit.ORB_HP, 64.0)
	_place_orb(_sq_hp_orb, X_SQUIRE, oy)
	_dock.add_child(_sq_hp_orb["cell"])
	var hp_lbl := _label("HP", 14, Color(1, 1, 1, 0.9))
	hp_lbl.offset_left = X_SQUIRE - 16
	hp_lbl.offset_right = X_SQUIRE + 80
	hp_lbl.offset_top = BASELINE + 2
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dock.add_child(hp_lbl)

	_sq_stam_orb = _orb(UiKit.ORB_MP, 64.0)
	_place_orb(_sq_stam_orb, X_SQUIRE + 72.0, oy)
	_dock.add_child(_sq_stam_orb["cell"])
	var st_lbl := _label("STAMINA", 14, Color(1, 1, 1, 0.9))
	st_lbl.offset_left = X_SQUIRE + 56
	st_lbl.offset_right = X_SQUIRE + 152
	st_lbl.offset_top = BASELINE + 2
	st_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dock.add_child(st_lbl)

# ---------------------------------------------------------------- CARRYING
# Last compartment: a single item slot matching the ability slots in size +
# baseline, a "CARRY" header in the caption band, and the item name beneath it.
func _build_carry() -> void:
	var slot := ABILITY_SLOT
	var mid := X_CARRY + slot * 0.5

	_carry_slot = TextureRect.new()
	if ResourceLoader.exists(SLOT_TEX):
		_carry_slot.texture = load(SLOT_TEX)
	_carry_slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_carry_slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_carry_slot.offset_left = X_CARRY
	_carry_slot.offset_right = X_CARRY + slot
	_carry_slot.offset_top = BASELINE - slot
	_carry_slot.offset_bottom = BASELINE
	_carry_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock.add_child(_carry_slot)

	# item caption under the slot (allowed to overflow the slot width so "[CURSED]" fits)
	_carry_label = _label("—", 14, Color(1, 1, 1, 0.7))
	_carry_label.offset_left = mid - 88
	_carry_label.offset_right = mid + 88
	_carry_label.offset_top = BASELINE + 2
	_carry_label.offset_bottom = BASELINE + 22
	_carry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_carry_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dock.add_child(_carry_label)

# ---------------------------------------------------------------- ABILITY BAR
func _build_ability_bar() -> void:
	var slot := ABILITY_SLOT
	var gap := 12.0
	var n := ABILITIES.size()
	var total := n * slot + (n - 1) * gap

	# Third compartment. Cells are positioned from the bar's top-left; the slot is
	# the cell's 0..slot band, so anchoring the bar top at BASELINE-slot lands every
	# slot bottom on the shared row baseline (keycaps sit just above, names just below).
	var bar := Control.new()
	bar.offset_left = X_ABILITIES
	bar.offset_right = X_ABILITIES + total
	bar.offset_top = BASELINE - slot
	bar.offset_bottom = BASELINE - slot + (slot + 18.0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock.add_child(bar)

	var slot_tex: Texture2D = load(SLOT_TEX) if ResourceLoader.exists(SLOT_TEX) else null
	var x := 0.0
	for a in ABILITIES:
		var cell := Control.new()
		cell.offset_left = x
		cell.offset_right = x + slot
		cell.offset_top = 0
		cell.offset_bottom = slot + 18
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(cell)

		# slot frame
		var frame := TextureRect.new()
		if slot_tex:
			frame.texture = slot_tex
		else:
			# fallback: a styled box so the bar still reads without the asset
			var fp := _panel(Color(0.12, 0.10, 0.08, 0.85), Color(0.7, 0.55, 0.35, 0.9))
			fp.set_anchors_preset(Control.PRESET_FULL_RECT)
			fp.offset_bottom = -18
			cell.add_child(fp)
		frame.custom_minimum_size = Vector2(slot, slot)
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		frame.size = Vector2(slot, slot)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(frame)

		# labelled icon (boot/flask/alert/wand) so the slot reads at a glance
		var ic := UiKit.icon(a["icon"], slot * 0.5)
		ic.offset_left = slot * 0.25
		ic.offset_top = slot * 0.27
		ic.offset_right = slot * 0.75
		ic.offset_bottom = slot * 0.77
		cell.add_child(ic)

		# ability name (under the slot)
		var name_lbl := _label(a["name"], 16, Color(1, 1, 1, 0.95))
		name_lbl.anchor_left = 0.0
		name_lbl.anchor_right = 1.0
		name_lbl.offset_top = slot - 2
		name_lbl.offset_bottom = slot + 18
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(name_lbl)

		# keycap (top-centre, a clean styled cap with the key text)
		var key_panel := _panel(Color(0.92, 0.90, 0.82, 0.95), Color(0.25, 0.2, 0.15, 1.0), 2.0, 4)
		var kw: float = 30.0 if a["key"].length() <= 1 else 14.0 + a["key"].length() * 9.0
		key_panel.anchor_left = 0.5
		key_panel.anchor_right = 0.5
		key_panel.offset_left = -kw * 0.5
		key_panel.offset_right = kw * 0.5
		key_panel.offset_top = -12
		key_panel.offset_bottom = 16
		cell.add_child(key_panel)
		var key_lbl := _label(a["key"], 15, Color(0.15, 0.12, 0.1), true)
		key_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		key_panel.add_child(key_lbl)

		# radial cooldown sweep (dark veil over the slot, shrinks as it readies)
		var cd_bar := TextureProgressBar.new()
		cd_bar.texture_progress = _white
		cd_bar.fill_mode = TextureProgressBar.FILL_COUNTER_CLOCKWISE
		cd_bar.tint_progress = Color(0.03, 0.03, 0.05, 0.8)
		cd_bar.min_value = 0.0
		cd_bar.max_value = 1.0
		cd_bar.value = 0.0
		cd_bar.offset_right = slot
		cd_bar.offset_bottom = slot
		cd_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(cd_bar)

		# countdown number (over the veil)
		var cd_lbl := _label("", 24, Color.WHITE, true)
		cd_lbl.offset_right = slot
		cd_lbl.offset_bottom = slot
		cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cd_lbl.visible = false
		cell.add_child(cd_lbl)

		# "unavailable" dim veil (gated abilities: no stamina / not carrying)
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.5)
		dim.offset_right = slot
		dim.offset_bottom = slot
		dim.visible = false
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(dim)

		var cd_max := 1.0
		if a["id"] == "tip":
			cd_max = Squire.TIP_CD
		elif a["id"] == "scheme":
			cd_max = EventDirector.SCHEME_CD
		_slots[a["id"]] = {
			"cd_bar": cd_bar, "cd_label": cd_lbl, "dim": dim, "cd_max": cd_max,
		}
		x += slot + gap

# ---------------------------------------------------------------- DIVIDERS
# Subtle separators so the four clusters read as compartments of ONE console
# instead of separate boxes: a horizontal line under Suspicion + three verticals
# between the row clusters. Faint + warm so they echo the tray border.
func _build_dividers() -> void:
	var col := Color(0.5, 0.38, 0.28, 0.45)
	_line(PAD, 90.0, DOCK_W - PAD * 2.0, 2.0, col)        # under the suspicion meter
	for vx in [188.0, 494.0, 906.0]:
		_line(vx, 100.0, 2.0, 112.0, col)                # between SQUIRE│PRINCESS│abilities│CARRY

func _line(x: float, y: float, w: float, h: float, col: Color) -> void:
	var r := ColorRect.new()
	r.color = col
	r.offset_left = x
	r.offset_top = y
	r.offset_right = x + w
	r.offset_bottom = y + h
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock.add_child(r)

# ---------------------------------------------------------------- RUN INFO
# A quiet top-left readout of the two run-defining numbers (no box, just outlined
# text) so "what wave am I on / how am I scoring" is always answerable mid-run.
# Current-run only — resets with R like everything else.
func _build_runinfo() -> void:
	_run_info = _label("WAVE 1     SCORE 0", 20, Color(1.0, 0.93, 0.7), true)
	_run_info.offset_left = 18
	_run_info.offset_top = 12
	_run_info.offset_right = 380
	_run_info.offset_bottom = 40
	_run_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_run_info.modulate.a = 0.92
	_root.add_child(_run_info)

# ---------------------------------------------------------------- BANNERS
func _build_banners() -> void:
	_announce = _label("", 34, Color.WHITE, true)
	_announce.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_announce.offset_top = 120
	_announce.offset_bottom = 170
	_announce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce.modulate.a = 0.0
	_root.add_child(_announce)

	_big = _label("", 96, Color(1.0, 0.85, 0.25), true)
	_big.set_anchors_preset(Control.PRESET_CENTER)
	_big.offset_left = -600
	_big.offset_right = 600
	_big.offset_top = -80
	_big.offset_bottom = 80
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_big.modulate.a = 0.0
	_root.add_child(_big)

	_betray_root = Control.new()
	_betray_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_betray_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_betray_root.visible = false
	_root.add_child(_betray_root)
	_betray_vignette = ColorRect.new()
	_betray_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_betray_vignette.color = Color(0.6, 0.0, 0.05, 0.0)
	_betray_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_betray_root.add_child(_betray_vignette)
	_betray_title = _label("SHE KNOWS.", 72, Color(1.0, 0.2, 0.25), true)
	_betray_title.set_anchors_preset(Control.PRESET_CENTER)
	_betray_title.offset_left = -600
	_betray_title.offset_right = 600
	_betray_title.offset_top = -90
	_betray_title.offset_bottom = -10
	_betray_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_betray_root.add_child(_betray_title)
	_betray_sub = _label("The monsters rally to your side — bring her down!", 24, Color.WHITE, true)
	_betray_sub.set_anchors_preset(Control.PRESET_CENTER)
	_betray_sub.offset_left = -600
	_betray_sub.offset_right = 600
	_betray_sub.offset_top = 6
	_betray_sub.offset_bottom = 50
	_betray_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_betray_root.add_child(_betray_sub)

# ---------------------------------------------------------------- END SCREEN
func _build_end() -> void:
	_end_root = Control.new()
	_end_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_root.visible = false
	_root.add_child(_end_root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_root.add_child(dim)
	# framed card so the result reads as a deliberate screen, not floating text
	var card := _panel(Color(0.08, 0.06, 0.09, 0.94), UiKit.GOLD, 3.0, 14)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -480
	card.offset_right = 480
	card.offset_top = -150
	card.offset_bottom = 175
	_end_root.add_child(card)
	_end_title = _label("", 64, Color.WHITE, true)
	_end_title.set_anchors_preset(Control.PRESET_CENTER)
	_end_title.offset_left = -700
	_end_title.offset_right = 700
	_end_title.offset_top = -110
	_end_title.offset_bottom = -40
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_root.add_child(_end_title)
	_end_sub = _label("", 26, Color.WHITE, true)
	_end_sub.set_anchors_preset(Control.PRESET_CENTER)
	_end_sub.offset_left = -700
	_end_sub.offset_right = 700
	_end_sub.offset_top = -24
	_end_sub.offset_bottom = 16
	_end_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_root.add_child(_end_sub)
	_end_stats = _label("", 26, Color(1.0, 0.95, 0.72), true)
	_end_stats.set_anchors_preset(Control.PRESET_CENTER)
	_end_stats.offset_left = -700
	_end_stats.offset_right = 700
	_end_stats.offset_top = 36
	_end_stats.offset_bottom = 72
	_end_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_root.add_child(_end_stats)
	_end_restart = _label("Press R to scheme again", 22, Color(1.0, 0.85, 0.4), true)
	_end_restart.set_anchors_preset(Control.PRESET_CENTER)
	_end_restart.offset_left = -700
	_end_restart.offset_right = 700
	_end_restart.offset_top = 92
	_end_restart.offset_bottom = 124
	_end_restart.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_root.add_child(_end_restart)

# ============================================================ public API

func announce(text: String) -> void:
	_announce.text = text
	_announce.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.3)
	tw.tween_property(_announce, "modulate:a", 0.0, 0.9)

## Dialogue floats above whoever says it (Actor.say), so it reads as coming from
## the character instead of a banner.
func princess_say(text: String) -> void:
	var pr := get_tree().get_first_node_in_group("princess") as Actor
	if pr:
		pr.say(text, Color(1.0, 0.82, 0.9))

func squire_say(text: String) -> void:
	var sq := get_tree().get_first_node_in_group("squire") as Actor
	if sq:
		sq.say(text, Color(0.7, 1.0, 0.72))

func big_flash(text: String) -> void:
	_big.text = text
	_big.modulate.a = 1.0
	_big.scale = Vector2.ONE
	_big.pivot_offset = _big.size * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_big, "scale", Vector2(1.4, 1.4), 1.6)
	tw.tween_property(_big, "modulate:a", 0.0, 1.6).set_trans(Tween.TRANS_QUAD)

func betray() -> void:
	_betray_root.visible = true
	_betray_title.modulate.a = 0.0
	_betray_title.scale = Vector2(1.6, 1.6)
	_betray_title.pivot_offset = _betray_title.size * 0.5
	_betray_sub.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_betray_vignette, "color:a", 0.55, 0.12)
	tw.tween_property(_betray_title, "modulate:a", 1.0, 0.25)
	tw.tween_property(_betray_title, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(_betray_sub, "modulate:a", 1.0, 0.3)
	tw.chain().tween_interval(1.6)
	tw.chain().set_parallel(true)
	tw.tween_property(_betray_vignette, "color:a", 0.0, 0.8)
	tw.tween_property(_betray_title, "modulate:a", 0.0, 0.8)
	tw.tween_property(_betray_sub, "modulate:a", 0.0, 0.8)

## cause: "queen" (the Princess executed you, in the boss fight), "" / anything else
## (a pointless death — monsters, your own chaos, a stray trap).
func show_end(won: bool, final_score: int, final_wave: int, cause := "") -> void:
	if won:
		_end_title.text = "LONG LIVE THE SQUIRE"
		_end_title.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
		_end_sub.text = "The Princess is dead. The throne is yours."
	elif cause == "queen":
		_end_title.text = "EXECUTED FOR TREASON"
		_end_title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.35))
		_end_sub.text = "The Princess got her revenge. You should have been more careful, squire."
	else:
		_end_title.text = "A POINTLESS DEATH"
		_end_title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
		_end_sub.text = Lines.pick(Lines.POINTLESS_DEATH) if Lines.POINTLESS_DEATH.size() > 0 else "Not even the Princess noticed."
	_end_stats.text = "Reached wave %d  ·  Score %d" % [final_wave, final_score]
	_end_root.visible = true
	_end_title.modulate.a = 0.0
	_end_title.scale = Vector2(1.5, 1.5)
	_end_title.pivot_offset = _end_title.size * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_end_title, "modulate:a", 1.0, 0.35)
	tw.tween_property(_end_title, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# gentle pulse on the restart prompt
	var pt := create_tween().set_loops()
	pt.tween_property(_end_restart, "modulate:a", 0.4, 0.7)
	pt.tween_property(_end_restart, "modulate:a", 1.0, 0.7)

func update_state(game: Game) -> void:
	var ratio: float = clampf(game.suspicion / Game.SUSPICION_MAX, 0.0, 1.0)
	var boss := game.phase == "boss"

	if _run_info:
		_run_info.text = "WAVE %d     SCORE %d" % [game.wave, game.score]

	# suspicion / boss banner
	_sus_bar.visible = not boss
	_sus_pct.visible = not boss
	_sus_legend.visible = not boss
	_boss_banner.visible = boss
	if not boss:
		_sus_bar.value = ratio
		_sus_pct.text = "%d%%" % int(round(ratio * 100.0))
		_sus_fill.bg_color = Color(0.35, 0.85, 0.45).lerp(Color(1.0, 0.2, 0.2), ratio)
		# the whole console flares as she closes in — the tray border heats up
		var hot: float = clampf((ratio - 0.45) / 0.55, 0.0, 1.0)
		_dock_sb.border_color = Color(0.64, 0.47, 0.30, 0.95).lerp(Color(1.0, 0.15, 0.2, 1.0), hot)
		_dock_sb.set_border_width_all(int(round(3.0 + hot * 5.0)))
		# doubt-floor tick: the un-calmable minimum, anchored so it tracks any bar width
		var floor_ratio: float = clampf(game.doubt_floor / Game.SUSPICION_MAX, 0.0, 1.0)
		_sus_floor_marker.visible = floor_ratio > 0.01
		_sus_floor_marker.anchor_left = floor_ratio
		_sus_floor_marker.anchor_right = floor_ratio
		_sus_floor_marker.offset_left = -2.0
		_sus_floor_marker.offset_right = 2.0
		# legend reframed by stage. While she's still oblivious/doubtful the squire
		# breaks the fourth wall at you (lines rotate on a timer); once her attacks can
		# actually catch you it snaps back to a straight, useful danger warning.
		_legend_t -= get_process_delta_time()
		if _legend_t <= 0.0:
			_legend_line = Lines.pick(Lines.META_LEGEND)
			_legend_t = LEGEND_SWAP
		match game.suspicion_stage():
			Game.Stage.OBLIVIOUS, Game.Stage.DOUBT:
				_sus_legend.text = _legend_line
			Game.Stage.FRIENDLY_FIRE:
				_sus_legend.text = "DANGER — her attacks can hit you now"
			_:
				_sus_legend.text = "SHE'S ONTO YOU"

	# princess
	var pr := game.princess
	if pr:
		_pr_title.text = "PRINCESS — FINAL BOSS" if pr.hostile else "PRINCESS  Lv.%d" % pr.level
		_pr_title.add_theme_color_override("font_color", Color(1.0, 0.35, 0.4) if pr.hostile else Color(1.0, 0.6, 0.8))
		var pmax: float = maxf(1.0, pr._eff_max_hp())
		_orb_set(_pr_orb, pr.hp / pmax)
		# deepen the liquid to an angrier red once she turns on you (boss phase)
		_pr_orb["liquid"].modulate = Color(1.0, 0.62, 0.62) if pr.hostile else Color.WHITE
		_pr_hp.text = "%d / %d" % [int(pr.hp), int(pmax)]
		var notes := PackedStringArray()
		if pr.power_mult < 0.999:
			notes.append("ATK %d%%" % int(round(pr.power_mult * 100.0)))
		if pr.poison_dps > 0.0:
			notes.append("POISONED")
		_pr_notes.text = "  ·  ".join(notes)

	# squire
	var sq := game.squire
	if sq:
		# HP orb steps in quarters so the fill height == hits remaining (4 → die).
		var pip := Squire.MAX_HP / float(Squire.MAX_HITS)
		var left: int = clampi(int(round(sq.hp / pip)), 0, Squire.MAX_HITS)
		_orb_set(_sq_hp_orb, left / float(Squire.MAX_HITS))
		_sq_hp_orb["liquid"].modulate = Color(1.0, 0.55, 0.55) if left <= 1 else Color.WHITE
		_orb_set(_sq_stam_orb, sq.stamina / Squire.MAX_STAMINA)
		if sq.carry == "":
			_carry_label.text = "—"
			_carry_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
			_carry_slot.texture = _slot_empty
			_carry_slot.modulate = Color(1, 1, 1, 0.55)
		else:
			# item name fits the compartment; cursed/genuine is shown by colour (and the
			# slot's purple tint), so the long "[CURSED]" word no longer overflows the tray.
			_carry_label.text = sq.carry.to_upper()
			_carry_label.add_theme_color_override("font_color", Color(0.85, 0.4, 1.0) if sq.cursed else Color(0.7, 1.0, 0.7))
			_carry_slot.texture = _slot_potion if sq.carry == "potion" else _slot_weapon
			_carry_slot.modulate = Color(0.9, 0.55, 1.0) if sq.cursed else Color(1, 1, 1, 1)

		# ability bar
		var ev := game.event_director
		var tip_cd: float = sq.tip_cd
		var scheme_cd: float = ev.scheme_cd_left() if ev else 0.0
		_set_slot("dash", 0.0, sq.stamina >= Squire.DASH_COST)
		_set_slot("tamper", 0.0, sq.carry != "")
		_set_slot("tip", tip_cd, tip_cd <= 0.0 and sq.stamina >= Squire.TIP_COST)
		_set_slot("scheme", scheme_cd, scheme_cd <= 0.0 and game.phase == "serving")

func _set_slot(id: String, cd: float, gate_ready: bool) -> void:
	var s = _slots.get(id)
	if s == null:
		return
	if cd > 0.0:
		s["cd_bar"].value = clampf(cd / s["cd_max"], 0.0, 1.0)
		s["cd_bar"].visible = true
		s["cd_label"].text = "%d" % int(ceil(cd))
		s["cd_label"].visible = true
		s["dim"].visible = false
	else:
		s["cd_bar"].visible = false
		s["cd_label"].visible = false
		s["dim"].visible = not gate_ready    # greyed when unusable (no stamina / not carrying)
