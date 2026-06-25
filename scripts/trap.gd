extends Node2D
class_name Trap
## A MOVING ground hazard — the chaos-mode cousin of the stationary Hazard.
## Fire-and-forget like Telegraph / Fx / Hazard: a static factory telegraphs a
## "troll-short" warning, then spawns one of these to actually move + deal damage.
## Three behaviours, switched by `_mode` (the codebase idiom, cf. Fx._kind):
##   "roller" — a spiked disc that crosses the arena in a straight line
##   "laser"  — a damaging bar that slides across, OR a clock-hand that pivots
##   "spikes" — surprise pop-up tiles that jab a few times then retract
##
## Damage is distance-based like Hazard (no physics): every TICK seconds it hits
## anyone whose body overlaps the trap. Who it hurts is gated by hurt_* flags.
##
## COORDINATE RULE: this node sits at position (0,0) and stores ALL geometry in
## WORLD space, so local == world and _draw() lines up exactly with the damage
## math. Never give a Trap a non-zero position or the visuals desync from the hits.

const TICK := 0.25                     # damage cadence (matches Hazard)

var _mode := "roller"                  # "roller" | "laser" | "spikes"

# who takes damage (default: everyone — you dodge, the Princess gets chipped)
var hurt_squire := true
var hurt_princess := true
var hurt_monsters := true

# damage
var _dps := 26.0
var _tick := 0.0
var _jab := 22.0                       # spikes: damage per pop (one-shot, not dps*TICK)

# geometry (world space)
var _r := 34.0                         # roller radius / laser half-width / spike radius
var _from := Vector2.ZERO
var _to := Vector2.ZERO                # roller: disc centre. laser: far endpoint.
var _dir := Vector2.RIGHT
var _speed := 320.0

# rotating laser (clock-hand)
var _rotating := false
var _pivot := Vector2.ZERO
var _len := 600.0
var _ang := 0.0
var _ang_start := 0.0
var _ang_speed := 1.0                  # rad/sec
var _ang_total := PI                   # sweep this many rad then despawn

# spikes
var _tiles := PackedVector2Array()
var _spike_on := false
var _spike_t := 0.0
var _spike_up := 0.12
var _spike_down := 0.4
var _spike_cycles := 3
var _spike_done := 0

# lifecycle
var _t := 0.0
var _life_guard := 12.0                # hard despawn backstop (no trap lingers forever)
var _col := Color(1.0, 0.2, 0.55)
var _game: Game

func _ready() -> void:
	z_index = 3                        # above floor/pickups, below actors & Fx (like Hazard)
	position = Vector2.ZERO
	_game = get_tree().get_first_node_in_group("game") as Game

func _process(delta: float) -> void:
	# Pause cleanly outside active play (win/lose), exactly like Hazard.
	if _game and _game.phase != "serving" and _game.phase != "boss":
		queue_redraw()
		return
	_t += delta
	_life_guard -= delta
	if _life_guard <= 0.0:
		queue_free()
		return
	_tick -= delta
	match _mode:
		"roller": _step_roller(delta)
		"laser": _step_laser(delta)
		"spikes": _step_spikes(delta)
	queue_redraw()

# --- per-mode movement + damage --------------------------------------------
func _step_roller(delta: float) -> void:
	_to += _dir * _speed * delta
	if _tick <= 0.0:
		_tick = TICK
		_damage_circle(_to, _r, _dps * TICK)
	if _off_arena(_to, _r):
		Fx.sparks(get_parent(), _to, _col, 16, 140.0, 0.4)
		queue_free()

func _step_laser(delta: float) -> void:
	var a: Vector2
	var b: Vector2
	if _rotating:
		_ang += _ang_speed * delta
		a = _pivot
		b = _pivot + Vector2(cos(_ang), sin(_ang)) * _len
	else:
		var step := _dir * _speed * delta
		_from += step
		_to += step
		a = _from
		b = _to
	if _tick <= 0.0:
		_tick = TICK
		_damage_segment(a, b, _r, _dps * TICK)
	if _rotating:
		if absf(_ang - _ang_start) >= _ang_total:
			queue_free()
	else:
		var mid := (a + b) * 0.5
		var ar := Game.arena
		var gone := ((_dir.x > 0.5 and mid.x > ar.x + _r)
			or (_dir.x < -0.5 and mid.x < -_r)
			or (_dir.y > 0.5 and mid.y > ar.y + _r)
			or (_dir.y < -0.5 and mid.y < -_r))
		if gone:
			queue_free()

