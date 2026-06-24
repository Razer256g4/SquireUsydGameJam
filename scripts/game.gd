extends Node2D
class_name Game
## Main controller for "Princess Paladin (Squire's cut)".
## A reversed dungeon crawler: the Princess auto-battles waves of evil; you are
## her measly sidekick, scavenging potions & weapons and getting them to her.

const ARENA_SIZE := Vector2(1152, 648)
const WALL_MARGIN := 28.0

# --- tuning (gameplay pacing/difficulty knobs) ---
const FIRST_INTERMISSION := 2.5         # seconds before room 1 begins
const CLEAR_INTERMISSION := 3.5         # breather after a room is cleared
const FIRST_PICKUP_DELAY := 2.0         # seconds before the first loot drop
const PICKUP_INTERVAL := Vector2(4.0, 7.0)  # random seconds between loot drops
const MAX_PICKUPS := 6                  # cap on loot lying on the floor at once
const BASE_MONSTERS := 4                # monsters in room 1
const MONSTERS_PER_ROOM := 2            # extra monsters per room thereafter
const BASE_SPAWN_GAP := 0.7             # seconds between spawns in room 1
const MIN_SPAWN_GAP := 0.25             # fastest spawn rate (later rooms)
const SPAWN_GAP_DECAY := 0.02           # spawn gap shrinks by this per room

# --- runtime state ---
var state := "playing"          # "playing" | "gameover"
var score := 0
var wave := 0
var monsters_to_spawn := 0
var phase := "intermission"     # "intermission" | "spawning" | "fighting"
var phase_timer := FIRST_INTERMISSION
var spawn_timer := 0.0
var pickup_timer := FIRST_PICKUP_DELAY
var rng := RandomNumberGenerator.new()

var princess: Princess
var squire: Squire
var hud: HUD

func _ready() -> void:
	add_to_group("game")
	rng.randomize()

	princess = Princess.new()
	princess.position = ARENA_SIZE * 0.5
	add_child(princess)

	squire = Squire.new()
	squire.position = ARENA_SIZE * 0.5 + Vector2(0, 90)
	add_child(squire)

	hud = HUD.new()
	add_child(hud)
	hud.announce("Keep up with the Princess! Hand her potions & weapons.")

	_build_scenery()
	queue_redraw()

func _build_scenery() -> void:
	# Tiny Swords buildings as darkened backdrop along the top wall.
	var t := "res://tiny  swords terrain/Buildings/"
	_add_building(t + "Blue Buildings/Castle.png", Vector2(ARENA_SIZE.x * 0.5, WALL_MARGIN + 36.0), 0.55)
	_add_building(t + "Blue Buildings/Tower.png", Vector2(WALL_MARGIN + 60.0, WALL_MARGIN + 30.0), 0.5)
	_add_building(t + "Blue Buildings/Tower.png", Vector2(ARENA_SIZE.x - WALL_MARGIN - 60.0, WALL_MARGIN + 30.0), 0.5)

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
	s.modulate = Color(0.65, 0.65, 0.8, 0.9)   # darkened so it reads as background
	add_child(s)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			get_tree().reload_current_scene()

func _process(delta: float) -> void:
	if state != "playing":
		return

	match phase:
		"intermission":
			phase_timer -= delta
			if phase_timer <= 0.0:
				_start_wave()
		"spawning":
			spawn_timer -= delta
			if spawn_timer <= 0.0 and monsters_to_spawn > 0:
				_spawn_monster()
				monsters_to_spawn -= 1
				spawn_timer = maxf(MIN_SPAWN_GAP, BASE_SPAWN_GAP - wave * SPAWN_GAP_DECAY)
			if monsters_to_spawn <= 0:
				phase = "fighting"
		"fighting":
			if get_tree().get_nodes_in_group("monsters").is_empty():
				phase = "intermission"
				phase_timer = CLEAR_INTERMISSION
				hud.announce("Room %d cleared!" % wave)

	# Periodic loot drops so the squire always has something to fetch.
	pickup_timer -= delta
	if pickup_timer <= 0.0:
		if get_tree().get_nodes_in_group("pickups").size() < MAX_PICKUPS:
			_spawn_pickup(_weighted_pickup_kind(), _random_inner_point())
		pickup_timer = rng.randf_range(PICKUP_INTERVAL.x, PICKUP_INTERVAL.y)

	hud.update_state(self)

