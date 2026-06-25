Background music goes here. Tracks are loaded by name (the loader accepts .ogg/.mp3/.wav,
first match wins -- see scripts/sfx.gd -> _find / play_music / serving_music):

  menu.mp3        - intro / controls briefing (crossfades into serving when you start)
  serving.mp3     - calm serving bed; suspicion 0-50%      (commissioned "suspicion0-33")
  suspicion2.mp3  - tension layer; crossfades in at 50%+   (commissioned "level 2")
  suspicion3.mp3  - dread/final track; plays once she betrays you  (commissioned "level 3 / final")
  boss.ogg        - old boss placeholder [no longer used -- suspicion3 scores the boss fight now]

SUSPICION-REACTIVE SCORE: every track swap is a HARD CUT -- the layers are separate, never
blended. During the serving phase the music snaps up through the SERVING_BANDS table in
sfx.gd as the suspicion meter climbs (calm -> tension at 50%), and back down with hysteresis
if you regain her trust. When suspicion hits 100% she betrays you ("she knows") and _betray()
cuts to suspicion3 (dread) for the boss fight. On victory/defeat the music STOPS (silence --
only the win/lose sting plays). Tweak the thresholds/add a band by editing SERVING_BANDS.

Drop a file with the right name into this folder and it starts working automatically --
no code changes needed. A missing track is simply silent (no errors).

Volume is controlled by the "Music volume" slider in the pause menu (Esc).

Good CC0 (no-attribution) sources for loopable game music:
  - Tallbeard Studios "Music Loop Bundle" (itch.io, CC0)
  - OpenGameArt.org  (filter to CC0)
  - Kenney "Music Jingles" / "Music Loops" (kenney.nl, CC0) -- short, more stingers
