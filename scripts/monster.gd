extends Actor
class_name Monster
## Orcs. In phase 1 they besiege the Princess (scouts also harass the Squire).
## Tipping off the enemy (E) ENRAGES them. When the Princess discovers the betrayal
## every monster DEFECTS (faction "ally") and turns its fury on her.
##   grunt - standard, chases the Princess
##   scout - fast, fragile, harasses the Squire
##   brute - big, very tanky, very painful; best loot

const ALLY_TINT := Color(0.5, 0.8, 1.0)
const ENRAGED_TINT := Color(1.0, 0.55, 0.2)
const NEUTRAL_TINT := Color(0.75, 0.7, 0.55)   # peasants — drab, not-a-monster colour

# Placeholders only; configure() overwrites every stat (and makes the sprite).
var kind := "grunt"
var hp := 30.0
var max_hp := 30.0
var speed := 60.0
var damage := 8.0
var attack_cd := 1.0
var radius := 16.0
var scale_f := 0.6
var tint := Color.WHITE
var prefers_squire := false
var score_value := 10
var drop_chance := 0.18
var lifetime := 0.0             # >0 = self-despawns after this many seconds (gag minions)

var faction := "enemy"          # "enemy" | "ally" | "neutral"
var enraged := false

var _cd := 0.0
var _flash := 0.0
var _anim_lock := 0.0
var _dead := false
var _overlay_y := 0.0
var _game: Game

# hit-pop (juice): a brief scale punch when struck. Kept per-class (not on Actor)
# so it doesn't trip GDScript's cyclic base-member resolution. Uses inherited _spr.
var _pop := 0.0
var _base_scale := Vector2.ONE

func _pop_hit() -> void:
	_pop = 1.0

func _tick_pop(delta: float) -> void:
	if _spr == null:
		return
	if _pop > 0.0:
		_pop = maxf(0.0, _pop - delta * 6.0)
		_spr.scale = _base_scale * (1.0 + 0.18 * _pop)
	elif _spr.scale != _base_scale:
		_spr.scale = _base_scale

func _ready() -> void:
	add_to_group("monsters")
	z_index = 4
	_game = get_tree().get_first_node_in_group("game") as Game