func _start_wave() -> void:
	wave += 1
	monsters_to_spawn = BASE_MONSTERS + wave * MONSTERS_PER_ROOM
	spawn_timer = 0.0
	phase = "spawning"
	hud.announce("Room %d" % wave)

func _spawn_monster() -> void:
	var m := Monster.new()
	m.kind = _weighted_monster_kind()
	m.position = _edge_spawn_point()
	add_child(m)
	m.configure(wave)

func _spawn_pickup(kind: String, pos: Vector2) -> void:
	var p := Pickup.new()
	p.kind = kind
	p.position = pos
	add_child(p)

func on_monster_killed(m: Monster) -> void:
	score += m.score_value
	# Tougher monsters are more likely to drop something useful.
	if rng.randf() < m.drop_chance:
		_spawn_pickup(_weighted_pickup_kind(), clamp_to_arena(m.global_position, Pickup.RADIUS))

func game_over() -> void:
	if state == "gameover":
		return
	state = "gameover"
	hud.show_gameover(score, wave)

# --- helpers ---
func _weighted_monster_kind() -> String:
	var r := rng.randf()
	# More brutes/scouts appear in later rooms.
	var brute_w: float = min(0.30, 0.05 + wave * 0.02)
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
		0: return Vector2(rng.randf_range(inner, ARENA_SIZE.x - inner), inner)
		1: return Vector2(rng.randf_range(inner, ARENA_SIZE.x - inner), ARENA_SIZE.y - inner)
		2: return Vector2(inner, rng.randf_range(inner, ARENA_SIZE.y - inner))
		_: return Vector2(ARENA_SIZE.x - inner, rng.randf_range(inner, ARENA_SIZE.y - inner))

func _random_inner_point() -> Vector2:
	var pad := WALL_MARGIN + 60.0
	return Vector2(
		rng.randf_range(pad, ARENA_SIZE.x - pad),
		rng.randf_range(pad, ARENA_SIZE.y - pad))

static func clamp_to_arena(pos: Vector2, r: float) -> Vector2:
	return Vector2(
		clamp(pos.x, WALL_MARGIN + r, ARENA_SIZE.x - WALL_MARGIN - r),
		clamp(pos.y, WALL_MARGIN + r, ARENA_SIZE.y - WALL_MARGIN - r))

func _draw() -> void:
	# Floor
	draw_rect(Rect2(Vector2.ZERO, ARENA_SIZE), Color(0.10, 0.10, 0.14))
	var inner := Rect2(Vector2(WALL_MARGIN, WALL_MARGIN),
		ARENA_SIZE - Vector2(WALL_MARGIN * 2.0, WALL_MARGIN * 2.0))
	draw_rect(inner, Color(0.16, 0.16, 0.22))
	# Grid for depth
	var step := 64.0
	var x := WALL_MARGIN
	while x < ARENA_SIZE.x - WALL_MARGIN:
		draw_line(Vector2(x, WALL_MARGIN), Vector2(x, ARENA_SIZE.y - WALL_MARGIN), Color(1, 1, 1, 0.025), 1.0)
		x += step
	var y := WALL_MARGIN
	while y < ARENA_SIZE.y - WALL_MARGIN:
		draw_line(Vector2(WALL_MARGIN, y), Vector2(ARENA_SIZE.x - WALL_MARGIN, y), Color(1, 1, 1, 0.025), 1.0)
		y += step
	# Dungeon wall
	draw_rect(inner, Color(0.40, 0.34, 0.5), false, 5.0)
