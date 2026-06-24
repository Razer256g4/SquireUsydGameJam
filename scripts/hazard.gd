extends Node2D
class_name Hazard
## A lingering ground hazard left behind by an event (e.g. the plane-crash crater).
## Fire-and-forget like Telegraph/Fx: spawn it with Hazard.spawn() and it ticks
## damage to anyone standing inside for `_life` seconds, then fades and frees.

var _life := 5.0
var _t := 0.0
var _r := 120.0
var _dps := 14.0
var _col := Color(1.0, 0.5, 0.2)
var _tick := 0.0
var _game: Game

func _ready() -> void:
	z_index = 3                       # above floor/pickups, below actors & Fx
	_game = get_tree().get_first_node_in_group("game") as Game

func _process(delta: float) -> void:
	# Pause cleanly outside active play (win/lose) by just sitting still.
	if _game and _game.phase != "serving" and _game.phase != "boss":
		queue_redraw()
		return
	_t += delta
	if _t >= _life:
		queue_free()
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.25
		_damage_in(_dps * 0.25)
	queue_redraw()

func _damage_in(amount: float) -> void:
	for n in get_tree().get_nodes_in_group("monsters"):
		var m := n as Monster
		if global_position.distance_to(m.global_position) <= _r + m.radius:
			m.take_damage(amount)
	var pr := get_tree().get_first_node_in_group("princess") as Princess
	if pr and global_position.distance_to(pr.global_position) <= _r + Princess.RADIUS:
		pr.take_damage(amount)
	var sq := get_tree().get_first_node_in_group("squire") as Squire
	if sq and global_position.distance_to(sq.global_position) <= _r + Squire.RADIUS:
		sq.take_damage(amount)
	# SFX: hazard sizzle (deferred)

func _draw() -> void:
	var k := clampf(_t / _life, 0.0, 1.0)
	var fade := 1.0 - k
	# scorched crater
	draw_circle(Vector2.ZERO, _r, Color(0.12, 0.07, 0.05, 0.35 + 0.25 * fade))
	# smouldering rim
	var pulse := 0.5 + 0.3 * sin(_t * 7.0)
	draw_arc(Vector2.ZERO, _r, 0.0, TAU, 56,
		Color(_col.r, _col.g, _col.b, (0.35 + 0.35 * fade) * pulse), 5.0, true)
	draw_arc(Vector2.ZERO, _r * 0.6, 0.0, TAU, 40,
		Color(1.0, 0.85, 0.4, 0.25 * fade * pulse), 3.0, true)

static func spawn(parent: Node, pos: Vector2, radius: float, dps: float, life: float, col: Color) -> void:
	var h := Hazard.new()
	h.position = pos
	h._r = radius
	h._dps = dps
	h._life = life
	h._col = col
	parent.add_child(h)