func _step_spikes(delta: float) -> void:
	_spike_t -= delta
	if _spike_t > 0.0:
		return
	_spike_on = not _spike_on
	if _spike_on:
		_spike_t = _spike_up
		for c in _tiles:
			_damage_circle(c, _r, _jab)            # one jab, NOT dps*TICK
			Fx.sparks(get_parent(), c, _col, 8, 90.0, 0.3)
	else:
		_spike_t = _spike_down
		_spike_done += 1
		if _spike_done >= _spike_cycles:
			queue_free()

# --- distance damage (Hazard's pattern, gated per target) ------------------
func _damage_circle(center: Vector2, r: float, amount: float) -> void:
	var hit := false
	if hurt_monsters:
		for n in get_tree().get_nodes_in_group("monsters"):
			var m := n as Monster
			if m and center.distance_to(m.global_position) <= r + m.radius:
				m.take_damage(amount)
				hit = true
	if hurt_princess:
		var pr := get_tree().get_first_node_in_group("princess") as Princess
		if pr and center.distance_to(pr.global_position) <= r + Princess.RADIUS:
			pr.take_damage(amount)
			hit = true
	if hurt_squire:
		var sq := get_tree().get_first_node_in_group("squire") as Squire
		if sq and center.distance_to(sq.global_position) <= r + Squire.RADIUS:
			sq.take_damage(amount)
			hit = true
	if hit:
		Sfx.play("trap_hit")

func _damage_segment(a: Vector2, b: Vector2, half_w: float, amount: float) -> void:
	var hit := false
	if hurt_monsters:
		for n in get_tree().get_nodes_in_group("monsters"):
			var m := n as Monster
			if m and _dist_to_segment(m.global_position, a, b) <= half_w + m.radius:
				m.take_damage(amount)
				hit = true
	if hurt_princess:
		var pr := get_tree().get_first_node_in_group("princess") as Princess
		if pr and _dist_to_segment(pr.global_position, a, b) <= half_w + Princess.RADIUS:
			pr.take_damage(amount)
			hit = true
	if hurt_squire:
		var sq := get_tree().get_first_node_in_group("squire") as Squire
		if sq and _dist_to_segment(sq.global_position, a, b) <= half_w + Squire.RADIUS:
			sq.take_damage(amount)
			hit = true
	if hit:
		Sfx.play("trap_hit")

# point→segment distance (copied from princess.gd so Trap is standalone)
func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var l2: float = ab.length_squared()
	if l2 < 0.001:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _off_arena(c: Vector2, r: float) -> bool:
	var ar := Game.arena
	return c.x < -r or c.y < -r or c.x > ar.x + r or c.y > ar.y + r

# --- drawing (local == world because position is ZERO) ---------------------
func _draw() -> void:
	match _mode:
		"roller": _draw_roller()
		"laser": _draw_laser()
		"spikes": _draw_spikes()

func _draw_roller() -> void:
	draw_circle(_to, _r, Color(_col.r, _col.g, _col.b, 0.35))
	draw_arc(_to, _r, 0.0, TAU, 48, Color(_col.r, _col.g, _col.b, 0.9), 4.0, true)
	var spin := _t * 7.0                                   # spokes sell the "rolling"
	for i in 4:
		var ang := spin + i * (PI * 0.5)
		draw_line(_to, _to + Vector2(cos(ang), sin(ang)) * _r * 0.85, Color(1, 1, 1, 0.5), 3.0, true)

func _draw_laser() -> void:
	var a: Vector2
	var b: Vector2
	if _rotating:
		a = _pivot
		b = _pivot + Vector2(cos(_ang), sin(_ang)) * _len
	else:
		a = _from
		b = _to
	var d := b - a
	var ln := d.length()
	if ln < 0.001:
		return
	var perp := (d / ln).orthogonal() * _r
	draw_colored_polygon(PackedVector2Array([a + perp, b + perp, b - perp, a - perp]),
		Color(_col.r, _col.g, _col.b, 0.45))
	draw_line(a, b, Color(1.0, 0.95, 0.8, 0.9), maxf(2.0, _r * 0.5), true)   # white-hot core

func _draw_spikes() -> void:
	for c in _tiles:
		if _spike_on:
			draw_circle(c, _r, Color(_col.r, _col.g, _col.b, 0.5))
			for i in 6:
				var ang := i * (TAU / 6.0)
				draw_line(c, c + Vector2(cos(ang), sin(ang)) * _r * 1.1, Color(1, 1, 1, 0.85), 3.0, true)
		else:
			draw_arc(c, _r, 0.0, TAU, 24, Color(_col.r, _col.g, _col.b, 0.18), 2.0, true)

