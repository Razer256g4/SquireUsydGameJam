extends Actor
class_name Monster
## Evil orcs. Three flavors:
##   grunt - standard, chases the Princess
##   scout - fast, fragile, likes to harass the Squire
##   brute - big, very tanky, very painful; best loot
## Visual: the Orc sprite sheet, recoloured/scaled per flavor in configure().

# Stats below are grunt-ish placeholders only; configure() overwrites every one
# of them (and creates the sprite) based on `kind` right after the monster spawns.
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

var _cd := 0.0
var _flash := 0.0
var _anim_lock := 0.0
var _dead := false
var _overlay_y := 0.0       # set in configure(), once the sprite exists
var _game: Game

func _ready() -> void:
	add_to_group("monsters")
	z_index = 4
	_game = get_tree().get_first_node_in_group("game") as Game

func configure(wave: int) -> void:
	match kind:
		"scout":
			max_hp = 18.0; speed = 135.0; damage = 6.0; attack_cd = 0.8
			radius = 12.0; scale_f = 0.5; tint = Color(0.7, 0.95, 1.0); prefers_squire = true
			score_value = 12; drop_chance = 0.12
		"brute":
			max_hp = 95.0; speed = 42.0; damage = 18.0; attack_cd = 1.3
			radius = 22.0; scale_f = 0.9; tint = Color(1.0, 0.6, 0.55); prefers_squire = false
			score_value = 30; drop_chance = 0.45
		_: # grunt
			max_hp = 32.0; speed = 58.0; damage = 9.0; attack_cd = 1.0
			radius = 16.0; scale_f = 0.6; tint = Color.WHITE; prefers_squire = false
			score_value = 10; drop_chance = 0.18
	# Scale with room number.
	max_hp *= 1.0 + wave * 0.12
	damage *= 1.0 + wave * 0.06
	hp = max_hp

	_spr = AnimatedSprite2D.new()
	_spr.sprite_frames = Anim.orc()
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.scale = Vector2(scale_f, scale_f)
	_spr.offset = Vector2(0, -12)
	_spr.z_index = -1
	_spr.modulate = tint
	add_child(_spr)
	_play("idle")
	_overlay_y = overlay_y(scale_f)

func _process(delta: float) -> void:
	if _game and _game.state != "playing":
		return
	if _dead:
		return

	_cd = _decay(_cd, delta)
	_flash = _decay(_flash, delta)
	_anim_lock = _decay(_anim_lock, delta)
	if _spr:
		_spr.modulate = Color.WHITE if _flash > 0.0 else tint

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

func _choose_target() -> Node2D:
	var princess := get_tree().get_first_node_in_group("princess") as Node2D
	var squire := get_tree().get_first_node_in_group("squire") as Node2D
	if prefers_squire and squire and is_instance_valid(squire):
		return squire
	if princess and is_instance_valid(princess):
		return princess
	return squire

func _target_radius(t: Node2D) -> float:
	if t is Princess: return Princess.RADIUS
	if t is Squire: return Squire.RADIUS
	return 14.0

func _separation() -> Vector2:
	# Light push-apart so monsters don't stack into a single blob.
	var push := Vector2.ZERO
	for o in get_tree().get_nodes_in_group("monsters"):
		if o == self:
			continue
		var diff: Vector2 = global_position - o.global_position
		var d := diff.length()
		if d > 0.01 and d < radius + 8.0:
			push += diff / d * (radius + 8.0 - d) * 6.0
	return push

func take_damage(d: float) -> void:
	if _dead:
		return
	hp -= d
	_flash = 0.1
	if hp <= 0.0:
		_die()
	else:
		_play("hurt")
		_anim_lock = 0.2

func _die() -> void:
	_dead = true
	remove_from_group("monsters")     # so spawner/Princess stop counting it as alive
	if _game:
		_game.on_monster_killed(self)
	if _spr:
		_spr.modulate = tint
		_play("death")
	queue_redraw()
	await get_tree().create_timer(0.45).timeout
	if is_instance_valid(self):       # may have been freed by a scene reload (R)
		queue_free()

func _draw() -> void:
	if _dead:
		return
	if hp < max_hp:
		var w := 40.0
		var top := Vector2(-w * 0.5, _overlay_y)
		draw_rect(Rect2(top, Vector2(w, 4)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(top, Vector2(w * clampf(hp / max_hp, 0.0, 1.0), 4)), Color(0.9, 0.3, 0.3))
