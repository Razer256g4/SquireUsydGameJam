extends RefCounted
class_name Sfx
## Central audio helper — same static-factory idiom as Fx / Telegraph / Hazard /
## Settings (called as `Sfx.play("boom")`, no instance, no autoload). It lazily
## spawns a persistent player bank under the scene-tree ROOT on first use, so it
## survives scene reloads (R / restart) like an autoload would.
##
## MIX PHILOSOPHY — make it blend, never obtrude:
##   * GAIN STAGING: every key has a base dB trimmed by how loud/frequent it is.
##     Constant combat chatter (hits, swings, casts, zaps) sits well below the rare
##     punctuation (explosions, betrayal, win/lose). Kenney clips aren't loudness-
##     normalised, so this is what stops the mix turning into noise.
##   * POLYPHONY: a fixed pool of voices (round-robin steal). The same key can't
##     retrigger faster than its per-key GAP, so a 67-swarm reads as intensity, not
##     a machine gun, and mass events (enrage/defect on every monster) swell ONCE.
##   * SAFETY: a hard limiter on the Master bus means stacked SFX + music can't clip.
##   * VARIETY: each key holds an ARRAY of variants; play() picks one + jitters pitch.
##   * PARTIAL-PACK SAFE: a missing key/file is a silent no-op.
## MUSIC: one looping player on a quiet "Music" bus, sitting under the SFX as a bed.

const POOL_SIZE := 16
const DEFAULT_GAP := 45                     # fallback min-ms between two plays of a key
const ROOT := "res://assets/audio/"
const MUSIC_DIR := "res://assets/audio/music/"
const MASTER_CEILING_DB := -1.0             # limiter ceiling so the mix never clips

static var _players: Array[AudioStreamPlayer] = []
static var _music: AudioStreamPlayer = null
static var _holder: Node = null             # parents the pool; lives under root across reloads
static var _pending_music := ""             # track requested before the holder was in-tree
static var _next := 0                       # round-robin cursor
static var _last := {}                      # key -> Time.get_ticks_msec() of last play
static var _lib := {}                       # key -> Array[AudioStream]
static var _cfg := {}                       # key -> {"vol": dB, "gap": ms}
static var _booted := false

# --- lazy boot (no autoload) -----------------------------------------------
static func _boot() -> void:
	if _booted:
		return
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	var root := (loop as SceneTree).root
	if root == null:
		return
	_booted = true
	_ensure_bus("SFX")
	_ensure_bus("Music")
	_install_master_limiter()
	_holder = Node.new()
	_holder.name = "SfxHolder"
	for _i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		_holder.add_child(p)                # parenting to a still-free node is always allowed
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_holder.add_child(_music)
	_build_library()
	_build_config()
	_apply()
	# Attach under root DEFERRED: the first Sfx call comes from Game._ready(), during
	# which root is "blocked" (mid-adding the scene) and a direct add_child is rejected,
	# leaving every player outside the tree -> total silence. Deferring lands it safely
	# at idle, then we kick off any music that was requested before the holder existed.
	root.add_child.call_deferred(_holder)
	Sfx._start_pending_music.call_deferred()

## Begin any music requested before the holder finished entering the tree.
static func _start_pending_music() -> void:
	if _pending_music != "":
		var n := _pending_music
		_pending_music = ""
		play_music(n)

## Stable hook the intro / cutscene call on the first user interaction. The web
## AudioContext is already live from boot in our itch embed (music is no longer gated
## behind it), so this just kicks any track still pending the holder's tree-attach.
static func unlock() -> void:
	_start_pending_music()

# --- SFX --------------------------------------------------------------------
## Fire a sound. `key` is a logical event name. Base gain + throttle come from the
## per-key mix config; `volume_db` is an optional extra trim, `pitch_var` the ±
## random pitch spread.
static func play(key: String, pitch_var := 0.06, volume_db := 0.0) -> void:
	_boot()
	if _players.is_empty() or not _players[0].is_inside_tree():
		return                              # holder not attached yet (first frame) — skip silently
	if _pending_music != "":
		_start_pending_music()              # backup: ensure music started even if the deferred kick missed
	if Settings.sfx_volume <= 0.001 or Settings.master_volume <= 0.001:
		return
	var clips: Array = _lib.get(key, [])
	if clips.is_empty():
		return                              # partial-pack safe
	var cfg: Dictionary = _cfg.get(key, {})
	var gap: int = cfg.get("gap", DEFAULT_GAP)
	var now := Time.get_ticks_msec()
	var last: int = _last.get(key, -100000)
	if now - last < gap:                    # collapse a burst of identical hits to one voice
		return
	_last[key] = now
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = clips[randi() % clips.size()] as AudioStream
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.volume_db = float(cfg.get("vol", 0.0)) + volume_db
	p.play()

