extends CanvasLayer
class_name HUD
## All on-screen UI, drawn procedurally. The SUSPICION meter is the centerpiece.

# Play-field size — single-sourced from Game so the HUD always matches the arena.
var W := Game.arena.x
var H := Game.arena.y

var _canvas    # _HudCanvas (untyped so its custom `hud` field is accessible)

# snapshot of game state, refreshed each frame
var suspicion := 0.0
var phase := "serving"
var p_hp := 0.0
var p_max := 1.0
var p_lvl := 1
var p_power := 1.0
var p_poison := 0.0
var p_hostile := false
var s_hp := 0.0
var s_stam := 0.0
var s_carry := ""
var s_cursed := false
var s_tip := 0.0
var wave := 0
var score := 0
var monsters := 0

var _announce := ""
var _announce_t := 0.0
var _say := ""
var _say_t := 0.0
var _sq := ""             # squire / narrator bark (snide villain voice)
var _sq_t := 0.0
var _big := ""            # giant centre-screen flash (e.g. the "67" gag)
var _big_t := 0.0
var _betray_t := 0.0
var _over := false
var _won := false
var _final_score := 0
var _final_wave := 0

func _ready() -> void:
	layer = 10
	_canvas = _HudCanvas.new()
	_canvas.hud = self
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)

func _process(delta: float) -> void:
	var dirty := false
	if _announce_t > 0.0: _announce_t -= delta; dirty = true
	if _say_t > 0.0: _say_t -= delta; dirty = true
	if _sq_t > 0.0: _sq_t -= delta; dirty = true
	if _big_t > 0.0: _big_t -= delta; dirty = true
	if _betray_t > 0.0: _betray_t -= delta; dirty = true
	if dirty and _canvas:
		_canvas.queue_redraw()

func announce(text: String) -> void:
	_announce = text
	_announce_t = 2.2

func princess_say(text: String) -> void:
	_say = text
	_say_t = 2.5

func squire_say(text: String) -> void:
	_sq = text
	_sq_t = 2.6

func big_flash(text: String) -> void:
	_big = text
	_big_t = 1.6

func betray() -> void:
	_betray_t = 3.0

func show_end(won: bool, final_score: int, final_wave: int) -> void:
	_over = true
	_won = won
	_final_score = final_score
	_final_wave = final_wave
	if _canvas:
		_canvas.queue_redraw()

func update_state(game: Game) -> void:
	W = Game.arena.x        # track the live playable area
	H = Game.arena.y
	suspicion = game.suspicion
	phase = game.phase
	var pr := game.princess
	var sq := game.squire
	if pr:
		p_hp = pr.hp; p_max = pr._eff_max_hp(); p_lvl = pr.level
		p_power = pr.power_mult; p_poison = pr.poison_dps; p_hostile = pr.hostile
	if sq:
		s_hp = sq.hp; s_stam = sq.stamina; s_carry = sq.carry; s_cursed = sq.cursed; s_tip = sq.tip_cd
	wave = game.wave
	score = game.score
	monsters = game.get_tree().get_nodes_in_group("monsters").size()
	if _canvas:
		_canvas.queue_redraw()

# --- drawing ---
func _render(c: Control) -> void:
	var f := ThemeDB.fallback_font

	_render_suspicion(c, f)
	_render_princess(c, f)
	_render_squire(c, f)
	_render_carry(c, f)

	# Controls hint (bottom-right)
	c.draw_string(f, Vector2(W - 700, H - 16),
		"WASD move · Space dash · Ctrl tamper · bump Princess = give · E tip off · Q scheme · Esc pause · R restart",
		HORIZONTAL_ALIGNMENT_LEFT, 690, 12, Color(1, 1, 1, 0.4))

	# Princess speech (under the suspicion meter)
	if _say_t > 0.0:
		var sa: float = clampf(_say_t, 0.0, 1.0)
		c.draw_string(f, Vector2(0, 92), "\"%s\"" % _say, HORIZONTAL_ALIGNMENT_CENTER, W, 22,
			Color(1.0, 0.85, 0.9, sa))

	# Squire / narrator bark (your snide villain voice), just below her line
	if _sq_t > 0.0:
		var qa: float = clampf(_sq_t, 0.0, 1.0)
		c.draw_string(f, Vector2(0, 120), "— %s" % _sq, HORIZONTAL_ALIGNMENT_CENTER, W, 20,
			Color(0.6, 1.0, 0.65, qa))

	# Giant centre-screen flash (the "67" gag, etc.)
	if _big_t > 0.0 and not _over:
		var ba: float = clampf(_big_t / 1.6, 0.0, 1.0)
		var bs: int = int(90 + (1.0 - ba) * 40.0)            # punches outward as it fades
		c.draw_string(f, Vector2(0, H * 0.5 - 40.0), _big, HORIZONTAL_ALIGNMENT_CENTER, W, bs,
			Color(1.0, 0.85, 0.25, ba))

	# Wave / level announcement
	if _announce_t > 0.0 and _betray_t <= 0.0 and not _over:
		var aa: float = clampf(_announce_t / 1.0, 0.0, 1.0)
		c.draw_string(f, Vector2(0, 150), _announce, HORIZONTAL_ALIGNMENT_CENTER, W, 34,
			Color(1, 1, 1, aa))

	# Betrayal banner
	if _betray_t > 0.0 and not _over:
		c.draw_string(f, Vector2(0, 250), "SHE KNOWS.", HORIZONTAL_ALIGNMENT_CENTER, W, 66,
			Color(1.0, 0.2, 0.25))
		c.draw_string(f, Vector2(0, 300), "The monsters rally to your side — bring her down!",
			HORIZONTAL_ALIGNMENT_CENTER, W, 22, Color(1, 1, 1, 0.9))

	if _over:
		_render_end(c, f)

