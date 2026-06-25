Background music goes here. Tracks are loaded by name (the loader accepts .ogg/.mp3/.wav,
first match wins -- see scripts/sfx.gd -> _find / play_music / serving_music):

  menu.mp3        - intro / controls briefing (crossfades into serving when you start)
  serving.mp3     - calm serving bed; suspicion 0-40%      (commissioned "suspicion0-33")
  suspicion2.mp3  - tension layer; crossfades in at 40%+   (commissioned "level 2")
  suspicion3.mp3  - dread layer; crossfades in at 85%+     (commissioned "level 3 / final")
  boss.ogg        - once the Princess turns on you (boss phase)   [still a placeholder]

SUSPICION-REACTIVE SCORE: during the serving phase the music crossfades up through the
SERVING_BANDS table in sfx.gd as the suspicion meter climbs (calm -> tension -> dread), and
back down with hysteresis if you regain her trust. Dread lands at 85% (not 100%) because at
100% she betrays you and the music hard-cuts to the boss track. Tweak the thresholds/add a
band by editing SERVING_BANDS ({"at": <frac>, "name": "<file>"}).

Drop a file with the right name into this folder and it starts working automatically --
no code changes needed. A missing track is simply silent (no errors).

Volume is controlled by the "Music volume" slider in the pause menu (Esc).

Good CC0 (no-attribution) sources for loopable game music:
  - Tallbeard Studios "Music Loop Bundle" (itch.io, CC0)
  - OpenGameArt.org  (filter to CC0)
  - Kenney "Music Jingles" / "Music Loops" (kenney.nl, CC0) -- short, more stingers
