extends Node2D
class_name Game
## "Royal Assistant" — the Squire's betrayal.
##
## PHASE 1 "serving": the overpowered Princess auto-battles waves of monsters.
## You PRETEND to be her loyal squire while secretly sabotaging her — handing her
## cursed potions/weapons and tipping off the enemy. Sabotage raises SUSPICION and
## weakens her; genuine help lowers suspicion. At 100% suspicion she discovers the
## betrayal.
## PHASE 2 "boss": she turns on you. The surviving monsters, whom you've been
## feeding intel all game, defect and fight at your side. Her remaining strength is
## exactly whatever you left her — so every sabotage in phase 1 pays off here.

## The playable area. DYNAMIC: set to the live viewport size at runtime (so the
## arena fills the browser canvas, whatever size it is). 1600x900 is just the
## initial/fallback. Everything (HUD, spawns, clamps, scenery, floor) derives from it.
static var arena := Vector2(1600, 900)
const WALL_MARGIN := 28.0

# --- pacing / difficulty tuning ---
const FIRST_INTERMISSION := 3.5
const CLEAR_INTERMISSION := 6.0   # longer breather between waves (time for banter + setup)
const FIRST_PICKUP_DELAY := 1.5
const PICKUP_INTERVAL := Vector2(0.4, 0.8)   # quick relocation after one is taken
const MAX_PICKUPS := 1                        # Snake-like: one supply on the field at a time
const PICKUP_HARD_CAP := 3                    # ceiling including occasional kill drops
const KILL_DROP_MULT := 0.4                   # kill drops are now rare
const BASE_MONSTERS := 9
const MONSTERS_PER_ROOM := 4
const WAVE_HP_GROWTH := 1.16     # monster HP scales EXPONENTIALLY per wave
const WAVE_DMG_GROWTH := 1.09    # monster damage scales exponentially per wave
const BASE_SPAWN_GAP := 0.4
const MIN_SPAWN_GAP := 0.12
const SPAWN_GAP_DECAY := 0.02
const SPAWN_BURST := 3                       # monsters poured in per spawn tick (a horde)
const BOSS_ALLY_BONUS := 4                   # extra defectors that storm in at the betrayal
const BOSS_REINFORCE_INTERVAL := 3.5         # boss: fresh defectors keep arriving...
const BOSS_REINFORCE_COUNT := 2
const BOSS_ALLY_CAP := 14                     # ...up to this cap, so she can never fully wipe them

# --- suspicion economy (EXPONENTIAL: consecutive sabotage spikes fast; a single
#     genuine gift RESETS it to zero) ---
const SUSPICION_MAX := 100.0
const SUS_BASE := 8.0       # suspicion from the first sabotage in a streak
const SUS_GROWTH := 1.6     # each consecutive sabotage adds this much MORE (exponential)

# --- runtime state ---
var phase := "serving"            # "serving" | "boss" | "won" | "lost"
var score := 0
var wave := 0
var suspicion := 0.0
var cursed_streak := 0            # consecutive sabotages since the last genuine gift
var monsters_to_spawn := 0
var wave_state := "intermission"  # "intermission" | "spawning" | "fighting" (serving only)
var phase_timer := FIRST_INTERMISSION
var spawn_timer := 0.0
var pickup_timer := FIRST_PICKUP_DELAY
var boss_reinforce_timer := BOSS_REINFORCE_INTERVAL
var rng := RandomNumberGenerator.new()

var infighting_timer := 0.0       # >0 while the horde brawls itself (infighting event)

var princess: Princess
var squire: Squire
var hud: HUD
var event_director: EventDirector

# --- juice ---
var _shake := 0.0                 # screen-shake trauma 0..1 (drives the camera offset)
var _hitstop := false
var _cam: Camera2D                # shakes the VIEW only, so node coordinates stay intact

