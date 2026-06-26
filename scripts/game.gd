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
# Loaded by path (not the `IntroScreen` global) so it resolves even before the editor
# has registered the new class — avoids a "class not declared" parse error on first run.
const INTRO_SCREEN = preload("res://scripts/intro.gd")
# Same path-load trick: the story cutscene player (opening + victory), so it resolves
# before the editor has registered the new `Cutscene` class.
const CUTSCENE = preload("res://scripts/cutscene.gd")

# --- pacing / difficulty tuning ---
const FIRST_INTERMISSION := 2.0
const CLEAR_INTERMISSION := 2.5   # short breather — keep the horde coming (was 6.0)
const FIRST_PICKUP_DELAY := 1.5
const PICKUP_INTERVAL := Vector2(0.4, 0.8)   # quick relocation after one is taken
const MAX_PICKUPS := 1                        # Snake-like: one supply on the field at a time
const PICKUP_HARD_CAP := 3                    # ceiling including occasional kill drops
const KILL_DROP_MULT := 0.4                   # kill drops are now rare
# SWARM: big waves that keep the arena packed. MAX_CONCURRENT bounds the LIVE enemy count so the
# screen stays full without melting the single-threaded web build (monster AI/separation is O(n^2)).
const BASE_MONSTERS := 40
const MONSTERS_PER_ROOM := 12
const MAX_CONCURRENT := 42                    # hard ceiling on live enemies on screen at once
const WAVE_HP_GROWTH := 1.16     # monster HP scales EXPONENTIALLY per wave
const WAVE_DMG_GROWTH := 1.09    # monster damage scales exponentially per wave
const BASE_SPAWN_GAP := 0.22
const MIN_SPAWN_GAP := 0.07
const SPAWN_GAP_DECAY := 0.02
const SPAWN_BURST := 7                        # monsters poured in per spawn tick (a horde)
const BOSS_ALLY_BONUS := 4                   # extra defectors that storm in at the betrayal
const BOSS_REINFORCE_INTERVAL := 3.5         # boss: fresh defectors keep arriving...
const BOSS_REINFORCE_COUNT := 2
const BOSS_ALLY_CAP := 14                     # ...up to this cap, so she can never fully wipe them

# --- suspicion economy (RATCHET model: never falls back to zero) ---
# Each sabotage SPIKES suspicion (exponential within a streak) AND raises a permanent
# DOUBT FLOOR. A genuine gift calms suspicion down toward that floor but never below it,
# and a slow ambient CREEP nudges it up over time — so your cover wears thin for good.
const SUSPICION_MAX := 100.0
const SUS_BASE := 8.0       # suspicion from the first sabotage in a streak
const SUS_GROWTH := 1.6     # each consecutive sabotage adds this much MORE (exponential)
const SUS_CREEP := 0.35     # ambient suspicion/sec — slow; idling alone reaches 100 in ~5 min
const FLOOR_PER_SABOTAGE := 4.0   # permanent floor raised per sabotage (~half a fresh spike)
const FLOOR_GROWTH := 1.18        # later sabotages scar the floor a little harder
const FLOOR_CAP := 82.0           # floor ALONE never reaches 100 — betrayal stays earned, not automatic
const CALM_AMOUNT := 26.0         # a genuine gift drains this much, stopping at the floor
const MINOR_SUS := 4.0            # tip-off (E) / scheme (Q): small flat suspicion — they're cooldown-gated
const MINOR_FLOOR := 1.5          # ...and only a slight permanent mark on the floor

# Staged consequences as suspicion climbs (read by the Princess + HUD).
enum Stage { OBLIVIOUS, DOUBT, FRIENDLY_FIRE, BETRAYED }
const STAGE_DOUBT := 0.40   # she starts voicing suspicion ("why aren't you fighting?")
const STAGE_FF := 0.70      # her area attacks "accidentally" start catching you
const BARK_INTERVAL := Vector2(7.0, 11.0)   # spacing of her escalating suspicion barks