# --- music ------------------------------------------------------------------
## Loop a background track from assets/audio/music/<name>.ogg as a quiet bed.
static func play_music(name: String, volume_db := -7.0) -> void:
	_boot()
	if _music == null:
		return
	if not _music.is_inside_tree():
		_pending_music = name               # holder attaches deferred; _start_pending_music() retries
		return
	var path := "%s%s.ogg" % [MUSIC_DIR, name]
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	if _music.stream == stream and _music.playing:
		return                              # already on this track — don't restart
	stream.set("loop", true)                # harmless no-op for stream types without a loop flag
	_music.stream = stream
	_music.volume_db = volume_db
	_music.play()

static func stop_music() -> void:
	if _music:
		_music.stop()

# --- volumes (driven by the pause-menu sliders) ----------------------------
static func apply_volumes() -> void:
	_boot()
	_apply()

static func _apply() -> void:
	_set_bus("SFX", Settings.sfx_volume)
	_set_bus("Music", Settings.music_volume)
	_set_bus("Master", Settings.master_volume)

static func _set_bus(bus_name: String, vol: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, vol <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(0.001, vol)))

static func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")

## Brick-wall the Master output so a pile-up of SFX + music can never clip/distort.
static func _install_master_limiter() -> void:
	var master := AudioServer.get_bus_index("Master")
	if master < 0 or AudioServer.get_bus_effect_count(master) > 0:
		return
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = MASTER_CEILING_DB
	AudioServer.add_bus_effect(master, lim)

# --- clip library -----------------------------------------------------------
## Map each logical event to its clips. Missing files are skipped (partial-pack safe).
static func _build_library() -> void:
	_lib = {
		# combat / actors
		"swing":          _pack("rpg", ["knifeSlice", "knifeSlice2", "chop"]),
		"enemy_swing":    _pack("rpg", ["chop", "knifeSlice"]),
		"enemy_hurt":     _seq("impact", "impactPunch_medium", 5),
		"enemy_die":      _seq("impact", "impactSoft_heavy", 5),
		"player_hurt":    _seq("impact", "impactPunch_heavy", 5),
		"player_die":     _seq("impact", "impactGlass_heavy", 5),
		"boom":           _seq("scifi", "explosionCrunch", 5),          # real AoE explosion
		"zap":            _seq("scifi", "laserLarge", 5),               # beam / charge / smite
		"cast":           _pack("rpg", ["cloth1", "cloth2", "cloth3", "cloth4"]),  # subtle whoosh (very frequent)
		# squire actions / gifts
		"dash":           _pack("rpg", ["cloth1", "cloth2"]),
		"pickup":         _pack("rpg", ["handleCoins", "handleCoins2"]),
		"princess_drink": _pack("rpg", ["metalPot1", "metalPot2", "metalPot3"]),
		"princess_arm":   _pack("rpg", ["drawKnife1", "drawKnife2", "drawKnife3"]),
		"gift_curse":     _pack("rpg", ["creak1", "creak2", "creak3"]),
		"tipoff":         _pack("rpg", ["metalClick", "metalLatch"]),
		"enrage":         _seq("impact", "impactSoft_medium", 5),
		"defect":         _pack("rpg", ["metalLatch", "beltHandle1"]),
		# events / chaos
		"explosion_big":  _seq("scifi", "lowFrequency_explosion", 2),   # deep huge boom (plane crash)
		"crowd":          _seq("impact", "footstep_concrete", 5),
		"infighting":     _seq("impact", "impactGeneric_light", 5),
		"swarm":          _seq("impact", "impactTin_medium", 5),
		"trap_spawn":     _seq("impact", "impactWood_heavy", 5),
		"trap_hit":       _seq("impact", "impactMetal_light", 5),
		"angel":          _seq("scifi", "laserLarge", 5),               # heavenly beams descend
		# system / UI stings
		"wave_start":     _pack("ui", ["switch20"]),
		"wave_clear":     _pack("ui", ["switch21"]),
		"levelup":        _pack("ui", ["switch15"]),
		"betray_sting":   _seq("scifi", "lowFrequency_explosion", 2),   # deep WHOOM as she turns
		"betray_roar":    _seq("impact", "impactMetal_heavy", 5),
		"win":            _pack("ui", ["switch31"]),
		"lose":           _pack("impact", ["impactGlass_heavy_004"]),
		"ui_click":       _pack("ui", ["click1", "click2", "click3", "click4", "click5"]),
		"ui_hover":       _pack("ui", ["rollover1", "rollover2", "rollover3"]),
		"ui_toggle":      _pack("ui", ["switch1"]),
	}

