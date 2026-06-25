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

# --- speech bubble (world-space, floats above this actor's head) ------------
# So a line "comes from" whoever says it: drawn in the actor's own _draw(), it
# tracks the character and shakes with the camera. HUD.princess_say/squire_say
# route here; subclasses call _tick_speech() in _process and _draw_speech() in _draw.
var _speech := ""
var _speech_t := 0.0
var _speech_col := Color.WHITE

## Show `text` above this actor's head for `dur` seconds, tinted `col`.
func say(text: String, col := Color.WHITE, dur := 2.6) -> void:
	_speech = text
	_speech_t = dur
	_speech_col = col

func _tick_speech(delta: float) -> void:
	if _speech_t > 0.0:
		_speech_t = maxf(0.0, _speech_t - delta)

## Draw the current line as a little bubble whose bottom sits just above `top_y`
## (the actor's overlay-row Y). Call from _draw(); no-op when nothing is being said.
func _draw_speech(top_y: float) -> void:
	if _speech_t <= 0.0 or _speech == "":
		return
	var font := ThemeDB.fallback_font
	var fsize := 15
	var alpha: float = clampf(_speech_t, 0.0, 1.0)          # fade out over the final second
	var tw: float = font.get_string_size(_speech, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	var pad := Vector2(8.0, 5.0)
	var box_h: float = fsize + pad.y * 2.0
	var bottom: float = top_y - 6.0                          # just above the HP bar / crown
	var box := Rect2(Vector2(-tw * 0.5 - pad.x, bottom - box_h), Vector2(tw + pad.x * 2.0, box_h))
	var bg := Color(0.06, 0.05, 0.09, 0.8 * alpha)
	draw_rect(box, bg)
	draw_rect(box, Color(_speech_col.r, _speech_col.g, _speech_col.b, 0.55 * alpha), false, 1.5)
	draw_colored_polygon(PackedVector2Array([                # little tail pointing down at the head
		Vector2(-6.0, bottom), Vector2(6.0, bottom), Vector2(0.0, bottom + 7.0)]), bg)
	draw_string(font, Vector2(-tw * 0.5, bottom - pad.y - 1.0), _speech,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(_speech_col.r, _speech_col.g, _speech_col.b, alpha))
