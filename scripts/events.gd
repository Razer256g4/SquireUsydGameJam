extends Node
class_name EventDirector
## Random "fun" events that shake up the serving phase: a plane crash, a peasant
## revolt, the horde infighting, a "67" swarm. MIX triggering — most fire on an
## ambient timer, but the squire can also TRIGGER one on demand (Q in squire.gd),
## which costs suspicion (chaos you cause makes her suspicious: risk/reward, on-theme).
##
## Reuses everything: Telegraph (warn→strike), Fx (visuals), Hazard (crater),
## Game.spawn_monster / spawn points, Game.shake / hitstop, and Lines for quips.

const FIRE := Color(1.0, 0.55, 0.12)
const TRAP_COL := Color(1.0, 0.2, 0.55)    # hot pink-red moving traps
const ANGEL_COL := Color(1.0, 0.95, 0.55)  # holy gold

const SCHEME_CD := 12.0
# "trap" is listed twice so the moving-trap chaos shows up roughly a third of the time.
const AMBIENT := ["infighting", "protestors", "plane", "swarm67", "trap", "trap"]
const SCHEMES := ["plane", "protestors", "infighting"]

const TROLL := 0.35          # short "where did THAT come from" telegraph
const ANGEL_STREAK := 4      # consecutive sabotages before the heavens intervene
const ANGEL_CD := 25.0       # ...and how long until they intervene again
const PLANE_DELAY := 1.5     # plane flight time AND the impact telegraph — kept equal so it lands on the boom

var _game: Game
var rng := RandomNumberGenerator.new()
var _ambient_timer := 14.0
var _last := ""
var _scheme_cd := 0.0
var _angel_cd := 0.0

func _ready() -> void:
	_game = get_parent() as Game
	rng.randomize()
	_ambient_timer = rng.randf_range(10.0, 16.0)

func _process(delta: float) -> void:
	if not _game or _game.phase != "serving":
		return                                  # events only during the serving act
	_scheme_cd = maxf(0.0, _scheme_cd - delta)
	_ambient_timer -= delta
	if _ambient_timer <= 0.0:
		_fire_ambient()
		var base := rng.randf_range(12.0, 20.0)
		_ambient_timer = maxf(7.0, base - _game.wave * 0.4)   # rising chaos with the waves

	# DIVINE RETRIBUTION: keep handing her cursed gifts and the heavens send an angel
	# to laser you. Polls cursed_streak (no game.gd change needed); re-fires on cooldown
	# while the streak stays high, stops once a genuine gift resets it.
	_angel_cd = maxf(0.0, _angel_cd - delta)
	if _game.cursed_streak >= ANGEL_STREAK and _angel_cd <= 0.0:
		_angel_cd = ANGEL_CD
		_ev_angel()

func _fire_ambient() -> void:
	var kind := _last
	var guard := 0
	while kind == _last and guard < 8:          # avoid back-to-back repeats
		kind = AMBIENT[rng.randi() % AMBIENT.size()]
		guard += 1
	_last = kind
	_run(kind)

## Seconds left on the squire-triggered scheme (Q) cooldown — read by the HUD ability
## bar to drive its radial cooldown sweep. 0.0 when ready.
func scheme_cd_left() -> float:
	return _scheme_cd

## Squire-triggered (Q). Fires a scheme on cooldown and bumps suspicion. True if it fired.
func trigger_scheme() -> bool:
	if _scheme_cd > 0.0 or not _game or _game.phase != "serving":
		return false
	_scheme_cd = SCHEME_CD
	_game.minor_suspicion()
	if _game.hud:
		_game.hud.squire_say(Lines.pick(Lines.SCHEME_SQUIRE))
	_run(SCHEMES[rng.randi() % SCHEMES.size()])
	return true

func _run(kind: String) -> void:
	match kind:
		"plane": _ev_plane()
		"protestors": _ev_protestors()
		"infighting": _ev_infighting()
		"swarm67": _ev_swarm67()
		"trap": _ev_trap()

# --- events ----------------------------------------------------------------
func _ev_plane() -> void:
	var radius := 150.0
	# Aim the crash at the Princess's position the moment the scheme fires — she's the
	# target. The telegraph still gives PLANE_DELAY to clear the blast circle, so a
	# moving Princess can dodge it (and you must mind it too).
	var center: Vector2
	var pr := _game.princess
	if pr and is_instance_valid(pr):
		center = Game.clamp_to_arena(pr.global_position, radius)
	else:
		center = _game._random_inner_point()
	if _game.hud:
		_game.hud.announce("INCOMING!")
		_game.hud.squire_say(Lines.pick(Lines.PLANE_SQUIRE))
		_game.hud.princess_say(Lines.pick(Lines.PLANE_PRINCESS))
	# Flashy + funny: an actual plane screams in and nosedives into the ring, arriving
	# exactly when the telegraph completes and the boom lands.
	var ar := Game.arena
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var from := Vector2(center.x + side * (ar.x * 0.65 + 240.0), -240.0)
	Airplane.crash(_game, from, center, PLANE_DELAY)
	var me := self
	Telegraph.circle(_game, center, radius, PLANE_DELAY, FIRE, func() -> void:
		if is_instance_valid(me) and is_instance_valid(me._game):
			me._plane_impact(center, radius))

