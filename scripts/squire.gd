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
const MAX_HITS := 4                     # die on the Nth hit from ANY source (each hit = one pip)
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
var _ghost_t := 0.0             # spacing timer for the dash afterimage trail
var _hurt_cd := 0.0
var _anim_lock := 0.0           # >0 while a one-shot clip (hurt / heal) plays out
var _flash := 0.0
var _flash_col := Color.RED
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
	add_to_group("squire")
	z_index = 10
	_game = get_tree().get_first_node_in_group("game") as Game

	_spr = AnimatedSprite2D.new()
	_spr.sprite_frames = Anim.priest()
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.scale = Vector2(SCALE, SCALE)
	_spr.offset = Vector2(0, -6)        # feet sit on the node origin
	_spr.z_index = -1
	add_child(_spr)
	_base_scale = Vector2(SCALE, SCALE)
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
			KEY_Q:
				_scheme()

func _process(delta: float) -> void:
	if not _active():
		return

	_hurt_cd = _decay(_hurt_cd, delta)
	_anim_lock = _decay(_anim_lock, delta)
	_flash = _decay(_flash, delta)
	tip_cd = _decay(tip_cd, delta)
	_tick_speech(delta)

	var input_dir := _read_move()
	if input_dir != Vector2.ZERO:
		_facing = input_dir

	var moving := false
	if _dash_time > 0.0:
		_dash_time -= delta
		position += _dash_dir * DASH_SPEED * delta
		moving = true
		_ghost_t -= delta                 # lay down a fading echo every ~30ms of the dash
		if _ghost_t <= 0.0:
			_ghost_t = 0.03
			var tex := _spr.sprite_frames.get_frame_texture(_spr.animation, _spr.frame)
			Fx.afterimage(get_parent(), tex, global_position, _spr.offset, _base_scale, _spr.flip_h)
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
	if _anim_lock <= 0.0:           # let a hurt/heal one-shot finish before resuming locomotion
		_play("walk" if moving else "idle")
	_tick_pop(delta)
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
	Sfx.play("dash")
	_dash_time = DASH_TIME
	_dash_dir = _read_move()
	if _dash_dir == Vector2.ZERO:
		_dash_dir = _facing
	_hurt_cd = maxf(_hurt_cd, DASH_TIME + 0.05)   # i-frames through enemies
	_ghost_t = 0.0                                 # start the afterimage trail immediately
	Fx.dash_dust(get_parent(), global_position, _dash_dir)   # grit kicked out behind the burst

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
	Sfx.play("tipoff")
	for n in get_tree().get_nodes_in_group("monsters"):
		(n as Monster).enrage()
	if _game and _game.phase == "serving":
		_game.minor_suspicion()
	_flash = 0.15
	_flash_col = Color(1.0, 0.5, 0.2)

## Stir up a random "scheme" event (plane / revolt / infighting). The EventDirector
## handles the cooldown + suspicion cost; we just flash to acknowledge the input.
func _scheme() -> void:
	if not (_game and _game.phase == "serving" and _game.event_director):
		return
	if _game.event_director.trigger_scheme():
		_flash = 0.15
		_flash_col = Color(1.0, 0.4, 0.8)

func _try_pickup() -> void:
	if carry != "":
		return
	for p in get_tree().get_nodes_in_group("pickups"):
		if global_position.distance_to(p.global_position) <= RADIUS + p.radius + 4.0:
			carry = p.kind
			cursed = false
			Sfx.play("pickup")
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
	if cursed:
		Sfx.play("gift_curse")          # ominous extra cue; the sip/arm sound plays on the Princess
		_game.sabotage_suspicion()
	else:
		_game.help_calms_suspicion()
		_play("heal"); _anim_lock = 0.5  # a pious little flourish to sell the loyal-servant act
	carry = ""
	cursed = false

func take_damage(_d: float) -> void:
	# Every hit costs ONE pip regardless of the damage value, so the squire always
	# survives exactly MAX_HITS - 1 hits from any source (monster, trap, angel laser,
	# boss nuke…) before the next one kills. Dash / i-frames (_hurt_cd) still apply.
	if _hurt_cd > 0.0:
		return
	hp -= MAX_HP / float(MAX_HITS)
	_hurt_cd = 0.6
	_flash = 0.2
	_flash_col = Color.RED
	_pop_hit()
	if hp <= 0.0:
		hp = 0.0
		Sfx.play("player_die")
		_play("death")
		if _game:
			# Boss phase = the Princess is hunting you, so a death there is HER doing
			# (executed). Any serving-phase death is by monsters / traps / your own
			# chaos — a "pointless" non-queen death.
			_game.lose("queen" if _game.phase == "boss" else "")
	else:
		Sfx.play("player_hurt")
		_play("hurt"); _anim_lock = 0.25     # hold the hurt clip so it's actually visible

func _draw() -> void:
	_draw_speech(_overlay_y)
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
