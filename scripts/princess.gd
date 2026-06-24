extends Actor
class_name Princess
## The overpowered Princess. In phase 1 she auto-battles the waves and obliviously
## thanks you for every "gift". Your cursed items quietly stack debuffs on her
## (poison, lost max HP, weaker attacks) that persist into the boss fight. When the
## Suspicion meter fills she becomes hostile (become_boss) and hunts the Squire,
## while the defected monsters tear into her.

const RADIUS := 32.0
const SCALE := 5.0
const SPEED := 150.0
const BOSS_SPEED := 175.0

# --- cursed-item effects ---
const CURSE_POISON := 7.0     # poison damage/sec added per cursed potion
const CURSE_HP_PEN := 45.0    # max-HP lost per cursed potion
const CURSE_SIP := 18.0       # immediate damage when she drinks a cursed potion
const CURSE_REGEN := 0.25     # self-heal multiplier lost per cursed potion
const CURSE_POWER := 0.14     # attack multiplier lost per cursed weapon
const GENUINE_HEAL := 70.0
const GENUINE_POWER := 0.05

# --- flashy abilities (phase 1), each on its own cooldown ---
const METEOR_CD := 5.0       # heavy AoE bomb dropped on the thickest part of the horde
const METEOR_RADIUS := 160.0
const METEOR_POWER := 3.2    # x base_damage
const NOVA_CD := 7.0         # holy burst centred on her, clears anything hugging her
const NOVA_RADIUS := 140.0
const NOVA_POWER := 1.7
const SMITE_CD := 3.5        # chain lightning to the nearest few
const SMITE_TARGETS := 4
const SMITE_POWER := 1.5
const FIRE := Color(1.0, 0.55, 0.12)
const HOLY := Color(1.0, 0.92, 0.45)
const ARC := Color(0.6, 0.85, 1.0)

const THANKS := [
	"Thanks, faithful servant!", "You always know best!",
	"What would I do without you?", "Such a loyal squire.", "Bless you, dear squire.",
]
const SUSPICIOUS := [
	"Hm... this tastes odd.", "Are you quite sure about this?",
	"Something feels... off.", "You seem nervous, squire.",
]

# base (already OP) stats; grow with level
var level := 1
var max_hp := 320.0
var hp := 320.0
var base_damage := 24.0
var attack_range := 95.0
var base_attack_cd := 0.6
var regen := 9.0

# sabotage debuffs (persist into the boss)
var power_mult := 1.0
var regen_mult := 1.0
var poison_dps := 0.0
var hp_penalty := 0.0

var hostile := false

var _cd := 0.0
var _anim_lock := 0.0
var _flash := 0.0
var _flash_col := Color.RED
var _nuke_cd := 0.0
var _meteor_cd := 1.5
var _nova_cd := 3.0
var _smite_cd := 2.0
var _dead := false
var _overlay_y := 0.0
var _game: Game

func _ready() -> void:
	add_to_group("princess")
	z_index = 8
	_game = get_tree().get_first_node_in_group("game") as Game

	_spr = AnimatedSprite2D.new()
	_spr.sprite_frames = Anim.soldier()
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.scale = Vector2(SCALE, SCALE)
	_spr.offset = Vector2(0, -6)        # feet sit on the node origin
	_spr.z_index = -1
	add_child(_spr)
	_play("idle")
	_overlay_y = overlay_y(39.0, SCALE)

func _process(delta: float) -> void:
	if _dead:
		queue_redraw()
		return
	if _game and _game.phase != "serving" and _game.phase != "boss":
		return

	_cd = _decay(_cd, delta)
	_anim_lock = _decay(_anim_lock, delta)
	_flash = _decay(_flash, delta)
	_nuke_cd = _decay(_nuke_cd, delta)
	_meteor_cd = _decay(_meteor_cd, delta)
	_nova_cd = _decay(_nova_cd, delta)
	_smite_cd = _decay(_smite_cd, delta)

	if poison_dps > 0.0:
		hp -= poison_dps * delta
		if hp <= 0.0:
			_on_death()
			return

	_spr.modulate = _flash_col if _flash > 0.0 else _base_modulate()

	var moved := _boss_step(delta) if hostile else _serving_step(delta)

	_update_flip()
	if _anim_lock <= 0.0:
		_play("walk" if moved else "idle")
	queue_redraw()

