extends RefCounted
class_name UiKit
## Shared Franuka-skinned UI style — ONE source of truth so the HUD, pause menu,
## intro/briefing and end screen all match. Static helpers (no autoload), matching
## the project's static-factory idiom (Sfx / Lines / Anim). All texture loads are
## null-tolerant so the game still runs if the pack is absent.

const DIR := "res://assets/ui/franuka/"
const F_TITLE := DIR + "fonts/FantasyRPGtitle (size 11).ttf"
const F_TEXT := DIR + "fonts/FantasyRPGtext (size 8).ttf"

# --- palette ---
const INK := Color(0.17, 0.12, 0.10)          # dark text on parchment
const GOLD := Color(1.0, 0.84, 0.40)
const PUMPKIN := Color(1.0, 0.55, 0.22)
const BLOOD := Color(0.90, 0.24, 0.27)
const POISON := Color(0.74, 0.45, 1.0)
const GREEN := Color(0.62, 1.0, 0.66)
const PINK := Color(1.0, 0.62, 0.82)
const CYAN := Color(0.40, 0.82, 1.0)
const PANEL_DARK := Color(0.10, 0.08, 0.11, 0.85)   # translucent HUD panel bg
# HIGH-CONTRAST accents for text ON the light parchment panels (gold/green read poorly
# on parchment — use these dark, saturated variants instead).
const EMPH := Color(0.60, 0.13, 0.11)               # dark red — emphasis on parchment
const INK_GREEN := Color(0.14, 0.42, 0.16)          # readable "go" green on parchment
const INK_KEY := Color(0.45, 0.22, 0.04)            # dark amber — keycaps/keys on parchment

# --- panels / banners ---
const PANEL := DIR + "bgbox/BGbox_01A.png"          # clean parchment
const PANEL_BLUE := DIR + "bgbox/BGbox_01B.png"
const PANEL_ORNATE := DIR + "bgbox/BGbox_03A.png"   # gold-cornered (titles)
const BANNER := DIR + "banners/BannerMedium_01A.png"   # dark, gem ends (titles over arena)
const BANNER_SM := DIR + "banners/BannerSmall_01A.png"

# --- item slots (carry indicator swaps these directly) ---
const SLOT := DIR + "slots/Slot_01_Empty.png"
const SLOT_POTION := DIR + "slots/Slot_01_Potion.png"
const SLOT_WEAPON := DIR + "slots/Slot_01_Weapon.png"

# --- liquid orb gauges (144x144). ORB_EMPTY is the dark socket+ring under-layer;
#     each bare liquid sphere is the fill (a full orb = ORB_EMPTY + its liquid, which
#     is exactly how the shipped Orb_Frame_* framed orbs are composited). HP/stamina
#     are drawn as TextureProgressBars filling bottom→top — see HUD._orb(). ---
const ORB_EMPTY := DIR + "orbs/Orb_Frame_Empty.png"
const ORB_HP := DIR + "orbs/Orb_HP.png"          # red liquid
const ORB_MP := DIR + "orbs/Orb_MP.png"          # blue liquid (stamina)
const ORB_ENERGY := DIR + "orbs/Orb_Energy.png"  # gold liquid

# --- mini icons (see contact sheet: 03 heart, 04 empty heart, 06 skull,
#     07 alert, 09 sword, 11 boot, 13 wand, 17 flask) ---
const IC_HEART := DIR + "icons/Icon_03.png"
const IC_HEART_EMPTY := DIR + "icons/Icon_04.png"
const IC_SKULL := DIR + "icons/Icon_06.png"
const IC_ALERT := DIR + "icons/Icon_07.png"
const IC_SWORD := DIR + "icons/Icon_09.png"
const IC_BOOT := DIR + "icons/Icon_11.png"
const IC_WAND := DIR + "icons/Icon_13.png"
const IC_FLASK := DIR + "icons/Icon_17.png"
const IC_CROWN := DIR + "icons/Icon_05.png"

# --- buttons (each has _Normal/_Pressed/_Selected) ---
const BTN_GOLD := DIR + "buttons/Button_03A"     # primary
const BTN_TAN := DIR + "buttons/Button_01A"      # normal
const BTN_RED := DIR + "buttons/Button_02A"      # destructive
const BTN_BLUE := DIR + "buttons/Button_05A"     # secondary

# --- checkboxes / sliders ---
const CB_OFF := DIR + "checkboxes/Checkbox_01A_Off.png"
const CB_ON := DIR + "checkboxes/Checkbox_01A_On.png"
const BAR_BOX := DIR + "bars/Slider01_Box.png"
const BAR_KNOB := DIR + "bars/Slider01_Button.png"

# The Franuka pixel fonts are decorative and hard to read at UI sizes, so we use
# Godot's clean default font for ALL text (the pixel LOOK still comes from the
# frames/buttons/banners/icons). Flip USE_PIXEL_FONT to true to restore the pixel font.
const USE_PIXEL_FONT := false

static func font_title() -> Font:
	if USE_PIXEL_FONT and ResourceLoader.exists(F_TITLE):
		return load(F_TITLE)
	return ThemeDB.fallback_font

static func font_text() -> Font:
	if USE_PIXEL_FONT and ResourceLoader.exists(F_TEXT):
		return load(F_TEXT)
	return ThemeDB.fallback_font

