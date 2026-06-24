extends Node2D
class_name Angel
## The "Angel of Retribution" — divine punishment for the squire's serial sabotage.
## Pure procedural visual (drawn in _draw, no art), fire-and-forget like Fx: it
## descends from the top, hovers with flapping wings while the EventDirector rains
## Trap laser beams, then ascends and frees. It deals NO damage itself — the lasers
## do. Spawn with Angel.descend(parent, x, hover_y).

var _t := 0.0
var _life := 4.5
var _x := 0.0
var _hover_y := 130.0
var _col := Color(1.0, 0.95, 0.55)

func _ready() -> void:
	z_index = 49                                   # above traps/actors, just under Fx
	modulate = Color(1, 1, 1, 0.0)

func _process(delta: float) -> void:
	_t += delta
	if _t >= _life:
		queue_free()
		return
	var ease_in := clampf(_t / 0.6, 0.0, 1.0)
	var ease_out := clampf((_life - _t) / 0.6, 0.0, 1.0)
	var enter := -200.0 * (1.0 - ease_in)          # drops in from above...
	var exit := -200.0 * (1.0 - ease_out)          # ...and rises back out
	position = Vector2(_x, _hover_y + enter + exit + sin(_t * 3.0) * 6.0)
	modulate = Color(1, 1, 1, minf(ease_in, ease_out))
	queue_redraw()

func _draw() -> void:
	var pulse := 0.6 + 0.4 * sin(_t * 5.0)
	# divine glow
	draw_circle(Vector2.ZERO, 78.0, Color(_col.r, _col.g, _col.b, 0.08 * pulse))
	# halo
	draw_arc(Vector2(0, -36), 22.0, 0.0, TAU, 32, Color(_col.r, _col.g, _col.b, 0.95), 4.0, true)
	# wings (flapping)
	var flap := sin(_t * 6.0) * 12.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, -10), Vector2(-62, -28 - flap), Vector2(-54, 12), Vector2(-16, 6)]),
		Color(1, 1, 1, 0.9))
	draw_colored_polygon(PackedVector2Array([
		Vector2(14, -10), Vector2(62, -28 - flap), Vector2(54, 12), Vector2(16, 6)]),
		Color(1, 1, 1, 0.9))
	# robe + head
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, -18), Vector2(14, -18), Vector2(22, 42), Vector2(-22, 42)]),
		Color(0.98, 0.98, 1.0, 0.95))
	draw_circle(Vector2(0, -22), 12.0, Color(1.0, 0.92, 0.8))

static func descend(parent: Node, at_x: float, hover_y := 130.0) -> void:
	var a := Angel.new()
	a._x = at_x
	a._hover_y = hover_y
	a.position = Vector2(at_x, -200.0)
	parent.add_child(a)
