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
# Global SFX trim added on top of every per-key vol. The commissioned clips are mastered
# hotter than the old Kenney placeholders the per-key gains were calibrated for, so the
# whole SFX layer ran too loud — this pulls it down uniformly (the per-key BALANCE below is
# preserved; this is the one knob for "all SFX too loud").
const MIX_TRIM := -3.0
# Accepted source formats, in preference order. The commissioned originals ship as .mp3
# (web-friendly size); the remaining CC0 placeholders are .ogg. Godot imports all three
# natively, so the loader is format-agnostic — a clip resolves to the first ext present.
const AUDIO_EXTS: Array[String] = [".ogg", ".mp3", ".wav"]
const MUSIC_BED_DB := -7.0                  # serving/menu/boss bed level (under the SFX)
# Suspicion-reactive serving score: tracks by ASCENDING suspicion band, each
# {at: threshold 0..1, name}. serving_music(frac) crossfades up to the highest band the
# meter has reached (and back down, with hysteresis), so the music sours calm -> tension as
# she closes in. A quick dip-and-swap on one player (robust whether or not the stems are
# sample-aligned), not a sustained simultaneous layer mix. The dread stem (suspicion3) is NOT
# a serving band — it's the boss track once she knows (see _betray() in game.gd).
const SERVING_BANDS := [
	{"at": 0.0,  "name": "serving"},        # calm bed (commissioned "suspicion0-33")
	{"at": 0.50, "name": "suspicion2"},     # tension — once she starts to doubt (50%+)
]

static var _players: Array[AudioStreamPlayer] = []
static var _music: AudioStreamPlayer = null
static var _holder: Node = null             # parents the pool; lives under root across reloads
static var _pending_music := ""             # track requested before the holder was in-tree
static var _music_name := ""                # name of the track currently on _music
static var _serving_band := -1              # active SERVING_BANDS index (-1 = not in the reactive serving score)
static var _xfade: Tween = null             # in-flight crossfade tween (killed before any new music command)
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
	p.volume_db = float(cfg.get("vol", 0.0)) + volume_db + MIX_TRIM
	p.play()

# --- music ------------------------------------------------------------------
## Loop a background track from assets/audio/music/<name> as a quiet bed (hard cut).
## Used for the standalone cues: menu / boss / (future victory, defeat). The serving
## phase instead drives serving_music() for the suspicion-reactive crossfade.
static func play_music(name: String, volume_db := MUSIC_BED_DB) -> void:
	_boot()
	if _music == null:
		return
	if not _music.is_inside_tree():
		_pending_music = name               # holder attaches deferred; _start_pending_music() retries
		return
	_kill_xfade()                           # cancel any in-flight crossfade before a hard swap
	_serving_band = -1                      # leaving the reactive serving score (menu/boss/etc.)
	var path := _find("%s%s" % [MUSIC_DIR, name])
	if path == "":
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	_music_name = name
	if _music.stream == stream and _music.playing:
		return                              # already on this track — don't restart
	stream.set("loop", true)                # harmless no-op for stream types without a loop flag
	_music.stream = stream
	_music.volume_db = volume_db
	_music.play()

## Suspicion-reactive serving score. Call every serving-phase frame with suspicion/MAX
## (0..1): keeps the serving music playing and crossfades to the band matching the meter,
## with a little hysteresis so it doesn't flap on the boundary. Idempotent within a band.
static func serving_music(frac: float) -> void:
	_boot()
	if _music == null or not _music.is_inside_tree():
		return                              # not attached yet — the raw play_music start handles frame 1
	var cur := maxi(0, _serving_band)
	var target := cur
	while target + 1 < SERVING_BANDS.size() and frac >= float(SERVING_BANDS[target + 1]["at"]):
		target += 1                         # climb to the highest band the meter has reached
	while target > 0 and frac < float(SERVING_BANDS[target]["at"]) - 0.05:
		target -= 1                         # only step back down once clearly under the threshold
	if target == _serving_band:
		return
	# Adopt an already-playing calm track (e.g. started raw after an R-restart) without a swap.
	if _serving_band == -1 and target == 0 and _music_name == "serving" and _music.playing:
		_serving_band = 0
		return
	_serving_band = target
	_crossfade_music(String(SERVING_BANDS[target]["name"]))

## Dip the current track out, swap streams, fade the new one in (~0.8 s total) — one player.
static func _crossfade_music(name: String) -> void:
	var path := _find("%s%s" % [MUSIC_DIR, name])
	if path == "":
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	_kill_xfade()
	_music_name = name
	_xfade = _holder.create_tween()
	if _music.playing:
		_xfade.tween_property(_music, "volume_db", -40.0, 0.35)
	_xfade.tween_callback(func() -> void:
		stream.set("loop", true)
		_music.stream = stream
		_music.volume_db = -40.0
		_music.play())
	_xfade.tween_property(_music, "volume_db", MUSIC_BED_DB, 0.45)

static func _kill_xfade() -> void:
	if _xfade != null and _xfade.is_valid():
		_xfade.kill()
	_xfade = null