func _ready() -> void:
	add_to_group("game")
	rng.randomize()
	arena = get_viewport_rect().size       # fit the playable area to the actual canvas

	princess = Princess.new()
	princess.position = arena * 0.5
	add_child(princess)

	squire = Squire.new()
	squire.position = arena * 0.5 + Vector2(0, 110)
	add_child(squire)

	hud = HUD.new()
	add_child(hud)
	hud.announce("Serve the Princess... faithfully.")

	event_director = EventDirector.new()
	add_child(event_director)

	add_child(PauseMenu.new())

	# Camera centred on the arena keeps the exact current framing (arena == viewport),
	# and lets screen-shake jitter the view via its offset without moving any node.
	_cam = Camera2D.new()
	_cam.position = arena * 0.5
	add_child(_cam)
	_cam.make_current()

	_build_scenery()
	Sfx.play_music("serving")    # loops assets/audio/music/serving.ogg if present (silent otherwise)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_tree().reload_current_scene()

func _process(delta: float) -> void:
	# Keep the playable area matched to the (possibly resized) browser canvas.
	# (compare against the live position-free size so screen-shake offset is ignored)
	var vp := get_viewport_rect().size
	if vp != arena:
		arena = vp
		if _cam:
			_cam.position = arena * 0.5
		_rebuild_scenery()
		queue_redraw()

	infighting_timer = maxf(0.0, infighting_timer - delta)
	_update_shake(delta)

	match phase:
		"serving":
			_serving_process(delta)
			hud.update_state(self)
		"boss":
			_boss_process(delta)
			hud.update_state(self)

# --- phase 1: serving ---
func _serving_process(delta: float) -> void:
	_run_waves(delta)
	_run_pickups(delta)
	if suspicion >= SUSPICION_MAX:
		_betray()

func _run_waves(delta: float) -> void:
	match wave_state:
		"intermission":
			phase_timer -= delta
			if phase_timer <= 0.0:
				_start_wave()
		"spawning":
			spawn_timer -= delta
			if spawn_timer <= 0.0 and monsters_to_spawn > 0:
				for _i in mini(SPAWN_BURST, monsters_to_spawn):
					_spawn_enemy()
					monsters_to_spawn -= 1
				spawn_timer = maxf(MIN_SPAWN_GAP, BASE_SPAWN_GAP - wave * SPAWN_GAP_DECAY)
			if monsters_to_spawn <= 0:
				wave_state = "fighting"
		"fighting":
			# Only the wave's real enemies gate completion — event spawns (neutral
			# protestors, "67" minions) must NOT keep the wave open or it soft-locks.
			if _enemies_remaining() == 0:
				wave_state = "intermission"
				phase_timer = CLEAR_INTERMISSION
				Sfx.play("wave_clear")
				princess.level_up()
				hud.announce("The Princess grows stronger... (Lv.%d)" % princess.level)
				_wave_banter()

func _run_pickups(delta: float) -> void:
	pickup_timer -= delta
	if pickup_timer <= 0.0:
		if get_tree().get_nodes_in_group("pickups").size() < MAX_PICKUPS:
			_spawn_pickup(_weighted_pickup_kind(), _random_inner_point())
		pickup_timer = rng.randf_range(PICKUP_INTERVAL.x, PICKUP_INTERVAL.y)

func _start_wave() -> void:
	wave += 1
	monsters_to_spawn = BASE_MONSTERS + wave * MONSTERS_PER_ROOM
	spawn_timer = 0.0
	wave_state = "spawning"
	Sfx.play("wave_start")
	hud.announce("Wave %d" % wave)

## A witty princess/squire exchange between waves — gives the betrayal story room
## to breathe (paired by index in Lines, so the reply matches her line).
func _wave_banter() -> void:
	if not hud or Lines.INTERLUDE_PRINCESS.size() == 0:
		return
	var i := rng.randi() % Lines.INTERLUDE_PRINCESS.size()
	hud.princess_say(Lines.INTERLUDE_PRINCESS[i])
	hud.squire_say(Lines.INTERLUDE_SQUIRE[i])

# --- phase 2: boss ---
func _betray() -> void:
	phase = "boss"
	Sfx.play("betray_sting")                # deep WHOOM under her "TRAITOR!" roar (level in mix config)
	Sfx.play_music("boss")                  # swap to assets/audio/music/boss.ogg if present
	princess.become_boss()
	# Every surviving monster defects to your side...
	for m in get_tree().get_nodes_in_group("monsters"):
		(m as Monster).defect()
	# ...and reinforcements storm in to help bring her down.
	for _i in BOSS_ALLY_BONUS:
		var m := _spawn_enemy()
		m.defect()
	hud.betray()