static func tex(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null

# A label with the pixel font + a dark outline (reads on any background).
static func label(text: String, size: int, color := Color.WHITE, title := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_title() if title else font_text())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	# Outline by luminance: LIGHT text (on dark bg) gets a strong dark outline so it
	# pops; DARK text (ink on light parchment) gets NO outline so it stays crisp, not muddy.
	var lum := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	if lum > 0.5:
		l.add_theme_constant_override("outline_size", maxi(4, size / 5))
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	else:
		l.add_theme_constant_override("outline_size", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

# A PanelContainer skinned with a Franuka frame. UNLIKE nine(), this IS a layout
# container: it auto-sizes to its single child and insets it by `pad`. Use this for
# menu/panel backings that wrap content (nine() does NOT size to its children).
static func panel_container(path := PANEL, tex_margin := 26, pad := 34) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _sbt(path, tex_margin, pad, pad))
	return pc

# A 9-sliced texture frame (NinePatchRect) — tiles so pixel borders stay crisp.
# NOTE: NinePatchRect is NOT a Container; it will not size to children. For a
# content backing use panel_container() instead.
static func nine(path: String, margin := 28) -> NinePatchRect:
	var n := NinePatchRect.new()
	var t := tex(path)
	if t:
		n.texture = t
	n.patch_margin_left = margin
	n.patch_margin_right = margin
	n.patch_margin_top = margin
	n.patch_margin_bottom = margin
	n.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	n.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n

static func icon(path: String, size: float) -> TextureRect:
	var r := TextureRect.new()
	var t := tex(path)
	if t:
		r.texture = t
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

# A StyleBoxTexture from a Franuka frame, for theming Button/Panel.
static func _sbt(path: String, m := 26, cm_h := 30, cm_v := 16) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	var t := tex(path)
	if t:
		sb.texture = t
	sb.texture_margin_left = m
	sb.texture_margin_right = m
	sb.texture_margin_top = m
	sb.texture_margin_bottom = m
	sb.content_margin_left = cm_h
	sb.content_margin_right = cm_h
	sb.content_margin_top = cm_v
	sb.content_margin_bottom = cm_v
	return sb

# A Franuka-skinned button. `base` is one of the BTN_* prefixes.
static func button(text: String, base := BTN_TAN, font_size := 22, text_col := INK) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font_title())
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", text_col)
	b.add_theme_color_override("font_hover_color", text_col)
	b.add_theme_color_override("font_pressed_color", text_col)
	b.add_theme_color_override("font_focus_color", text_col)
	b.add_theme_constant_override("outline_size", 0)
	b.add_theme_stylebox_override("normal", _sbt(base + "_Normal.png"))
	b.add_theme_stylebox_override("hover", _sbt(base + "_Selected.png"))
	b.add_theme_stylebox_override("pressed", _sbt(base + "_Pressed.png"))
	b.add_theme_stylebox_override("focus", _sbt(base + "_Selected.png"))
	b.add_theme_stylebox_override("disabled", _sbt(base + "_Normal.png"))
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return b

# A labelled checkbox row (returns [HBoxContainer, CheckBox]). Caller wires `toggled`.
static func toggle(text: String, on: bool) -> Array:
	var cb := CheckBox.new()
	cb.button_pressed = on
	cb.text = text
	cb.add_theme_font_override("font", font_text())
	cb.add_theme_font_size_override("font_size", 18)
	# dark ink — these sit on the light parchment panels
	cb.add_theme_color_override("font_color", INK)
	cb.add_theme_color_override("font_hover_color", Color(0.0, 0.0, 0.0))
	cb.add_theme_color_override("font_pressed_color", INK)
	var off := _icon_box(CB_OFF)
	var ono := _icon_box(CB_ON)
	cb.add_theme_icon_override("unchecked", off)
	cb.add_theme_icon_override("checked", ono)
	cb.add_theme_icon_override("unchecked_disabled", off)
	cb.add_theme_icon_override("checked_disabled", ono)
	cb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return [cb, cb]

static func _icon_box(path: String) -> Texture2D:
	return tex(path)

# A clean section header for use ON parchment: centred dark heading + a solid
# divider line. Avoids the stretched-banner / broken-9-slice look on thin strips.
static func section_header(text: String, size := 22) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(text, size, INK_KEY, false)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(l)
	var line := ColorRect.new()
	line.color = Color(0.42, 0.26, 0.16, 0.7)
	line.custom_minimum_size = Vector2(0, 3)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(line)
	return v

# A solid divider line (no NinePatch — avoids broken tiling on thin strips).
static func divider() -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(0.42, 0.26, 0.16, 0.6)
	line.custom_minimum_size = Vector2(0, 3)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line

# A dark title banner with centred gold text — sits nicely atop a parchment panel.
static func title_banner(text: String, font_size := 30) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size = Vector2(0, 88)   # banner art is 144x96; keep near-native height so it never squishes
	var b := nine(BANNER, 22)
	b.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(b)
	var l := label(text, font_size, GOLD, true)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c.add_child(l)
	return c

# A Franuka-skinned HSlider (parchment track + knob, gold fill).
static func slider(value: float, mn := 0.0, mx := 1.0, step := 0.05) -> HSlider:
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(220, 28)
	s.add_theme_stylebox_override("slider", _sbt(BAR_BOX, 10, 6, 6))
	var area := StyleBoxFlat.new()
	area.bg_color = GOLD
	area.set_corner_radius_all(3)
	s.add_theme_stylebox_override("grabber_area", area)
	s.add_theme_stylebox_override("grabber_area_highlight", area)
	var knob := tex(BAR_KNOB)
	if knob:
		s.add_theme_icon_override("grabber", knob)
		s.add_theme_icon_override("grabber_highlight", knob)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return s
