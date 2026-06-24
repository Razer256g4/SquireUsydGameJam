extends Actor
class_name Squire
## The player: the Princess's measly sidekick. You can't fight — you fetch.
## Move: WASD / arrows.  Dash: Space.  Hand item to Princess: bump into her.
## Ctrl: drink a carried potion yourself, or yeet a carried weapon at her.
## Visual: the Soldier sprite, tinted/scaled down to read as a humble squire.

const SPEED := 235.0
const RADIUS := 14.0
const SCALE := 0.62
const TINT := Color(0.7, 1.0, 0.7)     # greenish, so you don't look like the Princess
const MAX_HP := 100.0
const MAX_STAMINA := 100.0

const DASH_SPEED := 720.0
const DASH_TIME := 0.16
const DASH_COST := 34.0
const STAMINA_REGEN := 26.0            # stamina per second

const SELF_HEAL := 42.0                # potion drunk on yourself (Ctrl)
const PRINCESS_HEAL := 65.0            # potion handed to the Princess

var hp := MAX_HP
var stamina := MAX_STAMINA
var carry := ""                        # "" | "potion" | "weapon"

var _dash_time := 0.0
var _dash_dir := Vector2.DOWN
var _hurt_cd := 0.0
var _flash := 0.0
var _flash_col := Color.RED
var _anim_lock := 0.0
var _overlay_y := 0.0                   # set in _ready(), once the sprite exists
var _game: Game

func _ready() -> void:
	add_to_group("squire")
	z_index = 10
	_game = get_tree().get_first_node_in_group("game") as Game

	_spr = AnimatedSprite2D.new()
	_spr.sprite_frames = Anim.soldier()
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.scale = Vector2(SCALE, SCALE)
	_spr.offset = Vector2(0, -14)
	_spr.z_index = -1
	add_child(_spr)
	_play("idle")
	_overlay_y = overlay_y(SCALE)

func _input(event: InputEvent) -> void:
	if _game and _game.state != "playing":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_try_dash()
			KEY_CTRL:
				_use_item()

func _process(delta: float) -> void:
	if _game and _game.state != "playing":
		return

	_hurt_cd = _decay(_hurt_cd, delta)
	_flash = _decay(_flash, delta)
	_anim_lock = _decay(_anim_lock, delta)

	var input_dir := _read_move()
	if input_dir != Vector2.ZERO:
		_facing = input_dir

	var moving := false
	if _dash_time > 0.0:
		_dash_time -= delta
		position += _dash_dir * DASH_SPEED * delta
		moving = true
	else:
		var sp := SPEED
		if carry == "weapon":
			sp *= 0.88        # weapons are heavy — slows you down
		position += input_dir * sp * delta
		stamina = minf(MAX_STAMINA, stamina + STAMINA_REGEN * delta)
		moving = input_dir != Vector2.ZERO

	position = Game.clamp_to_arena(position, RADIUS)

	_try_pickup()
	_try_hand_to_princess()

	# Visuals: flash on heal/hit, blink while invulnerable after a hit (not mid-dash).
	var col := TINT
	if _flash > 0.0:
		col = _flash_col
	elif _hurt_cd > 0.0 and _dash_time <= 0.0:
		col.a = 0.55
	_spr.modulate = col
	_update_flip()
	if _anim_lock <= 0.0:
		_play("walk" if moving else "idle")
	queue_redraw()

func _read_move() -> Vector2:
	var d := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): d.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): d.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): d.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): d.x += 1.0
	return d.normalized()

func _try_dash() -> void:
	if _dash_time > 0.0 or stamina < DASH_COST:
		return
	stamina -= DASH_COST
	_dash_time = DASH_TIME
	_dash_dir = _read_move()
	if _dash_dir == Vector2.ZERO:
		_dash_dir = _facing
	_hurt_cd = maxf(_hurt_cd, DASH_TIME + 0.05)   # brief i-frames through enemies

func _use_item() -> void:
	match carry:
		"potion":
			hp = minf(MAX_HP, hp + SELF_HEAL)
			carry = ""
			_flash = 0.2
			_flash_col = Color(0.4, 1.0, 0.5)
		"weapon":
			_yeet_weapon()
			carry = ""

func _yeet_weapon() -> void:
	var princess := get_tree().get_first_node_in_group("princess") as Node2D
	if not princess:
		return
	var proj := WeaponThrow.new()
	proj.position = global_position
	_game.add_child(proj)
	proj.launch(princess)

func _try_pickup() -> void:
	if carry != "":
		return
	for p in get_tree().get_nodes_in_group("pickups"):
		if global_position.distance_to(p.global_position) <= RADIUS + p.radius + 4.0:
			carry = p.kind
			p.queue_free()
			return

func _try_hand_to_princess() -> void:
	if carry == "":
		return
	var princess := get_tree().get_first_node_in_group("princess") as Princess
	if not princess:
		return
	if global_position.distance_to(princess.global_position) <= RADIUS + Princess.RADIUS + 6.0:
		if carry == "potion":
			princess.receive_potion(PRINCESS_HEAL)
		elif carry == "weapon":
			princess.receive_weapon()
		carry = ""

func take_damage(d: float) -> void:
	if _hurt_cd > 0.0:
		return
	hp -= d
	_hurt_cd = 0.6
	_flash = 0.2
	_flash_col = Color.RED
	if hp <= 0.0:
		hp = 0.0
		_play("death")
		if _game:
			_game.game_over()
	else:
		_play("hurt")
		_anim_lock = 0.22

func _draw() -> void:
	# Carried item floats above the squire's head.
	if carry == "":
		return
	var at := Vector2(0, _overlay_y)
	if carry == "potion":
		draw_circle(at + Vector2(0, 2), 6.0, Color(0.9, 0.2, 0.3))
		draw_rect(Rect2(at + Vector2(-2, -7), Vector2(4, 6)), Color(0.75, 0.78, 0.85))
	else:
		draw_line(at + Vector2(0, 7), at + Vector2(0, -7), Color(0.85, 0.9, 1.0), 3.0)
		draw_line(at + Vector2(-5, 3), at + Vector2(5, 3), Color(0.8, 0.65, 0.3), 3.0)