# --- phase 1: massacre the waves ---
func _serving_step(delta: float) -> bool:
	hp = minf(_eff_max_hp(), hp + regen * regen_mult * delta)
	var target := _nearest_enemy()
	if not target:
		return false
	_try_abilities(target)
	var to_t: Vector2 = target.global_position - global_position
	_facing = to_t.normalized()
	var dist := to_t.length()
	if dist > attack_range:
		position += _facing * SPEED * delta
		position = Game.clamp_to_arena(position, RADIUS)
		return true
	elif _cd <= 0.0:
		_attack_cleave()
	return false

# Fire at most one flashy move per frame, biggest first.
func _try_abilities(target: Monster) -> void:
	if _meteor_cd <= 0.0 and _enemies_near(target.global_position, METEOR_RADIUS) >= 3:
		_cast_meteor(target.global_position)
	elif _nova_cd <= 0.0 and _enemies_near(global_position, NOVA_RADIUS) >= 2:
		_cast_nova()
	elif _smite_cd <= 0.0:
		_cast_smite()

func _attack_cleave() -> void:
	_cd = base_attack_cd
	_play("attack")
	_anim_lock = 0.35
	var dmg := base_damage * power_mult
	for n in get_tree().get_nodes_in_group("monsters"):
		var m := n as Monster
		if m.faction == "enemy" and global_position.distance_to(m.global_position) <= attack_range + m.radius:
			m.take_damage(dmg)
	Fx.slash(get_parent(), global_position + Vector2(0, -10), _facing, attack_range, Color(0.95, 0.97, 1.0))

# --- the flashy moves ---
func _cast_meteor(center: Vector2) -> void:
	_meteor_cd = METEOR_CD
	_play("attack"); _anim_lock = 0.4
	_flash = 0.3; _flash_col = FIRE
	_damage_enemies_in(center, METEOR_RADIUS, base_damage * power_mult * METEOR_POWER)
	Fx.explosion(get_parent(), center, FIRE, METEOR_RADIUS)

func _cast_nova() -> void:
	_nova_cd = NOVA_CD
	_play("attack"); _anim_lock = 0.35
	_flash = 0.3; _flash_col = HOLY
	_damage_enemies_in(global_position, NOVA_RADIUS, base_damage * power_mult * NOVA_POWER)
	Fx.nova(get_parent(), global_position, NOVA_RADIUS, HOLY)

func _cast_smite() -> void:
	var targets := _nearest_enemies(SMITE_TARGETS)
	if targets.is_empty():
		return
	_smite_cd = SMITE_CD
	_flash = 0.2; _flash_col = ARC
	var origin := global_position + Vector2(0, -40)
	var dmg := base_damage * power_mult * SMITE_POWER
	for m in targets:
		m.take_damage(dmg)
		Fx.bolt(get_parent(), origin, m.global_position, ARC)
		Fx.sparks(get_parent(), m.global_position, ARC, 12, 130.0, 0.4)

# --- enemy queries shared by the abilities ---
func _enemies_near(center: Vector2, r: float) -> int:
	var c := 0
	for n in get_tree().get_nodes_in_group("monsters"):
		var m := n as Monster
		if m.faction == "enemy" and center.distance_to(m.global_position) <= r:
			c += 1
	return c

func _damage_enemies_in(center: Vector2, r: float, dmg: float) -> void:
	for n in get_tree().get_nodes_in_group("monsters"):
		var m := n as Monster
		if m.faction == "enemy" and center.distance_to(m.global_position) <= r + m.radius:
			m.take_damage(dmg)

func _nearest_enemies(k: int) -> Array:
	var arr := []
	for n in get_tree().get_nodes_in_group("monsters"):
		var m := n as Monster
		if m.faction == "enemy":
			arr.append(m)
	var origin := global_position
	arr.sort_custom(func(a, b): return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position))
	return arr.slice(0, k)

func _nearest_enemy() -> Monster:
	var best: Monster = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("monsters"):
		var m := n as Monster
		if m.faction != "enemy":
			continue
		var d: float = global_position.distance_squared_to(m.global_position)
		if d < best_d:
			best_d = d
			best = m
	return best

# --- phase 2: hunt the traitor ---
func _boss_step(delta: float) -> bool:
	hp = minf(_eff_max_hp(), hp + regen * regen_mult * 0.3 * delta)
	var sq := _squire()
	if not sq:
		return false
	var to_t: Vector2 = sq.global_position - global_position
	_facing = to_t.normalized()
	var dist := to_t.length()
	if _nuke_cd <= 0.0:
		_nuke(sq)
	if dist > attack_range * 0.6:
		position += _facing * BOSS_SPEED * delta
		position = Game.clamp_to_arena(position, RADIUS)
		return true
	elif _cd <= 0.0:
		sq.take_damage(_boss_damage())
		_cd = base_attack_cd
		_play("attack")
		_anim_lock = 0.4
	return false

