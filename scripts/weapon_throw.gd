extends Node2D
class_name WeaponThrow
## A weapon yeeted at the Princess (Ctrl while carrying a weapon). It homes in
## on her and upgrades her on arrival. Uses the Tiny RPG arrow sprite.

const SPEED := 620.0
var _target: Node2D
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

func launch(target: Node2D) -> void:
	_target = target

func _process(delta: float) -> void:
	if not _target or not is_instance_valid(_target):
		queue_free()
		return
	var to_t: Vector2 = _target.global_position - global_position
	var dist := to_t.length()
	rotation = to_t.angle()
	if dist <= 16.0:
		if _target.has_method("receive_weapon"):
			_target.receive_weapon()
		queue_free()
		return
	position += to_t / dist * SPEED * delta