func _boss_process(delta: float) -> void:
	if not is_instance_valid(princess) or princess.hp <= 0.0:
		win()
		return
	# Fresh defectors keep storming in, so the Princess can mow down the horde around
	# her while chasing you without ever fully clearing your army (which would soft-lock).
	boss_reinforce_timer -= delta
	if boss_reinforce_timer <= 0.0:
		boss_reinforce_timer = BOSS_REINFORCE_INTERVAL
		if get_tree().get_nodes_in_group("monsters").size() < BOSS_ALLY_CAP:
			for _i in BOSS_REINFORCE_COUNT:
				var m := _spawn_enemy()
				m.defect()

# --- outcomes ---
func win() -> void:
	if phase == "won" or phase == "lost":
		return
	phase = "won"
	Sfx.play("win")
	hud.update_state(self)      # final snapshot — _process stops refreshing once we leave the play phases
	hud.show_end(true, score, wave)

func lose() -> void:
	if phase == "won" or phase == "lost":
		return
	phase = "lost"
	Sfx.play("lose")
	hud.update_state(self)      # final snapshot so the HP pips show the lethal hit (0 left), not a stale 1
	hud.show_end(false, score, wave)

## A sabotage (cursed gift or tip-off) raises suspicion on an exponential curve:
## the longer the streak since your last genuine gift, the bigger each spike.
func sabotage_suspicion() -> void:
	suspicion = clampf(suspicion + SUS_BASE * pow(SUS_GROWTH, cursed_streak), 0.0, SUSPICION_MAX)
	cursed_streak += 1

## A genuine gift fully allays her suspicion and resets the streak.
func help_resets_suspicion() -> void:
	suspicion = 0.0
	cursed_streak = 0

func on_monster_killed(m: Monster) -> void:
	score += m.score_value
	# Occasional, bounded kill drops; the steady supply is the single relocating pickup.
	if get_tree().get_nodes_in_group("pickups").size() < PICKUP_HARD_CAP and rng.randf() < m.drop_chance * KILL_DROP_MULT:
		_spawn_pickup(_weighted_pickup_kind(), clamp_to_arena(m.global_position, Pickup.RADIUS))

# --- spawning helpers ---
func _spawn_enemy() -> Monster:
	return spawn_monster(_weighted_monster_kind(), _edge_spawn_point())

## Spawn one monster of `kind` at `pos`, optionally on a non-enemy faction
## ("neutral" protestors, "ally" defectors). Used by the wave loop AND the
## EventDirector. configure() builds the sprite/stats first; faction tints after.
func spawn_monster(kind: String, pos: Vector2, fac := "enemy") -> Monster:
	var m := Monster.new()
	m.kind = kind
	m.position = pos
	add_child(m)
	m.configure(wave)
	if fac != "enemy":
		m.set_faction(fac)
	return m

## Real wave enemies still standing (excludes neutral protestors and gag minions).
func _enemies_remaining() -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("monsters"):
		var m := node as Monster
		if m.faction == "enemy" and m.kind != "minion":
			n += 1
	return n

func _spawn_pickup(kind: String, pos: Vector2) -> void:
	var p := Pickup.new()
	p.kind = kind
	p.position = pos
	add_child(p)

func _weighted_monster_kind() -> String:
	var r := rng.randf()
	var brute_w: float = minf(0.30, 0.05 + wave * 0.02)
	var scout_w := 0.35
	if r < brute_w:
		return "brute"
	elif r < brute_w + scout_w:
		return "scout"
	return "grunt"

func _weighted_pickup_kind() -> String:
	return "potion" if rng.randf() < 0.55 else "weapon"

func _edge_spawn_point() -> Vector2:
	var inner := WALL_MARGIN + 16.0
	match rng.randi_range(0, 3):
		0: return Vector2(rng.randf_range(inner, arena.x - inner), inner)
		1: return Vector2(rng.randf_range(inner, arena.x - inner), arena.y - inner)
		2: return Vector2(inner, rng.randf_range(inner, arena.y - inner))
		_: return Vector2(arena.x - inner, rng.randf_range(inner, arena.y - inner))