func _render_suspicion(c: Control, f: Font) -> void:
	var bw := 460.0
	var x := (W - bw) * 0.5
	var rect := Rect2(x, 16, bw, 22)
	var ratio: float = clampf(suspicion / Game.SUSPICION_MAX, 0.0, 1.0)
	var fill := Color(0.35, 0.85, 0.45).lerp(Color(1.0, 0.25, 0.25), ratio)
	_bar(c, rect, ratio, fill)
	c.draw_string(f, Vector2(x, 33), "SUSPICION  %d%%" % int(round(ratio * 100.0)),
		HORIZONTAL_ALIGNMENT_CENTER, bw, 15, Color(1, 1, 1, 0.95))

func _render_princess(c: Control, f: Font) -> void:
	var title := "PRINCESS — FINAL BOSS" if p_hostile else "PRINCESS  Lv.%d" % p_lvl
	var title_col := Color(1.0, 0.35, 0.4) if p_hostile else Color(1.0, 0.6, 0.8)
	c.draw_string(f, Vector2(16, 26), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, title_col)
	var fill := Color(1.0, 0.25, 0.25) if p_hostile else Color(0.95, 0.4, 0.65)
	_bar(c, Rect2(16, 34, 300, 18), p_hp / p_max, fill)
	c.draw_string(f, Vector2(20, 48), "%d / %d" % [int(p_hp), int(p_max)],
		HORIZONTAL_ALIGNMENT_LEFT, 290, 12, Color(1, 1, 1, 0.9))
	# Sabotage readout
	var notes := PackedStringArray()
	if p_power < 0.999:
		notes.append("ATK %d%%" % int(round(p_power * 100.0)))
	if p_poison > 0.0:
		notes.append("POISONED")
	if notes.size() > 0:
		c.draw_string(f, Vector2(16, 74), "  ·  ".join(notes), HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color(0.7, 1.0, 0.6))

func _render_squire(c: Control, f: Font) -> void:
	c.draw_string(f, Vector2(16, H - 74), "SQUIRE (you)", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 0.9, 0.7))
	_bar(c, Rect2(16, H - 64, 240, 16), s_hp / Squire.MAX_HP, Color(0.85, 0.3, 0.3))
	c.draw_string(f, Vector2(264, H - 51), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.8))
	_bar(c, Rect2(16, H - 44, 240, 12), s_stam / Squire.MAX_STAMINA, Color(0.35, 0.7, 1.0))
	c.draw_string(f, Vector2(264, H - 34), "Stamina", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.8))
	var tip := "Tip-off [E]: READY" if s_tip <= 0.0 else "Tip-off [E]: %.1fs" % s_tip
	c.draw_string(f, Vector2(16, H - 16), tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		Color(1.0, 0.6, 0.3) if s_tip <= 0.0 else Color(1, 1, 1, 0.5))

func _render_carry(c: Control, f: Font) -> void:
	var txt: String
	var col: Color
	if s_carry == "":
		txt = "Carrying: —   (grab supplies off the floor)"
		col = Color(1, 1, 1, 0.45)
	else:
		var state := "CURSED" if s_cursed else "genuine"
		txt = "Carrying: %s  [%s]" % [s_carry.to_upper(), state]
		col = Color(0.8, 0.4, 1.0) if s_cursed else Color(0.7, 1.0, 0.7)
	c.draw_string(f, Vector2(0, H - 64), txt, HORIZONTAL_ALIGNMENT_CENTER, W, 18, col)

func _render_end(c: Control, f: Font) -> void:
	c.draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.6))
	if _won:
		c.draw_string(f, Vector2(0, 250), "LONG LIVE THE SQUIRE", HORIZONTAL_ALIGNMENT_CENTER, W, 58, Color(0.5, 1.0, 0.6))
		c.draw_string(f, Vector2(0, 308), "The Princess is dead. The throne is yours.",
			HORIZONTAL_ALIGNMENT_CENTER, W, 24, Color.WHITE)
	else:
		c.draw_string(f, Vector2(0, 250), "EXECUTED FOR TREASON", HORIZONTAL_ALIGNMENT_CENTER, W, 58, Color(1.0, 0.3, 0.35))
		c.draw_string(f, Vector2(0, 308), "You should have been more careful, squire.",
			HORIZONTAL_ALIGNMENT_CENTER, W, 24, Color.WHITE)
	c.draw_string(f, Vector2(0, 352), "Reached wave %d  ·  Score %d" % [_final_wave, _final_score],
		HORIZONTAL_ALIGNMENT_CENTER, W, 20, Color(1, 1, 1, 0.85))
	c.draw_string(f, Vector2(0, 392), "Press R to scheme again", HORIZONTAL_ALIGNMENT_CENTER, W, 20,
		Color(1, 1, 1, 0.75))

func _bar(c: Control, rect: Rect2, ratio: float, fill: Color) -> void:
	c.draw_rect(rect, Color(0, 0, 0, 0.55))
	var r: float = clampf(ratio, 0.0, 1.0)
	c.draw_rect(Rect2(rect.position, Vector2(rect.size.x * r, rect.size.y)), fill)
	c.draw_rect(rect, Color(1, 1, 1, 0.25), false, 2.0)


class _HudCanvas:
	extends Control
	var hud
	func _draw() -> void:
		if hud:
			hud._render(self)
