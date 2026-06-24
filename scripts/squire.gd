extends Actor
class_name Squire
## You — the Princess's "loyal" squire, and the real villain. You fetch her
## supplies, but you can TAMPER with them first (Ctrl) so a healing potion poisons
## her and a fine weapon saps her strength. Bump into her to hand the item over.
## Press E to tip off / rally the monsters. Genuine gifts calm her Suspicion;
## cursed ones (and tip-offs) raise it. At 100% she turns on you.

const SPEED := 235.0
const RADIUS := 26.0
const SCALE := 4.0
const TINT := Color(0.7, 1.0, 0.7)     # humble servant green
const MAX_HP := 75.0
const MAX_STAMINA := 100.0

const DASH_SPEED := 720.0
const DASH_TIME := 0.16
const DASH_COST := 34.0
const STAMINA_REGEN := 26.0

const TIP_COST := 25.0
const TIP_CD := 4.0

var hp := MAX_HP
var stamina := MAX_STAMINA
var carry := ""                 # "" | "potion" | "weapon"
var cursed := false             # has the carried item been tampered with?
var tip_cd := 0.0

var _dash_time := 0.0
var _dash_dir := Vector2.DOWN
var _hurt_cd := 0.0
var _flash := 0.0
var _flash_col := Color.RED
var _overlay_y := 0.0
var _game: Game

func _ready() -> void:
	add_to_group("squire")
	z_index = 10
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

func _input(event: InputEvent) -> void:
	if not _active():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_try_dash()
			KEY_CTRL:
				_toggle_curse()
			KEY_E:
				_tip_off()

func _process(delta: float) -> void:
	if not _active():
		return

	_hurt_cd = _decay(_hurt_cd, delta)
	_flash = _decay(_flash, delta)
	tip_cd = _decay(tip_cd, delta)

	var input_dir := _read_move()
	if input_dir != Vector2.ZERO:
		_facing = input_dir

	var moving := false
	if _dash_time > 0.0:
		_dash_time -= delta
		position += _dash_dir * DASH_SPEED * delta
		moving = true
	else:
		position += input_dir * SPEED * delta
		stamina = minf(MAX_STAMINA, stamina + STAMINA_REGEN * delta)
		moving = input_dir != Vector2.ZERO

	position = Game.clamp_to_arena(position, RADIUS)

	_try_pickup()
	_try_hand()

	# Visuals
	var col := TINT
	if _flash > 0.0:
		col = _flash_col
	elif _hurt_cd > 0.0 and _dash_time <= 0.0:
		col.a = 0.55
	_spr.modulate = col
	_update_flip()
	_play("walk" if moving else "idle")
	queue_redraw()

func _active() -> bool:
	return _game == null or _game.phase == "serving" or _game.phase == "boss"

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
	_hurt_cd = maxf(_hurt_cd, DASH_TIME + 0.05)   # i-frames through enemies

func _toggle_curse() -> void:
	if carry == "":
		return
	cursed = not cursed

## Tip off the enemy (phase 1) / rally your defectors (phase 2): enrage every
## monster so it hits the Princess harder. Costs stamina; raises suspicion.
func _tip_off() -> void:
	if tip_cd > 0.0 or stamina < TIP_COST:
		return
	stamina -= TIP_COST
	tip_cd = TIP_CD
	for n in get_tree().get_nodes_in_group("monsters"):
		(n as Monster).enrage()
	if _game and _game.phase == "serving":
		_game.add_suspicion(Game.SUS_TIP)
	_flash = 0.15
	_flash_col = Color(1.0, 0.5, 0.2)

func _try_pickup() -> void:
	if carry != "":
		return
	for p in get_tree().get_nodes_in_group("pickups"):
		if global_position.distance_to(p.global_position) <= RADIUS + p.radius + 4.0:
			carry = p.kind
			cursed = false
			p.queue_free()
			return

func _try_hand() -> void:
	if carry == "" or not (_game and _game.phase == "serving"):
		return
	var pr := get_tree().get_first_node_in_group("princess") as Princess
	if not pr:
		return
	if global_position.distance_to(pr.global_position) > RADIUS + Princess.RADIUS + 6.0:
		return
	if carry == "potion":
		if cursed: pr.receive_cursed_potion()
		else: pr.receive_genuine_potion()
	else:
		if cursed: pr.receive_cursed_weapon()
		else: pr.receive_genuine_weapon()
	_game.add_suspicion(Game.SUS_CURSE if cursed else -Game.SUS_GENUINE)
	carry = ""
	cursed = false

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
			_game.lose()
	else:
		_play("hurt")

func _draw() -> void:
	# Carried item floats above the squire's head, with a tell-tale aura if cursed.
	if carry == "":
		return
	var at := Vector2(0, _overlay_y)
	var aura := Color(0.6, 0.15, 0.8, 0.5) if cursed else Color(1.0, 0.9, 0.4, 0.35)
	draw_circle(at, 17.0, aura)
	if carry == "potion":
		draw_circle(at + Vector2(0, 3), 9.0, Color(0.9, 0.2, 0.3))
		draw_rect(Rect2(at + Vector2(-3, -11), Vector2(6, 9)), Color(0.75, 0.78, 0.85))
	else:
		draw_line(at + Vector2(0, 11), at + Vector2(0, -11), Color(0.85, 0.9, 1.0), 4.0)
		draw_line(at + Vector2(-8, 5), at + Vector2(8, 5), Color(0.8, 0.65, 0.3), 4.0)
