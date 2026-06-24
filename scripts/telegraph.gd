extends Node2D
class_name Telegraph
## A "warning then strike" danger indicator. It charges (a danger zone fills up +
## pulses) for `delay` seconds, then calls `on_strike` exactly once and frees.
## Fire-and-forget like Fx — pass the world (Game) as `parent`. Two shapes:
##   "circle" — radial AoE
##   "line"   — thick capsule along a segment (beams / charge paths)
## The strike Callable must self-guard the caster with is_instance_valid: the
## Princess can be freed (win / scene reload) during the short charge window.

var _kind := "circle"          # "circle" | "line"
var _t := 0.0
var _delay := 0.6
var _r := 120.0                # circle radius, or line half-thickness
var _from := Vector2.ZERO      # line endpoints, local to this node
var _to := Vector2.ZERO
var _col := Color(1.0, 0.3, 0.2)
var _struck := false
var _on_strike := Callable()

func _process(delta: float) -> void:
	_t += delta
	if not _struck and _t >= _delay:
		_struck = true
		if _on_strike.is_valid():
			_on_strike.call()
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var k: float = clampf(_t / _delay, 0.0, 1.0)
	var pulse: float = 0.35 + 0.25 * sin(_t * 16.0)
	var edge := Color(_col.r, _col.g, _col.b, 0.85)
	var fill := Color(_col.r, _col.g, _col.b, (0.12 + 0.30 * k) * pulse + 0.10)
	match _kind:
		"circle":
			draw_circle(Vector2.ZERO, _r, fill)
			draw_arc(Vector2.ZERO, _r, 0.0, TAU, 64, edge, 3.0, true)
			# inner ring sweeps outward as the strike approaches
			draw_arc(Vector2.ZERO, _r * k, 0.0, TAU, 64,
				Color(1, 1, 1, 0.5 + 0.5 * k), maxf(2.0, 6.0 * k), true)
		"line":
			var d: Vector2 = _to - _from
			var ln: float = d.length()
			if ln < 0.001:
				return
			var dir: Vector2 = d / ln
			var perp: Vector2 = dir.orthogonal() * _r
			draw_colored_polygon(PackedVector2Array([
				_from + perp, _to + perp, _to - perp, _from - perp]), fill)
			draw_polyline(PackedVector2Array([
				_from + perp, _to + perp, _to - perp, _from - perp, _from + perp]),
				edge, 3.0, true)
			# a "loading" sweep down the path
			draw_line(_from, _from + dir * ln * k, Color(1, 1, 1, 0.6), maxf(2.0, _r * 0.5 * k), true)

static func _spawn(parent: Node, pos: Vector2) -> Telegraph:
	var t := Telegraph.new()
	t.position = pos
	t.z_index = 6                  # ground warning: above floor/pickups, under Fx & actors
	parent.add_child(t)
	return t

static func circle(parent: Node, center: Vector2, radius: float, delay: float, col: Color, on_strike: Callable) -> void:
	var t := _spawn(parent, center)
	t._kind = "circle"
	t._r = radius
	t._delay = delay
	t._col = col
	t._on_strike = on_strike

static func line(parent: Node, from: Vector2, to: Vector2, half_w: float, delay: float, col: Color, on_strike: Callable) -> void:
	var t := _spawn(parent, from)  # node sits at `from`; endpoints stored relative to it
	t._kind = "line"
	t._from = Vector2.ZERO
	t._to = to - from
	t._r = half_w
	t._delay = delay
	t._col = col
	t._on_strike = on_strike
