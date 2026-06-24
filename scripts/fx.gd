extends Node2D
class_name Fx
## Asset-free, fire-and-forget visual effects.
##
## Everything here is procedural so it needs no art: CPUParticles2D for debris (it
## renders on the `gl_compatibility` backend this project targets, unlike the GPU
## emitter) plus a hand-drawn ring / bolt / slash that animates in _process and
## queue_free()s itself when its lifetime runs out. Call the static factories from
## anywhere — pass the world node (usually the Game) as `parent`.

# An Fx instance is one hand-drawn shape. `_kind` selects what _draw() renders.
var _kind := "ring"
var _t := 0.0
var _life := 0.45
var _col := Color.WHITE
var _r := 120.0                       # ring/slash radius (reach)
var _w := 8.0                         # stroke width
var _pts := PackedVector2Array()      # bolt: jagged path (local); slash: [Vector2(angle,0)]

func _process(delta: float) -> void:
	_t += delta
	if _t >= _life:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var k := clampf(_t / _life, 0.0, 1.0)
	var fade := 1.0 - k
	match _kind:
		"ring":
			var r := _r * sqrt(k)                       # expands fast, then eases
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 64,
				Color(_col.r, _col.g, _col.b, fade), maxf(2.0, _w * fade), true)
			draw_arc(Vector2.ZERO, r * 0.7, 0.0, TAU, 48,
				Color(1, 1, 1, fade * 0.6), maxf(1.0, _w * 0.5 * fade), true)
		"bolt":
			var col := Color(_col.r, _col.g, _col.b, fade)
			for i in range(_pts.size() - 1):
				draw_line(_pts[i], _pts[i + 1], col, _w * (0.6 + 0.8 * fade), true)
			for i in range(_pts.size() - 1):   # white-hot core
				draw_line(_pts[i], _pts[i + 1], Color(1, 1, 1, fade * 0.8), _w * 0.4, true)
		"slash":
			var base: float = _pts[0].x if _pts.size() > 0 else 0.0
			var sweep := PI * 0.9
			var ang0 := base - sweep * 0.5
			draw_arc(Vector2.ZERO, _r, ang0, ang0 + sweep * k, 24,
				Color(_col.r, _col.g, _col.b, fade), _w * (1.0 - k * 0.5), true)

# --- hand-drawn shape factories ---
static func _spawn(parent: Node, pos: Vector2) -> Fx:
	var f := Fx.new()
	f.position = pos
	f.z_index = 50
	parent.add_child(f)
	return f

static func ring(parent: Node, pos: Vector2, radius: float, col: Color, life := 0.45, width := 8.0) -> void:
	var f := _spawn(parent, pos)
	f._kind = "ring"; f._r = radius; f._col = col; f._life = life; f._w = width

static func bolt(parent: Node, from: Vector2, to: Vector2, col: Color, life := 0.22) -> void:
	var f := _spawn(parent, from)
	f._kind = "bolt"; f._col = col; f._life = life; f._w = 4.0
	var d := to - from
	var perp := d.orthogonal().normalized()
	var span := d.length()
	var n := 8
	var pts := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		var jitter := 0.0 if (i == 0 or i == n) else randf_range(-1.0, 1.0) * span * 0.08
		pts.append(d * t + perp * jitter)
	f._pts = pts

static func slash(parent: Node, pos: Vector2, facing: Vector2, reach: float, col: Color) -> void:
	var f := _spawn(parent, pos)
	f._kind = "slash"; f._r = reach; f._col = col; f._life = 0.25; f._w = 10.0
	f._pts = PackedVector2Array([Vector2(facing.angle(), 0.0)])

# --- particle debris ---
static func sparks(parent: Node, pos: Vector2, col: Color, amount: int, power: float, life := 0.6) -> void:
	var p := CPUParticles2D.new()
	p.texture = _dot_tex()
	p.position = pos
	p.z_index = 48
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = maxi(1, amount)
	p.lifetime = life
	p.direction = Vector2.RIGHT
	p.spread = 180.0                      # full radial burst
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = power * 0.35
	p.initial_velocity_max = power
	p.damping_min = power * 0.4
	p.damping_max = power * 0.9
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0
	p.color = col
	var g := Gradient.new()
	g.set_color(0, Color(col.r, col.g, col.b, 1.0))
	g.set_color(1, Color(col.r, col.g, col.b, 0.0))
	p.color_ramp = g
	parent.add_child(p)
	p.emitting = true
	# Free once the burst has fully faded. Auto-disconnects if the node dies first.
	p.get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)

# --- composite signature effects ---
static func explosion(parent: Node, pos: Vector2, col: Color, radius: float) -> void:
	ring(parent, pos, radius, col, 0.5, 10.0)
	sparks(parent, pos, col, 70, radius * 2.0, 0.7)
	sparks(parent, pos, Color(1.0, 0.95, 0.7), 30, radius * 1.2, 0.5)   # hot core

static func nova(parent: Node, pos: Vector2, radius: float, col: Color) -> void:
	ring(parent, pos, radius, col, 0.55, 12.0)
	ring(parent, pos, radius * 0.6, Color(1, 1, 1, 0.9), 0.4, 6.0)
	sparks(parent, pos, col, 50, radius * 1.6, 0.6)

# Soft round dot used by every particle burst (built once, cached).
static var _dot: Texture2D
static func _dot_tex() -> Texture2D:
	if _dot:
		return _dot
	var s := 16
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c := Vector2(s, s) * 0.5
	for y in s:
		for x in s:
			var dd := Vector2(x + 0.5, y + 0.5).distance_to(c) / (s * 0.5)
			var a := clampf(1.0 - dd, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	_dot = ImageTexture.create_from_image(img)
	return _dot
