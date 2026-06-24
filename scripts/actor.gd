extends Node2D
class_name Actor
## Shared base for the animated characters — Princess, Squire and Monster.
## Holds the single copy of the play / flip / overlay / timer-decay helpers, so a
## change to that logic happens in exactly one place. Subclasses own their own
## stats, AI and `_draw()` overlays; this base only owns the AnimatedSprite2D body
## and the `_facing` direction used to mirror it.

# The Tiny RPG sheets are 100x100 with the body roughly centred. The floating
# overlay row (HP bar / crown / carried item) sits just above the sprite's
# visible top, derived from its offset and scale by overlay_y().
const FRAME_CENTER := 50.0   # centre of a 100px sprite frame

var _facing := Vector2.DOWN
var _spr: AnimatedSprite2D

## Switch to `anim_name` only when it isn't already the running clip, so looping
## idle/walk animations don't restart (and freeze on frame 0) every frame.
func _play(anim_name: String) -> void:
	if _spr and (_spr.animation != anim_name or not _spr.is_playing()):
		_spr.play(anim_name)

## Tick a timer toward zero. Shared by the flash / animation-lock / i-frame timers.
func _decay(t: float, delta: float) -> float:
	return maxf(0.0, t - delta)

## Mirror the sprite to face the current movement/aim direction.
func _update_flip() -> void:
	if _spr:
		_spr.flip_h = _facing.x < 0.0

## World-space Y of the floating overlay row (HP bar / crown / carried item).
## `content_top` is the top edge of the visible character inside the 100px frame
## (the art only fills a small, padded region); mapped to world space and nudged up.
func overlay_y(content_top: float, sc: float) -> float:
	return (_spr.offset.y + (content_top - FRAME_CENTER)) * sc - 8.0

## Virtual hook so any Actor can be damaged through an `Actor`-typed reference.
## Princess / Squire / Monster each override this with their real behaviour.
func take_damage(_amount: float) -> void:
	pass