# --- static factories: telegraph (troll-short), then spawn the mover -------
static func _new_trap(mode: String, col: Color, sq: bool, pr: bool, mo: bool) -> Trap:
	var t := Trap.new()
	t._mode = mode
	t._col = col
	t.hurt_squire = sq
	t.hurt_princess = pr
	t.hurt_monsters = mo
	return t

## A spiked disc that enters from a random edge and rolls straight across.
static func roller(game: Game, delay: float, speed: float, radius: float, col: Color,
		sq := true, pr := true, mo := true) -> void:
	if game == null:
		return
	var ar := Game.arena
	var entry: Vector2
	var dir: Vector2
	match game.rng.randi_range(0, 3):
		0:
			entry = Vector2(-radius, game.rng.randf_range(radius, ar.y - radius))
			dir = Vector2.RIGHT
		1:
			entry = Vector2(ar.x + radius, game.rng.randf_range(radius, ar.y - radius))
			dir = Vector2.LEFT
		2:
			entry = Vector2(game.rng.randf_range(radius, ar.x - radius), -radius)
			dir = Vector2.DOWN
		_:
			entry = Vector2(game.rng.randf_range(radius, ar.x - radius), ar.y + radius)
			dir = Vector2.UP
	var far := entry + dir * (ar.length() + radius * 2.0)
	Telegraph.line(game, entry, far, radius, delay, col, func() -> void:
		if not is_instance_valid(game):
			return
		var t := Trap._new_trap("roller", col, sq, pr, mo)
		t._to = entry
		t._dir = dir
		t._speed = speed
		t._r = radius
		game.add_child(t))

## A bar that slides across the whole arena (vertical sweeps →/←, horizontal ↑/↓).
static func laser(game: Game, delay: float, speed: float, half_w: float, col: Color,
		sq := true, pr := true, mo := true) -> void:
	if game == null:
		return
	var ar := Game.arena
	var from: Vector2
	var to: Vector2
	var dir: Vector2
	if game.rng.randf() < 0.5:
		var x := -half_w if game.rng.randf() < 0.5 else ar.x + half_w
		dir = Vector2.RIGHT if x < 0.0 else Vector2.LEFT
		from = Vector2(x, 0.0)
		to = Vector2(x, ar.y)
	else:
		var y := -half_w if game.rng.randf() < 0.5 else ar.y + half_w
		dir = Vector2.DOWN if y < 0.0 else Vector2.UP
		from = Vector2(0.0, y)
		to = Vector2(ar.x, y)
	Telegraph.line(game, from, to, half_w, delay, col, func() -> void:
		if not is_instance_valid(game):
			return
		var t := Trap._new_trap("laser", col, sq, pr, mo)
		t._from = from
		t._to = to
		t._dir = dir
		t._speed = speed
		t._r = half_w
		game.add_child(t))

## A clock-hand beam that pivots from `pivot`, sweeping `ang_total` rad. (The angel.)
static func laser_spin(game: Game, pivot: Vector2, length: float, ang_speed: float,
		ang_total: float, half_w: float, delay: float, col: Color, start_ang: float,
		sq := true, pr := true, mo := true) -> void:
	if game == null:
		return
	var end := pivot + Vector2(cos(start_ang), sin(start_ang)) * length
	Telegraph.line(game, pivot, end, half_w, delay, col, func() -> void:
		if not is_instance_valid(game):
			return
		var t := Trap._new_trap("laser", col, sq, pr, mo)
		t._rotating = true
		t._pivot = pivot
		t._len = length
		t._ang = start_ang
		t._ang_start = start_ang
		t._ang_speed = ang_speed
		t._ang_total = ang_total
		t._r = half_w
		game.add_child(t))

## Surprise pop-up tiles: warn briefly at `count` random spots, then jab `cycles` times.
static func spikes(game: Game, count: int, radius: float, jab: float, cycles: int,
		delay: float, col: Color, sq := true, pr := true, mo := true) -> void:
	if game == null:
		return
	var tiles := PackedVector2Array()
	for _i in count:
		tiles.append(game._random_inner_point())
	for c in tiles:
		Telegraph.circle(game, c, radius, delay, col, Callable())   # warning-only (empty Callable)
	game.get_tree().create_timer(delay).timeout.connect(func() -> void:
		if not is_instance_valid(game):
			return
		var t := Trap._new_trap("spikes", col, sq, pr, mo)
		t._tiles = tiles
		t._r = radius
		t._jab = jab
		t._spike_cycles = cycles
		game.add_child(t))
