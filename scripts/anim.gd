extends RefCounted
class_name Anim
## Builds (and caches) SpriteFrames from the Tiny RPG strip sheets.
## Every strip is laid out horizontally with 100x100 frames.

const FW := 100

const RPG := "res://tiny rpg/Tiny RPG Character Asset Pack v1.03 -Free Soldier&Orc/"
const CHARS := RPG + "Characters(100x100)/"

static var _cache := {}

static func soldier() -> SpriteFrames:
	if _cache.has("soldier"):
		return _cache["soldier"]
	var b := CHARS + "Soldier/Soldier/"
	var sf := _build([
		{"name": "idle", "path": b + "Soldier-Idle.png", "frames": 6, "fps": 8.0, "loop": true},
		{"name": "walk", "path": b + "Soldier-Walk.png", "frames": 8, "fps": 12.0, "loop": true},
		{"name": "attack", "path": b + "Soldier-Attack01.png", "frames": 6, "fps": 16.0, "loop": false},
		{"name": "hurt", "path": b + "Soldier-Hurt.png", "frames": 4, "fps": 12.0, "loop": false},
		{"name": "death", "path": b + "Soldier-Death.png", "frames": 4, "fps": 8.0, "loop": false},
	])
	_cache["soldier"] = sf
	return sf

static func orc() -> SpriteFrames:
	if _cache.has("orc"):
		return _cache["orc"]
	var b := CHARS + "Orc/Orc/"
	var sf := _build([
		{"name": "idle", "path": b + "Orc-Idle.png", "frames": 6, "fps": 8.0, "loop": true},
		{"name": "walk", "path": b + "Orc-Walk.png", "frames": 8, "fps": 12.0, "loop": true},
		{"name": "attack", "path": b + "Orc-Attack01.png", "frames": 6, "fps": 16.0, "loop": false},
		{"name": "hurt", "path": b + "Orc-Hurt.png", "frames": 4, "fps": 12.0, "loop": false},
		{"name": "death", "path": b + "Orc-Death.png", "frames": 4, "fps": 8.0, "loop": false},
	])
	_cache["orc"] = sf
	return sf

static func vampire() -> SpriteFrames:
	if _cache.has("vampire"):
		return _cache["vampire"]
	var b := "res://sprites/vampire/processed/Vampire-"
	var sf := _build([
		{"name": "idle",    "path": b + "Idle.png",    "frames": 6, "fps": 8.0,  "loop": true},
		{"name": "walk",    "path": b + "Walk.png",    "frames": 6, "fps": 10.0, "loop": true},
		{"name": "attack",  "path": b + "Attack.png",  "frames": 5, "fps": 14.0, "loop": false},
		{"name": "special", "path": b + "Special.png", "frames": 8, "fps": 10.0, "loop": false},
		{"name": "hurt",    "path": b + "Hurt.png",    "frames": 3, "fps": 10.0, "loop": false},
		{"name": "death",   "path": b + "Death.png",   "frames": 5, "fps": 7.0,  "loop": false},
	])
	_cache["vampire"] = sf
	return sf

static func arrow_texture() -> Texture2D:
	return load(RPG + "Arrow(Projectile)/Arrow01(100x100).png") as Texture2D

static func werewolf() -> SpriteFrames:
	if _cache.has("werewolf"):
		return _cache["werewolf"]
	var idle_p := "res://sprites/Firefly_pixel art sprite sheet, werewolf idle breathing animation, 6 frames horizontal strip, 676886.png"
	var howl_p := "res://sprites/Firefly_Gemini Flash_pixel art sprite sheet, werewolf howl special attack, 7 frames horizontal strip,_head 676886.png"
	var sf := _build([
		{"name": "idle",   "path": idle_p, "frames": 6, "fps": 8.0,  "loop": true,  "fw": 234},
		{"name": "walk",   "path": idle_p, "frames": 6, "fps": 10.0, "loop": true,  "fw": 234},
		{"name": "attack", "path": howl_p, "frames": 7, "fps": 14.0, "loop": false, "fw": 390},
		{"name": "hurt",   "path": idle_p, "frames": 2, "fps": 10.0, "loop": false, "fw": 234},
		{"name": "death",  "path": idle_p, "frames": 6, "fps": 5.0,  "loop": false, "fw": 234},
	])
	_cache["werewolf"] = sf
	return sf

static func _build(defs: Array) -> SpriteFrames:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for d in defs:
		var name: String = d["name"]
		sf.add_animation(name)
		sf.set_animation_speed(name, d["fps"])
		sf.set_animation_loop(name, d["loop"])
		var tex := load(d["path"]) as Texture2D
		if tex == null:
			push_warning("Anim: could not load " + str(d["path"]))
			continue
		var fw: int = d.get("fw", FW)
		var fh := tex.get_height()
		var n: int = d["frames"]
		for i in n:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * fw, 0, fw, fh)
			sf.add_frame(name, at)
	return sf