## Per-key MIX: base gain (dB, negative = quieter) + min retrigger gap (ms).
## Rule of thumb: the more often a sound fires, the quieter and more throttled it is;
## rare punctuation sits loudest. Unlisted keys default to {vol 0, gap DEFAULT_GAP}.
static func _build_config() -> void:
	_cfg = {
		# constant combat chatter — pushed down, throttled so hordes don't machine-gun
		"swing":          {"vol": -9.0,  "gap": 55},
		"enemy_swing":    {"vol": -13.0, "gap": 90},
		"enemy_hurt":     {"vol": -11.0, "gap": 60},
		"enemy_die":      {"vol": -8.0,  "gap": 70},
		"player_hurt":    {"vol": -4.0,  "gap": 110},
		"player_die":     {"vol": -2.0,  "gap": 200},
		"boom":           {"vol": -9.0,  "gap": 90},
		"zap":            {"vol": -12.0, "gap": 75},
		"cast":           {"vol": -16.0, "gap": 110},
		"trap_hit":       {"vol": -12.0, "gap": 90},
		# squire actions / gifts — player-driven, moderate
		"dash":           {"vol": -11.0, "gap": 90},
		"pickup":         {"vol": -7.0,  "gap": 60},
		"princess_drink": {"vol": -6.0,  "gap": 80},
		"princess_arm":   {"vol": -6.0,  "gap": 80},
		"gift_curse":     {"vol": -8.0,  "gap": 90},
		"tipoff":         {"vol": -7.0,  "gap": 150},
		# mass-trigger (fire for every monster at once) — long gap = ONE swell, not forty
		"enrage":         {"vol": -10.0, "gap": 220},
		"defect":         {"vol": -9.0,  "gap": 220},
		# events / chaos — rarer, can be present
		"explosion_big":  {"vol": -2.0,  "gap": 300},
		"crowd":          {"vol": -9.0,  "gap": 250},
		"infighting":     {"vol": -8.0,  "gap": 250},
		"swarm":          {"vol": -7.0,  "gap": 250},
		"trap_spawn":     {"vol": -8.0,  "gap": 200},
		"angel":          {"vol": -6.0,  "gap": 200},
		# system / UI stings — sparse punctuation, allowed to read clearly
		"wave_start":     {"vol": -7.0,  "gap": 200},
		"wave_clear":     {"vol": -7.0,  "gap": 200},
		"levelup":        {"vol": -8.0,  "gap": 150},
		"betray_sting":   {"vol": -2.0,  "gap": 500},
		"betray_roar":    {"vol": -6.0,  "gap": 500},
		"win":            {"vol": -4.0,  "gap": 500},
		"lose":           {"vol": -4.0,  "gap": 500},
		"ui_click":       {"vol": -9.0,  "gap": 40},
		"ui_hover":       {"vol": -14.0, "gap": 40},
		"ui_toggle":      {"vol": -10.0, "gap": 40},
	}

## Load named clips from a subfolder, dropping any that are missing (partial-pack safe).
static func _pack(dir: String, names: Array) -> Array:
	var out := []
	for n in names:
		var path := "%s%s/%s.ogg" % [ROOT, dir, n]
		if ResourceLoader.exists(path):
			var s := load(path)
			if s != null:
				out.append(s)
	return out

## Load a numbered Kenney variant run: base_000 .. base_(count-1).
static func _seq(dir: String, base: String, count: int) -> Array:
	var names := []
	for i in count:
		names.append("%s_%03d" % [base, i])
	return _pack(dir, names)