# --- runtime state ---
var phase := "serving"            # "serving" | "boss" | "won" | "lost"
var score := 0
var elapsed := 0.0                # seconds of active play (serving + boss); shown as the run timer
var wave := 0
var suspicion := 0.0
var doubt_floor := 0.0           # suspicion can never fall below this; ratchets up with each sabotage
var cursed_streak := 0            # consecutive sabotages since the last genuine gift
var _bark_timer := 6.0           # paces the Princess's escalating suspicion barks
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
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # crisp pixels for the tiled floor in _draw()
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED   # let draw_texture_rect(tile=true) wrap the floor patch
	_load_floor()
	rng.randomize()
	Settings.apply_display()               # re-assert fullscreen/vsync so they survive a restart (R)
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

	# Story cutscene (the amulet + the betrayal) THEN the controls briefing, both shown
	# once per session. The cutscene marks INTRO_SCREEN.seen so a quick R won't replay it.
	# Capture the fresh-run state NOW, BEFORE the cutscene's _ready flips `seen` to true —
	# otherwise the music check below always reads `seen` and never plays the menu theme.
	var fresh_run := not INTRO_SCREEN.seen
	if fresh_run:
		var opening := CUTSCENE.opening()
		opening.finished.connect(_show_intro)
		add_child(opening)

	# Camera centred on the arena keeps the exact current framing (arena == viewport),
	# and lets screen-shake jitter the view via its offset without moving any node.
	_cam = Camera2D.new()
	_cam.position = arena * 0.5
	add_child(_cam)
	_cam.make_current()

	_build_scenery()
	# MUSIC RULE: the calm serving track plays ONLY inside the arena; the menu theme
	# (menu.mp3) scores everything before it — the opening cutscene + the controls briefing.
	# A fresh run shows those, so play the menu theme; IntroScreen._dismiss hands off to the
	# calm track the instant the arena begins. An R-restart skips the cutscene/briefing (intro
	# already `seen`) and drops straight into the arena, so start the calm track immediately.
	if fresh_run:
		Sfx.play_music("menu")       # fresh: menu theme over the cutscene + briefing
	else:
		Sfx.serving_music(0.0)       # restart: the arena begins now -> calm
	queue_redraw()

## Hand off from the opening story cutscene to the controls briefing (both stay paused).
func _show_intro() -> void:
	add_child(INTRO_SCREEN.new())

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
			elapsed += delta
			_serving_process(delta)
			hud.update_state(self)
			if phase == "serving":           # _serving_process may have just tripped the betrayal (-> boss music)
				Sfx.serving_music(suspicion / SUSPICION_MAX)
		"boss":
			elapsed += delta
			_boss_process(delta)
			hud.update_state(self)

# --- phase 1: serving ---
func _serving_process(delta: float) -> void:
	# Ambient creep, clamped up to a freshly-raised floor so you can never sit below
	# your own track record of treachery.
	suspicion = clampf(maxf(suspicion, doubt_floor) + SUS_CREEP * delta, 0.0, SUSPICION_MAX)
	_run_waves(delta)
	_run_pickups(delta)
	_run_suspicion_barks(delta)
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
				# Pour in a burst, but never exceed MAX_CONCURRENT live enemies. As the Princess
				# mows the horde down, room frees up and the wave keeps topping back up — so the
				# arena stays SWARMING instead of draining, while the live count stays bounded.
				var room := MAX_CONCURRENT - _enemies_remaining()
				var burst := mini(mini(SPAWN_BURST, monsters_to_spawn), maxi(room, 0))
				for _i in burst:
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
				hud.announce("The Princess grows stronger!  Lv.%d   +%d Max HP · +%d ATK" %
					[princess.level, int(Princess.LVL_HP_GAIN), int(Princess.LVL_DMG_GAIN)])
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
	Sfx.play_music("suspicion3")            # "she knows" — the dread/final track scores the boss fight
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
	Sfx.stop_music()            # silence the boss track — only the victory sting plays over the end
	Sfx.play("win")
	hud.update_state(self)      # final snapshot — _process stops refreshing once we leave the play phases
	# Victory cutscene (her power stolen → crowned king → the wheel turns) plays over the
	# arena; when it finishes it unpauses and reveals the existing end card beneath it.
	var vic := CUTSCENE.victory(score, wave)
	vic.finished.connect(_after_victory_cutscene)
	add_child(vic)

func _after_victory_cutscene() -> void:
	get_tree().paused = false
	hud.show_end(true, elapsed, wave)

## cause: "queen" if the Princess struck you down (the boss fight), else a witty
## "pointless death". The squire passes this based on the phase it died in.
func lose(cause := "") -> void:
	if phase == "won" or phase == "lost":
		return
	phase = "lost"
	Sfx.stop_music()            # silence the boss track — only the defeat sting plays over the end
	Sfx.play("lose")
	hud.update_state(self)      # final snapshot so the HP pips show the lethal hit (0 left), not a stale 1
	hud.show_end(false, elapsed, wave, cause)

## A sabotage (cursed gift or tip-off) spikes suspicion on an exponential curve AND
## permanently ratchets up the doubt floor — the longer the streak since your last
## genuine gift, the bigger both bites.
func sabotage_suspicion() -> void:
	suspicion = clampf(suspicion + SUS_BASE * pow(SUS_GROWTH, cursed_streak), 0.0, SUSPICION_MAX)
	doubt_floor = minf(FLOOR_CAP, doubt_floor + FLOOR_PER_SABOTAGE * pow(FLOOR_GROWTH, cursed_streak))
	cursed_streak += 1

## A minor stir — tip-off (E) or scheme (Q). They're cooldown-gated, so each only
## nudges suspicion a touch and barely ratchets the floor, and never feeds the streak:
## the exponential + the Angel of Retribution stay reserved for deliberate cursed gifts.
func minor_suspicion() -> void:
	suspicion = clampf(suspicion + MINOR_SUS, 0.0, SUSPICION_MAX)
	doubt_floor = minf(FLOOR_CAP, doubt_floor + MINOR_FLOOR)

