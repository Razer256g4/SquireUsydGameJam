extends Node2D
class_name Pickup
## Loot on the dungeon floor. "potion" or "weapon". The Squire grabs it by
## walking over it (when empty-handed).

const RADIUS := 16.0       # pickup reach radius (shared with Game spawn-inset)
const VIS := 1.4           # visual upscale so loot reads at the bigger character scale

var kind := "potion"
var radius := RADIUS
var _bob := 0.0

func _ready() -> void:
	add_to_group("pickups")
	z_index = 2
	_bob = float(get_instance_id() % 100) * 0.1

func _process(delta: float) -> void:
	_bob += delta
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(VIS, VIS))
	var y := sin(_bob * 3.0) * 3.0
	var at := Vector2(0, y)
	# Glow ring
	var glow := Color(0.9, 0.3, 0.4, 0.25) if kind == "potion" else Color(1.0, 0.85, 0.3, 0.25)
	draw_circle(at, radius + 4.0, glow)

	if kind == "potion":
		# Red flask
		draw_circle(at + Vector2(0, 4), 8.0, Color(0.9, 0.2, 0.3))
		draw_rect(Rect2(at + Vector2(-3, -9), Vector2(6, 8)), Color(0.75, 0.78, 0.85))
		draw_rect(Rect2(at + Vector2(-4, -11), Vector2(8, 3)), Color(0.5, 0.35, 0.25))
		draw_circle(at + Vector2(-2, 2), 2.0, Color(1, 1, 1, 0.6))
	else:
		# Golden sword
		draw_line(at + Vector2(0, 10), at + Vector2(0, -10), Color(0.85, 0.9, 1.0), 4.0)
		draw_line(at + Vector2(-7, 5), at + Vector2(7, 5), Color(0.8, 0.65, 0.3), 4.0)
		draw_circle(at + Vector2(0, 9), 2.5, Color(0.8, 0.65, 0.3))