func _plane_impact(center: Vector2, radius: float) -> void:
	_boom(center, radius, 60.0)                                  # unchanged: damage + explosion + juice
	Hazard.spawn(_game, center, radius * 0.8, 16.0, 5.0, FIRE)   # unchanged: burning crater
	# --- flash & funny layer (visual only) ---
	Fx.nova(_game, center, radius * 1.25, Color(1.0, 0.85, 0.3)) # second shockwave ring
	Fx.sparks(_game, center, Color(0.55, 0.55, 0.6), 26, radius * 2.4, 0.8)  # flying smoke
	Fx.debris(_game, center, Color(0.5, 0.48, 0.52), 14, radius * 1.7, 0.9)  # a bit of tumbling wreckage
	if _game.hud:
		_game.hud.big_flash("KABOOM!")                           # giant comic centre text
	_game.shake(0.5)                                             # extra kick on top of _boom's 0.6
	Sfx.play("explosion_big")                                    # deep boom — level set in Sfx mix config

func _ev_protestors() -> void:
	var n := rng.randi_range(6, 9)
	for _i in n:
		_game.spawn_monster("protestor", _game._edge_spawn_point(), "neutral")
	Sfx.play("crowd")
	if _game.hud:
		_game.hud.announce("PEASANT REVOLT!")
		_game.hud.squire_say(Lines.pick(Lines.PROTEST_SQUIRE))
		_game.hud.princess_say(Lines.pick(Lines.PROTEST_PRINCESS))

func _ev_infighting() -> void:
	_game.infighting_timer = 6.0
	Sfx.play("infighting")
	if _game.hud:
		_game.hud.announce("INFIGHTING!")
		_game.hud.squire_say(Lines.pick(Lines.INFIGHT_SQUIRE))

func _ev_swarm67() -> void:
	for _i in 67:
		_game.spawn_monster("minion", _game._edge_spawn_point())
	Sfx.play("swarm")
	if _game.hud:
		_game.hud.big_flash("67")
		_game.hud.squire_say(Lines.pick(Lines.SWARM67_SQUIRE))

# --- moving traps (Trap Adventure 2 energy) --------------------------------
## Spawn a random unlocked moving trap. Magnitudes scale with the wave (speed /
## count / spread) but NOT per-tick damage, so late-game traps stay survivable.
func _ev_trap() -> void:
	var w := _game.wave
	var modes := _trap_modes()
	var mode: String = modes[rng.randi() % modes.size()]
	Sfx.play("trap_spawn")
	if _game.hud:
		_game.hud.announce("TRAP!")
		_game.hud.squire_say(Lines.pick(Lines.TRAP_SQUIRE))
	match mode:
		"roller":
			var count := mini(4, 1 + w / 4)
			for _i in count:
				Trap.roller(_game, TROLL, 300.0 + w * 22.0, 34.0, TRAP_COL)
		"spikes":
			Trap.spikes(_game, 4 + w, 30.0, 14.0 + w * 1.5, 3, TROLL, TRAP_COL)
		"laser":
			Trap.laser(_game, TROLL, 150.0 + w * 14.0, 16.0, TRAP_COL)

## Which trap styles are unlocked at the current wave (escalating variety).
func _trap_modes() -> Array:
	var modes := ["roller"]
	if _game.wave >= 2:
		modes.append("spikes")
	if _game.wave >= 3:
		modes.append("laser")
	return modes

# --- the Angel of Retribution ----------------------------------------------
## Karmic punishment for serial sabotage: an angel descends and rains sweeping
## laser beams (which hurt EVERYONE, you included). Triggered from _process when
## cursed_streak crosses ANGEL_STREAK.
func _ev_angel() -> void:
	var w := _game.wave
	Sfx.play("angel")
	if _game.hud:
		_game.hud.announce("DIVINE RETRIBUTION")
		_game.hud.squire_say(Lines.pick(Lines.ANGEL_SQUIRE))
		_game.hud.princess_say(Lines.pick(Lines.ANGEL_PRINCESS))
	_game.shake(0.45)
	var sq := _game.squire
	var at_x: float = sq.global_position.x if (sq and is_instance_valid(sq)) else Game.arena.x * 0.5
	Angel.descend(_game, at_x)
	# Stagger several beams so you scramble to dodge.
	var beams := 3 + w / 3
	for i in beams:
		var idx := i
		var me := self
		_game.get_tree().create_timer(0.5 + i * 0.45).timeout.connect(func() -> void:
			if is_instance_valid(me) and is_instance_valid(me._game) and me._game.phase == "serving":
				me._fire_angel_beam(idx))

func _fire_angel_beam(i: int) -> void:
	var pivot := Game.arena * 0.5
	if i % 2 == 0:
		var dir_sign := 1.0 if (i % 4 == 0) else -1.0          # alternate spin direction
		Trap.laser_spin(_game, pivot, Game.arena.length(), dir_sign * deg_to_rad(160.0),
			PI, 15.0, TROLL, ANGEL_COL, rng.randf() * TAU)
	else:
		Trap.laser(_game, TROLL, 240.0, 16.0, ANGEL_COL)

# --- shared ----------------------------------------------------------------
## One-shot radial blast: damages monsters, Princess AND squire in range, with FX + juice.
func _boom(center: Vector2, radius: float, dmg: float) -> void:
	for n in _game.get_tree().get_nodes_in_group("monsters"):
		var m := n as Monster
		if center.distance_to(m.global_position) <= radius + m.radius:
			m.take_damage(dmg)
	var pr := _game.princess
	if pr and is_instance_valid(pr) and center.distance_to(pr.global_position) <= radius + Princess.RADIUS:
		pr.take_damage(dmg)
	var sq := _game.squire
	if sq and is_instance_valid(sq) and center.distance_to(sq.global_position) <= radius + Squire.RADIUS:
		sq.take_damage(dmg)
	Fx.explosion(_game, center, FIRE, radius)
	_game.shake(0.6)
	_game.hitstop(0.07)