static func stop_music() -> void:
	_kill_xfade()
	_serving_band = -1
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
	# Commissioned originals live in assets/audio/orig/<key>/ (one folder per logical key,
	# the composer's own variant filenames). Re-pointed here once — this map is the single
	# source of truth. Any key whose folder is absent falls back to silence (partial-pack safe).
	_lib = {
		# combat / actors
		"swing":          _pack("orig/swing",          ["swing_1", "swing_2", "swing_3", "swing_4"]),
		"enemy_swing":    _pack("orig/enemy_swing",    ["enemyswing_1", "enemyswing_2", "enemyswing_3", "enemyswing_4"]),
		"enemy_hurt":     _pack("orig/enemy_hurt",     ["enemyhurt_1", "enemyhurt_2", "enemyhurt_3", "enemyhurt_4", "enemyhurt_5"]),
		"enemy_die":      _pack("orig/enemy_die",      ["enemydie_1", "enemydie_2", "enemydie_3", "enemydie_4", "enemydie_5", "enemydie_6"]),
		"player_hurt":    _pack("orig/player_hurt",    ["squirehurt_1", "squirehurt_2", "squirehurt_3", "squirehurt_4", "squirehurt_5"]),
		"player_die":     _pack("orig/player_die",     ["playerdeath_1", "playerdeath_2", "playerdeath_3", "playerdeath_4", "playerdeath_5"]),
		"princess_fall":  _pack("orig/princess_fall",  ["princessdeath_1", "princessdeath_2", "princessdeath_3", "princessdeath_4", "princessdeath_5"]),  # her fall = the win; split out from player_die
		"boom":           _pack("orig/boom",           ["explosion_1", "explosion_2", "explosion_3"]),  # arcane AoE blast
		"zap":            _pack("orig/zap",            ["zap_1", "zap_2", "zap_3", "zap_4", "zap_5"]),   # beam / charge / smite
		"cast":           _pack("orig/cast",           ["cast_1", "cast_2", "cast_3", "cast_4"]),        # subtle shimmer-whoosh (very frequent)
		# squire actions / gifts
		"dash":           _pack("orig/dash",           ["dash_1", "dash_2", "dash_3"]),
		"pickup":         _pack("orig/pickup",         ["itempickup"]),
		"princess_drink": _pack("orig/princess_drink", ["princess_drink"]),
		"princess_arm":   _pack("orig/princess_arm",   ["princess_arm"]),
		"gift_curse":     _pack("orig/gift_curse",     ["gift_curse"]),    # the sabotage tell
		"tipoff":         _pack("orig/tipoff",         ["tipoff"]),
		"enrage":         _pack("orig/enrage",         ["enrage"]),
		"defect":         _pack("orig/defect",         ["defect"]),
		# events / chaos
		"explosion_big":  _pack("orig/explosion_big",  ["planecrash"]),    # deep huge boom (plane crash)
		"crowd":          _pack("orig/crowd",          ["peasantrevolt"]),
		"infighting":     _pack("orig/infighting",     ["infighting"]),
		"swarm":          _pack("orig/swarm",          ["67"]),            # the "67" tiny-minion gag
		"trap_spawn":     _pack("orig/trap_spawn",     ["traplay"]),
		"trap_hit":       _pack("orig/trap_hit",       ["traphit"]),
		"angel":          _pack("orig/angel",          ["angel"]),         # heavenly beams descend
		# system / UI stings
		"wave_start":     _pack("orig/wave_start",     ["wavestart"]),
		"wave_clear":     _pack("orig/wave_clear",     ["waveclear"]),
		"levelup":        _pack("orig/levelup",        ["princesslevelup"]),
		"betray_sting":   _pack("orig/betray_sting",   ["betray_sting"]),  # deep WHOOM as she turns
		"betray_roar":    _pack("orig/betray_roar",    ["betray_roar", "betray_roar2"]),
		"win":            _pack("orig/win",            ["win"]),
		"lose":           _pack("orig/lose",           ["lose"]),
		"ui_click":       _pack("orig/ui_click",       ["ui_click"]),
		"ui_hover":       _pack("orig/ui_hover",       ["ui_hover"]),
		"ui_toggle":      _pack("orig/ui_toggle",      ["ui_toggle"]),
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
		"player_hurt":    {"vol": -7.0,  "gap": 110},
		"player_die":     {"vol": -9.0,  "gap": 200},
		"princess_fall":  {"vol": -8.0,  "gap": 400},   # one-shot; her fall is THE big reverent moment
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
		"explosion_big":  {"vol": -9.0,  "gap": 300},
		"crowd":          {"vol": -9.0,  "gap": 250},
		"infighting":     {"vol": -8.0,  "gap": 250},
		"swarm":          {"vol": -7.0,  "gap": 250},
		"trap_spawn":     {"vol": -8.0,  "gap": 200},
		"angel":          {"vol": -6.0,  "gap": 200},
		# system / UI stings — sparse punctuation, allowed to read clearly
		"wave_start":     {"vol": -7.0,  "gap": 200},
		"wave_clear":     {"vol": -7.0,  "gap": 200},
		"levelup":        {"vol": -9.0,  "gap": 150},
		"betray_sting":   {"vol": -9.0,  "gap": 500},
		"betray_roar":    {"vol": -9.0,  "gap": 500},
		"win":            {"vol": -11.0, "gap": 500},
		"lose":           {"vol": -11.0, "gap": 500},
		"ui_click":       {"vol": -9.0,  "gap": 40},
		"ui_hover":       {"vol": -14.0, "gap": 40},
		"ui_toggle":      {"vol": -10.0, "gap": 40},
	}

## Resolve a path-without-extension to the first existing AUDIO_EXTS variant ("" if none).
static func _find(base: String) -> String:
	for ext in AUDIO_EXTS:
		var path := base + ext
		if ResourceLoader.exists(path):
			return path
	return ""

## Load named clips from a subfolder, dropping any that are missing (partial-pack safe).
static func _pack(dir: String, names: Array) -> Array:
	var out := []
	for n in names:
		var path := _find("%s%s/%s" % [ROOT, dir, n])
		if path != "":
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