func _nuke(sq: Squire) -> void:
	_nuke_cd = 3.5
	_flash = 0.3
	_flash_col = Color(1.0, 0.5, 0.1)
	var center := sq.global_position
	if global_position.distance_to(center) <= 150.0:
		sq.take_damage(_boss_damage() * 1.2)
	Fx.explosion(get_parent(), center, Color(1.0, 0.4, 0.1), 150.0)

# --- gifts from the squire ---
func receive_genuine_potion() -> void:
	hp = minf(_eff_max_hp(), hp + GENUINE_HEAL)
	_flash = 0.25
	_flash_col = Color(0.4, 1.0, 0.5)
	_say_thanks(false)

func receive_genuine_weapon() -> void:
	power_mult = minf(1.6, power_mult + GENUINE_POWER)
	_flash = 0.25
	_flash_col = Color(1.0, 0.9, 0.4)
	_say_thanks(false)

func receive_cursed_potion() -> void:
	poison_dps += CURSE_POISON
	hp_penalty += CURSE_HP_PEN
	regen_mult = maxf(0.2, regen_mult - CURSE_REGEN)
	hp -= CURSE_SIP
	if hp <= 0.0:
		_on_death()
		return
	_flash = 0.25
	_flash_col = Color(0.6, 0.2, 0.8)
	_say_thanks(true)

func receive_cursed_weapon() -> void:
	power_mult = maxf(0.25, power_mult - CURSE_POWER)
	base_attack_cd = minf(1.2, base_attack_cd + 0.04)
	_flash = 0.25
	_flash_col = Color(0.6, 0.2, 0.8)
	_say_thanks(true)

# --- damage / death ---
func take_damage(d: float) -> void:
	if _dead:
		return
	hp -= d
	_flash = 0.12
	_flash_col = Color.RED
	if hp <= 0.0:
		_on_death()
	elif not hostile:
		_play("hurt")
		_anim_lock = 0.18

func _on_death() -> void:
	if _dead:
		return
	_dead = true
	hp = 0.0
	_play("death")
	_anim_lock = 999.0
	if _game:
		_game.win()

# --- progression / betrayal ---
func level_up() -> void:
	level += 1
	max_hp += 25.0
	hp = minf(_eff_max_hp(), hp + 40.0)
	base_damage += 5.0
	attack_range += 2.0
	_flash = 0.4
	_flash_col = Color(1.0, 0.9, 0.3)

func become_boss() -> void:
	hostile = true
	_flash = 0.6
	_flash_col = Color(1.0, 0.2, 0.2)
	_play("hurt")
	_anim_lock = 0.4
	if _game and _game.hud:
		_game.hud.princess_say("You... TRAITOR!")

# --- helpers ---
func _eff_max_hp() -> float:
	return maxf(60.0, max_hp - hp_penalty)

func _boss_damage() -> float:
	return base_damage * power_mult

func _squire() -> Squire:
	return get_tree().get_first_node_in_group("squire") as Squire

func _base_modulate() -> Color:
	return Color(1.0, 0.7, 0.7) if hostile else Color(1.0, 0.96, 0.85)

func _say_thanks(cursed: bool) -> void:
	if not (_game and _game.hud):
		return
	var line: String
	if cursed and _game.suspicion > 50.0 and randf() < 0.4:
		line = SUSPICIOUS[randi() % SUSPICIOUS.size()]
	else:
		line = THANKS[randi() % THANKS.size()]
	_game.hud.princess_say(line)

func _draw() -> void:
	# World HP bar (red when she's the boss).
	var w := 80.0
	var top := Vector2(-w * 0.5, _overlay_y)
	var fill := Color(1.0, 0.25, 0.25) if hostile else Color(0.95, 0.4, 0.65)
	draw_rect(Rect2(top, Vector2(w, 8)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(top, Vector2(w * clampf(hp / _eff_max_hp(), 0.0, 1.0), 8)), fill)
	# Golden crown on her head, just under the bar.
	var crown := Color(1.0, 0.85, 0.2)
	var cy := _overlay_y + 16.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-22, cy + 16), Vector2(-22, cy), Vector2(-11, cy + 9),
		Vector2(0, cy - 8), Vector2(11, cy + 9), Vector2(22, cy), Vector2(22, cy + 16)
	]), crown)
