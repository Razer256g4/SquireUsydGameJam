extends Node2D
class_name Airplane
## Fire-and-forget cartoon plane (procedural, no art) — the visible half of the plane
## crash, modelled on Angel: screams in from offscreen and nosedives into the crash
## point over `_life`s (synced to the event telegraph), trailing smoke and tilting
## nose-down, then frees. Deals NO damage — EventDirector's telegraph→_plane_impact
## still does the boom, exactly like the Angel leaves the damage to its lasers.

var _t := 0.0
var _life := 1.5            # travel time == EventDirector.PLANE_DELAY, so it lands on the boom
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _smoke_t := 0.0
var _col := Color(0.86, 0.89, 0.96)
var _game: Game

func _ready() -> void:
	z_index = 49            # above actors/traps, just under Fx (matches Angel)
	_game = get_tree().get_first_node_in_group("game") as Game

func _process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / _life, 0.0, 1.0)
	position = _from.lerp(_to, k * k)                       # accelerate in: "coming in hot"
	rotation = (_to - _from).angle() + sin(_t * 28.0) * (0.06 + 0.18 * k)   # wobble grows as it dives
	_smoke_t -= delta
	if _smoke_t <= 0.0 and _game:
		_smoke_t = 0.07
		Fx.sparks(_game, global_position, Color(0.6, 0.6, 0.66, 0.85), 3, 55.0, 0.6)   # smoke trail
	if _t >= _life:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	# Drawn nose-toward +X; `rotation` aims it along the dive. Stubby comic airliner.
	draw_colored_polygon(PackedVector2Array([
		Vector2(52, 0), Vector2(20, -13), Vector2(-40, -12),
		Vector2(-48, 0), Vector2(-40, 12), Vector2(20, 13)]), _col)                    # fuselage
	var wing := Color(0.72, 0.76, 0.84)
	draw_colored_polygon(PackedVector2Array([Vector2(4, -6), Vector2(-12, -42), Vector2(-22, -42), Vector2(-12, -6)]), wing)
	draw_colored_polygon(PackedVector2Array([Vector2(4, 6), Vector2(-12, 42), Vector2(-22, 42), Vector2(-12, 6)]), wing)
	draw_colored_polygon(PackedVector2Array([Vector2(-40, -12), Vector2(-58, -30), Vector2(-50, -8)]), Color(0.85, 0.3, 0.32))  # tail fin
	draw_circle(Vector2(6, -2), 5.0, Color(0.45, 0.72, 1.0))                           # cockpit windows
	draw_circle(Vector2(-10, -2), 5.0, Color(0.45, 0.72, 1.0))
	var spin := _t * 40.0                                                              # spinning prop at the nose
	for i in 2:
		var a := spin + i * PI
		draw_line(Vector2(52, 0), Vector2(52, 0) + Vector2(cos(a), sin(a)) * 18.0, Color(1, 1, 1, 0.55), 2.0, true)
	draw_circle(Vector2(52, 0), 3.0, Color(0.15, 0.15, 0.15))

static func crash(parent: Node, from: Vector2, to: Vector2, travel: float) -> void:
	var pl := Airplane.new()
	pl._from = from
	pl._to = to
	pl._life = travel
	pl.position = from
	parent.add_child(pl)
