extends Node2D
class_name WeaponThrow
## A weapon hurled at the Princess (F while carrying one) — a ranged version of the
## bump hand-off. It homes in on her and is "received" on arrival, applying the same
## genuine/cursed weapon effect and suspicion change as handing it over in person.
## Fire-and-forget: reuses the Tiny RPG arrow sprite (Anim.arrow_texture).

const SPEED := 640.0

var _game: Game
var _target: Princess
var _cursed := false
var _spr: Sprite2D

func _ready() -> void:
	z_index = 12
	_spr = Sprite2D.new()
	var tex := Anim.arrow_texture()
	if tex:
		_spr.texture = tex
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.scale = Vector2(0.6, 0.6)
	add_child(_spr)
	_retint()

func launch(game: Game, target: Princess, cursed: bool) -> void:
	_game = game
	_target = target
	_cursed = cursed
	_retint()

func _retint() -> void:
	if _spr:
		_spr.modulate = Color(0.8, 0.4, 1.0) if _cursed else Color(1.0, 0.95, 0.7)

func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		queue_free()
		return
	var to_t: Vector2 = _target.global_position - global_position
	var dist := to_t.length()
	rotation = to_t.angle()
	if dist <= 18.0:
		_arrive()
		queue_free()
		return
	position += to_t / dist * SPEED * delta

func _arrive() -> void:
	# Only a still-trusting (serving) Princess accepts the "gift". If she's already
	# turned hostile mid-flight, it just fizzles into sparks.
	if _game and _game.phase == "serving" and is_instance_valid(_target):
		if _cursed:
			_target.receive_cursed_weapon()
			_game.sabotage_suspicion()
		else:
			_target.receive_genuine_weapon()
			_game.help_resets_suspicion()
	var col := Color(0.8, 0.4, 1.0) if _cursed else Color(1.0, 0.9, 0.4)
	if _game:
		Fx.sparks(_game, global_position, col, 12, 110.0, 0.45)