func configure(wave: int) -> void:
	match kind:
		"scout":
			max_hp = 18.0; speed = 135.0; damage = 6.0; attack_cd = 0.8
			radius = 24.0; scale_f = 3.4; tint = Color(0.7, 0.95, 1.0); prefers_squire = true
			score_value = 12; drop_chance = 0.12
		"brute":
			max_hp = 95.0; speed = 42.0; damage = 18.0; attack_cd = 1.3
			radius = 46.0; scale_f = 5.8; tint = Color(1.0, 0.6, 0.55); prefers_squire = false
			score_value = 30; drop_chance = 0.45
		"vampire":   # gothic elite: tanky, fast, cape-flowing idle, lunge attack
			max_hp = 70.0; speed = 92.0; damage = 13.0; attack_cd = 0.9
			radius = 28.0; scale_f = 0.12; tint = Color.WHITE; prefers_squire = false
			score_value = 26; drop_chance = 0.38
		"banshee":   # wave 3+ spectral screamer: fast, ethereal, terrifying wail
			max_hp = 60.0; speed = 110.0; damage = 14.0; attack_cd = 1.3
			radius = 26.0; scale_f = 0.1; tint = Color(0.85, 0.9, 1.0); prefers_squire = false
			score_value = 28; drop_chance = 0.35
		"werewolf":  # wave 2+ pack hunter: fast, medium HP, pounces hard
			max_hp = 55.0; speed = 105.0; damage = 11.0; attack_cd = 1.0
			radius = 28.0; scale_f = 0.15; tint = Color(0.75, 0.6, 0.9); prefers_squire = false
			score_value = 22; drop_chance = 0.32
		"minion":   # the "67" gag swarm: tiny, weak, fast, despawns on its own
			max_hp = 6.0; speed = 150.0; damage = 3.0; attack_cd = 0.7
			radius = 14.0; scale_f = 2.2; tint = Color(0.95, 0.8, 1.0); prefers_squire = false
			score_value = 1; drop_chance = 0.0; lifetime = 9.0
		"protestor":   # peasant revolt: marches on the Princess, harasses, then disperses
			max_hp = 40.0; speed = 72.0; damage = 4.0; attack_cd = 1.2
			radius = 28.0; scale_f = 3.6; tint = NEUTRAL_TINT; prefers_squire = false
			score_value = 5; drop_chance = 0.0; lifetime = 22.0
		_: # grunt
			max_hp = 32.0; speed = 58.0; damage = 9.0; attack_cd = 1.0
			radius = 32.0; scale_f = 4.2; tint = Color.WHITE; prefers_squire = false
			score_value = 10; drop_chance = 0.18
	max_hp *= pow(Game.WAVE_HP_GROWTH, wave)     # exponential difficulty curve
	damage *= pow(Game.WAVE_DMG_GROWTH, wave)
	hp = max_hp

	# Protestors are people, not monsters — use the human (Soldier) sheet. The
	# Soldier body sits slightly higher in its 100px frame than the Orc, so its
	# overlay row uses the same content-top (39) the Princess/Squire do.
	var human := kind == "protestor"
	_spr = AnimatedSprite2D.new()
	if kind == "vampire":
		_spr.sprite_frames = Anim.vampire()
	elif kind == "banshee":
		_spr.sprite_frames = Anim.banshee()
	elif kind == "werewolf":
		_spr.sprite_frames = Anim.werewolf()
	elif human:
		_spr.sprite_frames = Anim.soldier()
	else:
		_spr.sprite_frames = Anim.orc()
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.scale = Vector2(scale_f, scale_f)
	_spr.offset = Vector2(0, -6)        # feet sit on the node origin
	_spr.z_index = -1
	_spr.modulate = tint
	add_child(_spr)
	_base_scale = Vector2(scale_f, scale_f)
	_play("idle")
	# Non-standard frame heights: compute overlay_y directly instead of using FRAME_CENTER=50.
	if kind == "werewolf":
		_overlay_y = -(scale_f * 768.0 * 0.50) - 8.0
	elif kind == "banshee":
		_overlay_y = -(scale_f * 724.0 * 0.45) - 8.0
	elif kind == "vampire":
		_overlay_y = -(scale_f * 724.0 * 0.45) - 8.0
	else:
		_overlay_y = overlay_y(10.0 if kind == "vampire" else (39.0 if human else 42.0), scale_f)

func _process(delta: float) -> void:
	if _game and _game.phase != "serving" and _game.phase != "boss":
		return
	if _dead:
		return

	# Gag minions tidy themselves up so the "67" swarm doesn't linger.
	if lifetime > 0.0:
		lifetime -= delta
		if lifetime <= 0.0:
			remove_from_group("monsters")
			queue_free()
			return

	_cd = _decay(_cd, delta)
	_flash = _decay(_flash, delta)
	_anim_lock = _decay(_anim_lock, delta)
	_tick_pop(delta)
	if _spr:
		_spr.modulate = Color.WHITE if _flash > 0.0 else _base_tint()

	var moved := false
	var target := _choose_target()
	if target:
		var to_t: Vector2 = target.global_position - global_position
		var dist := to_t.length()
		_facing = to_t / maxf(dist, 0.001)
		var reach: float = radius + _target_radius(target) + 2.0
		if dist > reach:
			position += _facing * speed * delta
			position += _separation() * delta
			position = Game.clamp_to_arena(position, radius)
			moved = true
		elif _cd <= 0.0:
			target.take_damage(damage)
			_cd = attack_cd
			_play("attack")
			_anim_lock = 0.35

	_update_flip()
	if _anim_lock <= 0.0:
		_play("walk" if moved else "idle")
	queue_redraw()

