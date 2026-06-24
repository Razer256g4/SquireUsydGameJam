extends Actor
class_name Princess
## The Princess. The real hero — fully autonomous. Seeks the nearest monster,
## closes in and swings on a cooldown. You (the Squire) keep her alive/upgraded.
## Visual: the Soldier sprite sheet. If she falls, the kingdom falls.

const SPEED := 140.0
const RADIUS := 18.0
const SCALE := 0.8

var max_hp := 220.0
var hp := 220.0
var attack_damage := 18.0
var attack_range := 80.0
var attack_cooldown := 0.85
var weapon_level := 1
var weapon_name := "Dagger"

var _cd := 0.0
var _anim_lock := 0.0
var _flash := 0.0
var _flash_col := Color.RED
var _overlay_y := 0.0       # set in _ready(), once the sprite exists
var _game: Game

func _ready() -> void:
	add_to_group("princess")
	z_index = 8
	_game = get_tree().get_first_node_in_group("game") as Game

	_spr = AnimatedSprite2D.new()
	_spr.sprite_frames = Anim.soldier()
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.scale = Vector2(SCALE, SCALE)
	_spr.offset = Vector2(0, -16)
	_spr.z_index = -1                 # draw behind the parent's overlays
	add_child(_spr)
	_play("idle")
	_overlay_y = overlay_y(SCALE)

func _process(delta: float) -> void:
	if _game and _game.state != "playing":
		return

	_cd = _decay(_cd, delta)
	_anim_lock = _decay(_anim_lock, delta)
	_flash = _decay(_flash, delta)
	_spr.modulate = _flash_col if _flash > 0.0 else Color.WHITE

	var moved := false
	var target := _nearest_monster()
	if target:
		var to_target: Vector2 = target.global_position - global_position
		_facing = to_target.normalized()
		var dist := to_target.length()
		if dist > attack_range:
			position += _facing * SPEED * delta
			position = Game.clamp_to_arena(position, RADIUS)
			moved = true
		elif _cd <= 0.0:
			_attack(target)

	_update_flip()
	if _anim_lock <= 0.0:
		_play("walk" if moved else "idle")
	queue_redraw()

func _nearest_monster() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for m in get_tree().get_nodes_in_group("monsters"):
		var d: float = global_position.distance_squared_to(m.global_position)
		if d < best_d:
			best_d = d
			best = m
	return best

func _attack(target: Node2D) -> void:
	_cd = attack_cooldown
	_play("attack")
	_anim_lock = 0.4
	if weapon_level >= 3:
		# Cleave: hit every monster within range.
		for m in get_tree().get_nodes_in_group("monsters"):
			if global_position.distance_to(m.global_position) <= attack_range + m.radius:
				m.take_damage(attack_damage)
	else:
		target.take_damage(attack_damage)

func receive_potion(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	_flash = 0.25
	_flash_col = Color(0.4, 1.0, 0.5)

func receive_weapon() -> void:
	weapon_level += 1
	attack_damage += 9.0
	attack_range += 6.0
	attack_cooldown = maxf(0.30, attack_cooldown - 0.07)
	max_hp += 10.0
	hp += 10.0
	weapon_name = _weapon_name_for(weapon_level)
	_flash = 0.3
	_flash_col = Color(1.0, 0.85, 0.2)

func take_damage(d: float) -> void:
	hp -= d
	_flash = 0.15
	_flash_col = Color.RED
	if hp <= 0.0:
		hp = 0.0
		_play("death")
		if _game:
			_game.game_over()
	else:
		_play("hurt")
		_anim_lock = 0.22

func _weapon_name_for(lvl: int) -> String:
	match lvl:
		1: return "Dagger"
		2: return "Sword"
		3: return "Warhammer"
		4: return "Halberd"
		5: return "Holy Blade"
		_: return "Excalibur+%d" % (lvl - 5)

func _draw() -> void:
	# Golden crown floating above her head (so you can always spot the Princess).
	var crown := Color(1.0, 0.85, 0.2)
	var cy := _overlay_y + 6.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, cy + 8), Vector2(-10, cy), Vector2(-5, cy + 5),
		Vector2(0, cy - 4), Vector2(5, cy + 5), Vector2(10, cy), Vector2(10, cy + 8)
	]), crown)
	# World HP bar.
	var w := 48.0
	var top := Vector2(-w * 0.5, _overlay_y - 6.0)
	draw_rect(Rect2(top, Vector2(w, 5)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(top, Vector2(w * clampf(hp / max_hp, 0.0, 1.0), 5)), Color(0.95, 0.4, 0.65))