func _random_inner_point() -> Vector2:
	var pad := WALL_MARGIN + 60.0
	return Vector2(
		rng.randf_range(pad, arena.x - pad),
		rng.randf_range(pad, arena.y - pad))

static func clamp_to_arena(pos: Vector2, r: float) -> Vector2:
	return Vector2(
		clamp(pos.x, WALL_MARGIN + r, arena.x - WALL_MARGIN - r),
		clamp(pos.y, WALL_MARGIN + r, arena.y - WALL_MARGIN - r))

# --- juice: screen shake + hit-stop ---
## Add trauma (0..1). The world (this root Node2D) jitters; the HUD CanvasLayer
## is unaffected. Gated by the pause-menu toggle.
func shake(amount: float) -> void:
	if not Settings.screen_shake:
		return
	_shake = clampf(_shake + amount, 0.0, 1.0)

func _update_shake(delta: float) -> void:
	if _cam == null:
		return
	if _shake <= 0.0:
		if _cam.offset != Vector2.ZERO:
			_cam.offset = Vector2.ZERO
		return
	_shake = maxf(0.0, _shake - delta * 1.6)
	var mag := _shake * _shake * 20.0       # trauma² feels punchier than linear
	_cam.offset = Vector2(rng.randf_range(-mag, mag), rng.randf_range(-mag, mag))

## Briefly slow time on a big impact, then snap back. The restore timer ignores
## time_scale so the freeze lasts a real `secs`. Gated by the pause-menu toggle.
func hitstop(secs := 0.06) -> void:
	if not Settings.hit_stop or _hitstop:
		return
	_hitstop = true
	Engine.time_scale = 0.05
	await get_tree().create_timer(secs, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop = false

# --- scenery ---
func _rebuild_scenery() -> void:
	for s in get_tree().get_nodes_in_group("scenery"):
		s.queue_free()
	_build_scenery()

func _build_scenery() -> void:
	var t := "res://tiny  swords terrain/Buildings/"
	_add_building(t + "Blue Buildings/Castle.png", Vector2(arena.x * 0.5, WALL_MARGIN + 50.0), 0.8)
	_add_building(t + "Blue Buildings/Tower.png", Vector2(WALL_MARGIN + 80.0, WALL_MARGIN + 40.0), 0.7)
	_add_building(t + "Blue Buildings/Tower.png", Vector2(arena.x - WALL_MARGIN - 80.0, WALL_MARGIN + 40.0), 0.7)

func _add_building(path: String, pos: Vector2, sc: float) -> void:
	var tex := load(path) as Texture2D
	if tex == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = pos
	s.scale = Vector2(sc, sc)
	s.z_index = 1
	s.modulate = Color(0.65, 0.65, 0.8, 0.9)
	s.add_to_group("scenery")
	add_child(s)

func _draw() -> void:
	# Over-draw the backdrop by a margin so screen-shake never reveals a gap at the edge.
	draw_rect(Rect2(Vector2(-48, -48), arena + Vector2(96, 96)), Color(0.10, 0.10, 0.14))
	var inner := Rect2(Vector2(WALL_MARGIN, WALL_MARGIN),
		arena - Vector2(WALL_MARGIN * 2.0, WALL_MARGIN * 2.0))
	draw_rect(inner, Color(0.16, 0.16, 0.22))
	var step := 64.0
	var x := WALL_MARGIN
	while x < arena.x - WALL_MARGIN:
		draw_line(Vector2(x, WALL_MARGIN), Vector2(x, arena.y - WALL_MARGIN), Color(1, 1, 1, 0.025), 1.0)
		x += step
	var y := WALL_MARGIN
	while y < arena.y - WALL_MARGIN:
		draw_line(Vector2(WALL_MARGIN, y), Vector2(arena.x - WALL_MARGIN, y), Color(1, 1, 1, 0.025), 1.0)
		y += step
	draw_rect(inner, Color(0.40, 0.34, 0.5), false, 5.0)
