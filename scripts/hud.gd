extends CanvasLayer
class_name HUD
## All on-screen UI, drawn procedurally (no fonts/assets required).

# Play-field size — single-sourced from Game so the HUD always matches the arena.
var W := Game.ARENA_SIZE.x
var H := Game.ARENA_SIZE.y

var _canvas    # _HudCanvas (untyped so its custom `hud` field is accessible)

# snapshot of game state, refreshed each frame
var p_hp := 0.0
var p_max := 1.0
var p_wlvl := 1
var p_wname := ""
var s_hp := 0.0
var s_stam := 0.0
var s_carry := ""
var wave := 0
var score := 0
var monsters := 0

var _announce := ""
var _announce_t := 0.0
var _over := false
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
	if _announce_t > 0.0:
		_announce_t -= delta
		if _canvas:
			_canvas.queue_redraw()

func announce(text: String) -> void:
	_announce = text
	_announce_t = 2.2

func show_gameover(final_score: int, final_wave: int) -> void:
	_over = true
	_final_score = final_score
	_final_wave = final_wave
	if _canvas:
		_canvas.queue_redraw()

func update_state(game: Game) -> void:
	var pr := game.princess
	var sq := game.squire
	if pr:
		p_hp = pr.hp; p_max = pr.max_hp; p_wlvl = pr.weapon_level; p_wname = pr.weapon_name
	if sq:
		s_hp = sq.hp; s_stam = sq.stamina; s_carry = sq.carry
	wave = game.wave
	score = game.score
	monsters = game.get_tree().get_nodes_in_group("monsters").size()
	if _canvas:
		_canvas.queue_redraw()

# --- drawing (called from the inner Control) ---
func _render(c: Control) -> void:
	var f := ThemeDB.fallback_font

	# Princess panel (top-left)
	c.draw_string(f, Vector2(16, 26), "PRINCESS", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.6, 0.8))
	_bar(c, Rect2(16, 34, 300, 18), p_hp / p_max, Color(0.95, 0.4, 0.65))
	c.draw_string(f, Vector2(20, 48), "%d / %d" % [int(p_hp), int(p_max)],
		HORIZONTAL_ALIGNMENT_LEFT, 290, 12, Color(1, 1, 1, 0.9))
	c.draw_string(f, Vector2(16, 76), "Weapon: %s  (Lv.%d)" % [p_wname, p_wlvl],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.85, 0.4))

	# Squire panel (bottom-left)
	c.draw_string(f, Vector2(16, H - 70), "SQUIRE (you)", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 0.9, 0.7))
	_bar(c, Rect2(16, H - 60, 240, 16), s_hp / Squire.MAX_HP, Color(0.85, 0.3, 0.3))
	c.draw_string(f, Vector2(264, H - 47), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.8))
	_bar(c, Rect2(16, H - 40, 240, 12), s_stam / Squire.MAX_STAMINA, Color(0.35, 0.7, 1.0))
	c.draw_string(f, Vector2(264, H - 30), "Stamina", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.8))

	# Carry indicator (bottom-left, right of bars)
	var carry_txt := "Carrying: —"
	if s_carry == "potion": carry_txt = "Carrying: POTION"
	elif s_carry == "weapon": carry_txt = "Carrying: WEAPON"
	c.draw_string(f, Vector2(330, H - 44), carry_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
		Color(1, 1, 1) if s_carry != "" else Color(1, 1, 1, 0.45))

	# Wave / score (top-center)
	var top := "ROOM %d        SCORE %d        Monsters: %d" % [wave, score, monsters]
	c.draw_string(f, Vector2(0, 28), top, HORIZONTAL_ALIGNMENT_CENTER, W, 18, Color(0.9, 0.9, 1.0))

	# Controls hint (bottom-right)
	c.draw_string(f, Vector2(W - 470, H - 16),
		"WASD/Arrows move · Space dash · bump Princess to hand · Ctrl drink/yeet · R restart",
		HORIZONTAL_ALIGNMENT_LEFT, 460, 12, Color(1, 1, 1, 0.4))

	# Announcement (center)
	if _announce_t > 0.0 and not _over:
		var a: float = clamp(_announce_t / 1.0, 0.0, 1.0)
		c.draw_string(f, Vector2(0, 230), _announce, HORIZONTAL_ALIGNMENT_CENTER, W, 40,
			Color(1, 1, 1, a))

	# Game over
	if _over:
		c.draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.55))
		c.draw_string(f, Vector2(0, 270), "GAME OVER", HORIZONTAL_ALIGNMENT_CENTER, W, 64, Color(1, 0.3, 0.35))
		c.draw_string(f, Vector2(0, 330), "You reached Room %d  ·  Score %d" % [_final_wave, _final_score],
			HORIZONTAL_ALIGNMENT_CENTER, W, 26, Color.WHITE)
		c.draw_string(f, Vector2(0, 380), "Press R to try again", HORIZONTAL_ALIGNMENT_CENTER, W, 22,
			Color(1, 1, 1, 0.8))

func _bar(c: Control, rect: Rect2, ratio: float, fill: Color) -> void:
	c.draw_rect(rect, Color(0, 0, 0, 0.55))
	var r: float = clamp(ratio, 0.0, 1.0)
	c.draw_rect(Rect2(rect.position, Vector2(rect.size.x * r, rect.size.y)), fill)
	c.draw_rect(rect, Color(1, 1, 1, 0.25), false, 2.0)


class _HudCanvas:
	extends Control
	var hud
	func _draw() -> void:
		if hud:
			hud._render(self)
