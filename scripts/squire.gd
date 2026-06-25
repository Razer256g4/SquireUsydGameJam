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

# Carried-item overlay sprites (drawn above the head in _draw). Genuine vs tampered
# is shown by a different sprite; the cursed pair is wreathed in a voodoo hex.
const ITEM_POTION := "res://assets/items/item_potion.png"
const ITEM_POTION_V := "res://assets/items/item_potion_voodoo.png"
const ITEM_WEAPON := "res://assets/items/item_weapon.png"
const ITEM_WEAPON_V := "res://assets/items/item_weapon_voodoo.png"

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

# carried-item overlay textures (null until the PNGs are imported → primitive fallback)
var _tex_potion: Texture2D
var _tex_potion_v: Texture2D
var _tex_weapon: Texture2D
var _tex_weapon_v: Texture2D

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
	# crisp pixel art for the carried-item overlay drawn in _draw()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tex_potion = _load_tex(ITEM_POTION)
	_tex_potion_v = _load_tex(ITEM_POTION_V)
	_tex_weapon = _load_tex(ITEM_WEAPON)
	_tex_weapon_v = _load_tex(ITEM_WEAPON_V)
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
	if cursed:
		# a voodoo puff bursts off the gift the instant you hex it (violet + sickly green)
		var at := global_position + Vector2(0, _overlay_y)
		Fx.sparks(get_parent(), at, Color(0.62, 0.2, 0.85), 16, 150.0, 0.5)
		Fx.sparks(get_parent(), at, Color(0.35, 0.95, 0.45), 10, 110.0, 0.55)

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
	# a rallying shock-ring + embers ripple out as you whip the horde into a frenzy
	Fx.ring(get_parent(), global_position, 96.0, Color(1.0, 0.5, 0.2), 0.4, 7.0)
	Fx.sparks(get_parent(), global_position, Color(1.0, 0.55, 0.25), 18, 175.0, 0.5)

## Stir up a random "scheme" event (plane / revolt / infighting). The EventDirector
## handles the cooldown + suspicion cost; we just flash to acknowledge the input.
func _scheme() -> void:
	if not (_game and _game.phase == "serving" and _game.event_director):
		return
	if _game.event_director.trigger_scheme():
		_flash = 0.15
		_flash_col = Color(1.0, 0.4, 0.8)
		# a mischievous pink spark-ring as you stir the pot
		Fx.ring(get_parent(), global_position, 80.0, Color(1.0, 0.4, 0.8), 0.4, 6.0)
		Fx.sparks(get_parent(), global_position, Color(1.0, 0.45, 0.85), 16, 155.0, 0.5)

func _try_pickup() -> void:
	if carry != "":
		return
	for p in get_tree().get_nodes_in_group("pickups"):
		if global_position.distance_to(p.global_position) <= RADIUS + p.radius + 4.0:
			carry = p.kind
			cursed = false
			Sfx.play("pickup")
			# a little golden sparkle as you scoop up the supply
			Fx.sparks(get_parent(), global_position + Vector2(0, -8), Color(1.0, 0.95, 0.6), 14, 130.0, 0.45)
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
	var hand_at := pr.global_position + Vector2(0, -10)
	if cursed:
		Sfx.play("gift_curse")          # ominous extra cue; the sip/arm sound plays on the Princess
		_game.sabotage_suspicion()
		# voodoo puff as the hexed gift changes hands
		Fx.sparks(get_parent(), hand_at, Color(0.62, 0.2, 0.85), 18, 145.0, 0.6)
		Fx.sparks(get_parent(), hand_at, Color(0.35, 0.95, 0.45), 10, 100.0, 0.6)
	else:
		_game.help_calms_suspicion()
		_play("heal"); _anim_lock = 0.5  # a pious little flourish to sell the loyal-servant act
		# a wholesome green heal-flourish for a genuine gift
		Fx.ring(get_parent(), pr.global_position, 60.0, Color(0.7, 1.0, 0.8), 0.45, 5.0)
		Fx.sparks(get_parent(), hand_at, Color(0.55, 1.0, 0.65), 18, 130.0, 0.65)
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

func _load_tex(p: String) -> Texture2D:
	return load(p) if ResourceLoader.exists(p) else null

func _draw() -> void:
	_draw_speech(_overlay_y)
	# Carried item floats above the squire's head. A genuine gift gets a soft gold halo;
	# a tampered one is wreathed in a pulsing voodoo hex (violet + green, with crossbones).
	if carry == "":
		return
	var at := Vector2(0, _overlay_y)
	var t := float(Time.get_ticks_msec()) * 0.001
	var tex: Texture2D
	if carry == "potion":
		tex = _tex_potion_v if cursed else _tex_potion
	else:
		tex = _tex_weapon_v if cursed else _tex_weapon
	if cursed:
		_draw_voodoo_aura(at, t)
	else:
		draw_circle(at, 16.0, Color(1.0, 0.88, 0.42, 0.16))
		draw_circle(at, 10.0, Color(1.0, 0.96, 0.6, 0.26))
	if tex:
		draw_texture(tex, (at - tex.get_size() * 0.5).round())
	else:
		_draw_item_fallback(at)

# A pulsing hex halo for a tampered item: violet outer glow, sickly-green inner core,
# three orbiting green sparks, and a pair of bone-white crossbones flanking the item.
func _draw_voodoo_aura(at: Vector2, t: float) -> void:
	var pulse := 0.5 + 0.5 * sin(t * 3.2)
	draw_circle(at, 18.0 + pulse * 1.5, Color(0.42, 0.07, 0.55, 0.30))
	draw_circle(at, 12.0, Color(0.24, 0.82, 0.40, 0.20))
	var spark := Color(0.65, 1.0, 0.5, 0.9)
	for i in 3:
		var a := t * 1.7 + float(i) * TAU / 3.0
		var p := at + Vector2(cos(a), sin(a)) * (20.0 + pulse * 2.0)
		draw_line(p + Vector2(-2, 0), p + Vector2(2, 0), spark)
		draw_line(p + Vector2(0, -2), p + Vector2(0, 2), spark)
	_draw_crossbones(at + Vector2(-19, 3))
	_draw_crossbones(at + Vector2(19, 3))

func _draw_crossbones(p: Vector2) -> void:
	var c := Color(0.93, 0.91, 0.82, 0.9)
	draw_line(p + Vector2(-3, -3), p + Vector2(3, 3), c, 2.0)
	draw_line(p + Vector2(-3, 3), p + Vector2(3, -3), c, 2.0)
	for q in [Vector2(-4, -4), Vector2(4, 4), Vector2(-4, 4), Vector2(4, -4)]:
		draw_circle(p + q, 1.4, c)

# Pre-import / missing-asset fallback: the original primitive bottle / sword.
func _draw_item_fallback(at: Vector2) -> void:
	if carry == "potion":
		draw_circle(at + Vector2(0, 3), 9.0, Color(0.9, 0.2, 0.3))
		draw_rect(Rect2(at + Vector2(-3, -11), Vector2(6, 9)), Color(0.75, 0.78, 0.85))
	else:
		draw_line(at + Vector2(0, 11), at + Vector2(0, -11), Color(0.85, 0.9, 1.0), 4.0)
		draw_line(at + Vector2(-8, 5), at + Vector2(8, 5), Color(0.8, 0.65, 0.3), 4.0)