## A genuine gift calms her — but only down to the doubt floor, never to zero — and
## resets the streak (so the next spike starts small and the Angel stands down).
func help_calms_suspicion() -> void:
	suspicion = maxf(doubt_floor, suspicion - CALM_AMOUNT)
	cursed_streak = 0

## Which escalation rung the suspicion meter is on (drives Princess behaviour + HUD).
func suspicion_stage() -> int:
	if phase == "boss":
		return Stage.BETRAYED
	var r := suspicion / SUSPICION_MAX
	if r >= STAGE_FF:
		return Stage.FRIENDLY_FIRE
	if r >= STAGE_DOUBT:
		return Stage.DOUBT
	return Stage.OBLIVIOUS

## Periodic Princess barks that escalate with the suspicion stage: she voices growing
## doubt, then openly threatens you once her attacks can catch you.
func _run_suspicion_barks(delta: float) -> void:
	_bark_timer -= delta
	if _bark_timer > 0.0:
		return
	_bark_timer = rng.randf_range(BARK_INTERVAL.x, BARK_INTERVAL.y)
	if not hud:
		return
	match suspicion_stage():
		Stage.DOUBT:
			hud.princess_say(Lines.pick(Lines.DOUBT_PRINCESS))
		Stage.FRIENDLY_FIRE:
			hud.princess_say(Lines.pick(Lines.ACCUSE_PRINCESS))

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

# --- arena floor ---
# Dungeon floor from 0x72 "Dungeon Tileset II" (CC0, vendored under assets/terrain/0x72/).
# PERF: the whole floor is ONE tiled draw call — a pre-baked seamless 256x256 patch
# (floor_patch.png = a 4x4 grid of the 64px tiles, mostly floor_1 with a few cracks, built
# from the editable 16x16 source tiles) drawn with tile=true. The earlier per-cell loop
# issued ~350 textured draws/frame with interleaved textures, which broke 2D batching and
# tanked the framerate on the single-threaded web build. The source 16x16 tiles + the atlas
# still open in Aseprite / Tiled (16px grid) / Godot's TileSet editor; re-bake floor_patch
# from them if you change the mix.
const FLOOR_TINT := Color(0.82, 0.82, 0.9)   # darken + slight cool so the warm brown sits in the moody arena
const FLOOR_PATCH_PATH := "res://assets/terrain/0x72/floor_patch.png"
var _floor_patch: Texture2D

# Scattered skull decorations ("here and there") — 0x72 skull.png (16x16). Positions are
# ARENA-RELATIVE fractions so the scatter spreads to any viewport size and stays put across
# resizes (deterministic, no RNG). Each row: [x_frac, y_frac, scale, flip(1/-1), rot]. The
# centre (where the Princess/Squire start) is kept clear.
const SKULL_TINT := Color(0.72, 0.70, 0.66)   # weathered bone; sits into the dark floor
const SKULL_SPOTS := [
	[0.09, 0.30, 3.6,  1, -0.25], [0.16, 0.66, 2.8, -1,  0.18],
	[0.28, 0.86, 3.2,  1,  0.30], [0.30, 0.18, 2.6, -1, -0.12],
	[0.40, 0.74, 3.0,  1, -0.20], [0.50, 0.88, 3.4, -1,  0.10],
	[0.62, 0.70, 2.7,  1,  0.22], [0.72, 0.30, 3.0, -1, -0.28],
	[0.84, 0.55, 3.5,  1,  0.14], [0.90, 0.82, 2.6, -1, -0.16],
	[0.66, 0.16, 2.8,  1,  0.20], [0.20, 0.46, 2.5, -1,  0.26],
	[0.80, 0.40, 2.9,  1, -0.10],
]
var _skull_tex: Texture2D

func _load_floor() -> void:
	_floor_patch = load(FLOOR_PATCH_PATH) as Texture2D
	_skull_tex = load("res://assets/terrain/0x72/skull.png") as Texture2D

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
	if _floor_patch == null:
		draw_rect(inner, Color(0.16, 0.16, 0.22))   # fallback: flat fill if the patch failed to load
	else:
		draw_texture_rect(_floor_patch, inner, true, FLOOR_TINT)   # ONE tiled draw call (tile=true)
	_draw_decor(inner)
	draw_rect(inner, Color(0.30, 0.29, 0.38), false, 5.0)   # stone-edge border

## Scatter skull decorations across the floor. Drawn from the Game node's own _draw(), so
## they sit BELOW the child nodes (characters/buildings) and get walked over.
func _draw_decor(inner: Rect2) -> void:
	if _skull_tex == null:
		return
	var half := _skull_tex.get_size() * 0.5
	for s in SKULL_SPOTS:
		var pos := inner.position + Vector2(inner.size.x * s[0], inner.size.y * s[1])
		draw_set_transform(pos, s[4], Vector2(s[2] * s[3], s[2]))   # centre, rotate, scale/flip
		draw_texture(_skull_tex, -half, SKULL_TINT)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)   # reset so the border draws untransformed