func _choose_target() -> Actor:
	var princess := get_tree().get_first_node_in_group("princess") as Princess
	var squire := get_tree().get_first_node_in_group("squire") as Squire
	if faction == "ally":
		return princess          # defectors only ever attack the Princess
	if faction == "neutral":
		return princess          # protestors march on the Princess (she can't hit them back)
	# infighting event: the enemy horde turns on itself for a while
	if _game and _game.infighting_timer > 0.0:
		var other := _nearest_other_enemy()
		if other:
			return other
	# enemy: scouts harass the squire until enraged; everyone else mobs the Princess
	if not enraged and prefers_squire and squire and is_instance_valid(squire) \
			and _game and _game.phase == "serving":
		return squire
	return princess if princess else squire

func _nearest_other_enemy() -> Monster:
	var best: Monster = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("monsters"):
		var m := n as Monster
		if m == self or m._dead or m.faction != "enemy":
			continue
		var d: float = global_position.distance_squared_to(m.global_position)
		if d < best_d:
			best_d = d
			best = m
	return best

func _target_radius(t: Actor) -> float:
	if t is Princess: return Princess.RADIUS
	if t is Squire: return Squire.RADIUS
	if t is Monster: return (t as Monster).radius
	return 14.0

func _separation() -> Vector2:
	var push := Vector2.ZERO
	for o in get_tree().get_nodes_in_group("monsters"):
		if o == self:
			continue
		var diff: Vector2 = global_position - o.global_position
		var d := diff.length()
		if d > 0.01 and d < radius + 8.0:
			push += diff / d * (radius + 8.0 - d) * 6.0
	return push

## Tip-off / rally: become faster and hit harder.
func enrage() -> void:
	if enraged:
		return
	enraged = true
	speed *= 1.4
	damage *= 1.5

## Switch sides at the betrayal: now fight FOR the squire, against the Princess.
func defect() -> void:
	faction = "ally"
	tint = ALLY_TINT
	if _spr:
		_spr.modulate = ALLY_TINT

## Put this monster on a non-default faction (used by event spawns). Re-tints it.
func set_faction(f: String) -> void:
	faction = f
	match f:
		"ally": tint = ALLY_TINT
		"neutral": tint = NEUTRAL_TINT
	if _spr:
		_spr.modulate = tint

func take_damage(d: float) -> void:
	if _dead:
		return
	hp -= d
	_flash = 0.1
	_pop_hit()
	if hp <= 0.0:
		_die()
	else:
		_play("hurt")
		_anim_lock = 0.2

func _die() -> void:
	_dead = true
	remove_from_group("monsters")
	if _game:
		_game.on_monster_killed(self)
		Fx.sparks(_game, global_position, _base_tint(), 14, 110.0, 0.5)
	if _spr:
		_spr.modulate = _base_tint()
		_play("death")
	queue_redraw()
	await get_tree().create_timer(0.45).timeout
	if is_instance_valid(self):
		queue_free()

func _base_tint() -> Color:
	return ENRAGED_TINT if enraged else tint

func _draw() -> void:
	if _dead:
		return
	if hp < max_hp:
		var w := radius * 1.8
		var top := Vector2(-w * 0.5, _overlay_y)
		draw_rect(Rect2(top, Vector2(w, 5)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(top, Vector2(w * clampf(hp / max_hp, 0.0, 1.0), 5)), Color(0.9, 0.3, 0.3))
	if kind == "protestor":
		# a little raised protest placard so the crowd reads as peasants, not orcs
		var sy := _overlay_y - 18.0
		draw_line(Vector2(8, sy + 26), Vector2(8, sy), Color(0.5, 0.35, 0.2), 3.0)
		draw_rect(Rect2(Vector2(-6, sy - 14), Vector2(28, 16)), Color(0.95, 0.92, 0.8))
		draw_rect(Rect2(Vector2(-6, sy - 14), Vector2(28, 16)), Color(0.2, 0.15, 0.1), false, 1.5)
		draw_line(Vector2(-2, sy - 9), Vector2(20, sy - 9), Color(0.2, 0.15, 0.1), 1.5)
		draw_line(Vector2(-2, sy - 4), Vector2(14, sy - 4), Color(0.2, 0.15, 0.1), 1.5)
