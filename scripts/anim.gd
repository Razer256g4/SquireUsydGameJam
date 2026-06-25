extends RefCounted
class_name Anim
## Builds (and caches) SpriteFrames from the Tiny RPG strip sheets.
## Every strip is laid out horizontally with 100x100 frames.

const FW := 100

const RPG := "res://tiny rpg/Tiny RPG Character Asset Pack v1.03 -Free Soldier&Orc/"
const CHARS := RPG + "Characters(100x100)/"
# Hand-picked sheets lifted from the FULL 20-character pack (flat-copied so the
# paths stay short): the Swordsman for the Princess, the Priest for the Squire.
const FULL := "res://tiny rpg/full/"

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

## The Princess — Swordsman sheet. Ships THREE attack clips: "attack" is the quick
## basic swing, while "attack2"/"attack3" are longer flourishes the Princess rotates
## through for her big telegraphed spells (see princess.gd `_play_cast`).
static func swordsman() -> SpriteFrames:
	if _cache.has("swordsman"):
		return _cache["swordsman"]
	var b := FULL + "Swordsman/"
	var sf := _build([
		{"name": "idle", "path": b + "Swordsman-Idle.png", "frames": 6, "fps": 8.0, "loop": true},
		{"name": "walk", "path": b + "Swordsman-Walk.png", "frames": 8, "fps": 12.0, "loop": true},
		{"name": "attack", "path": b + "Swordsman-Attack01.png", "frames": 7, "fps": 16.0, "loop": false},
		{"name": "attack2", "path": b + "Swordsman-Attack02.png", "frames": 15, "fps": 18.0, "loop": false},
		{"name": "attack3", "path": b + "Swordsman-Attack3.png", "frames": 12, "fps": 16.0, "loop": false},
		{"name": "hurt", "path": b + "Swordsman-Hurt.png", "frames": 5, "fps": 12.0, "loop": false},
		{"name": "death", "path": b + "Swordsman-Death.png", "frames": 4, "fps": 8.0, "loop": false},
	])
	_cache["swordsman"] = sf
	return sf

## The Squire (you) — Priest sheet: a humble servant look, distinct from the Princess.
## "heal" is a short pious flourish the Squire plays when handing over a genuine gift.
static func priest() -> SpriteFrames:
	if _cache.has("priest"):
		return _cache["priest"]
	var b := FULL + "Priest/"
	var sf := _build([
		{"name": "idle", "path": b + "Priest-Idle.png", "frames": 6, "fps": 8.0, "loop": true},
		{"name": "walk", "path": b + "Priest-Walk.png", "frames": 8, "fps": 12.0, "loop": true},
		{"name": "attack", "path": b + "Priest-Attack.png", "frames": 9, "fps": 14.0, "loop": false},
		{"name": "heal", "path": b + "Priest-Heal.png", "frames": 6, "fps": 12.0, "loop": false},
		{"name": "hurt", "path": b + "Priest-Hurt.png", "frames": 4, "fps": 12.0, "loop": false},
		{"name": "death", "path": b + "Priest-Death.png", "frames": 4, "fps": 8.0, "loop": false},
	])
	_cache["priest"] = sf
	return sf

## Mage spell VFX lifted from the Wizard's "Magic(projectile)" sheets — layered onto
## the (Swordsman-bodied) Princess's casts so her magic actually looks like magic.
## "burst" = blue arcane star (arc/holy spells); "orb" = orange fireball (fire spells).
static func wizard_fx() -> SpriteFrames:
	if _cache.has("wizard_fx"):
		return _cache["wizard_fx"]
	var b := FULL + "WizardFx/"
	var sf := _build([
		{"name": "burst", "path": b + "Wizard-Burst.png", "frames": 10, "fps": 22.0, "loop": false},
		{"name": "orb", "path": b + "Wizard-Orb.png", "frames": 7, "fps": 18.0, "loop": false},
	])
	_cache["wizard_fx"] = sf
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

## Monster-horde variety, all from the Full pack. Mapped onto the existing monster
## "kinds" in monster.gd (scout→werewolf, brute→werebear, minion→slime) — same stats,
## wildly different silhouettes, so a wave no longer reads as one recoloured orc.
static func werewolf() -> SpriteFrames:
	if _cache.has("werewolf"):
		return _cache["werewolf"]
	var b := FULL + "Werewolf/"
	var sf := _build([
		{"name": "idle", "path": b + "Werewolf-Idle.png", "frames": 6, "fps": 8.0, "loop": true},
		{"name": "walk", "path": b + "Werewolf-Walk.png", "frames": 8, "fps": 14.0, "loop": true},
		{"name": "attack", "path": b + "Werewolf-Attack01.png", "frames": 9, "fps": 16.0, "loop": false},
		{"name": "hurt", "path": b + "Werewolf-Hurt.png", "frames": 4, "fps": 12.0, "loop": false},
		{"name": "death", "path": b + "Werewolf-Death.png", "frames": 4, "fps": 8.0, "loop": false},
	])
	_cache["werewolf"] = sf
	return sf

static func werebear() -> SpriteFrames:
	if _cache.has("werebear"):
		return _cache["werebear"]
	var b := FULL + "Werebear/"
	var sf := _build([
		{"name": "idle", "path": b + "Werebear-Idle.png", "frames": 6, "fps": 7.0, "loop": true},
		{"name": "walk", "path": b + "Werebear-Walk.png", "frames": 8, "fps": 10.0, "loop": true},
		{"name": "attack", "path": b + "Werebear-Attack01.png", "frames": 9, "fps": 14.0, "loop": false},
		{"name": "hurt", "path": b + "Werebear-Hurt.png", "frames": 4, "fps": 12.0, "loop": false},
		{"name": "death", "path": b + "Werebear-Death.png", "frames": 4, "fps": 8.0, "loop": false},
	])
	_cache["werebear"] = sf
	return sf

static func slime() -> SpriteFrames:
	if _cache.has("slime"):
		return _cache["slime"]
	var b := FULL + "Slime/"
	var sf := _build([
		{"name": "idle", "path": b + "Slime-Idle.png", "frames": 6, "fps": 8.0, "loop": true},
		{"name": "walk", "path": b + "Slime-Walk.png", "frames": 6, "fps": 12.0, "loop": true},
		{"name": "attack", "path": b + "Slime-Attack01.png", "frames": 6, "fps": 14.0, "loop": false},
		{"name": "hurt", "path": b + "Slime-Hurt.png", "frames": 4, "fps": 12.0, "loop": false},
		{"name": "death", "path": b + "Slime-Death.png", "frames": 4, "fps": 8.0, "loop": false},
	])
	_cache["slime"] = sf
	return sf

static func arrow_texture() -> Texture2D:
	return load(RPG + "Arrow(Projectile)/Arrow01(100x100).png") as Texture2D

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
		var fh := tex.get_height()
		var n: int = d["frames"]
		for i in n:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * FW, 0, FW, fh)
			sf.add_frame(name, at)
	return sf
