Background music goes here.

The game looks for looping tracks by name (see scripts/sfx.gd -> play_music):

  serving.ogg   - plays on a loop during the "serving" phase (the waves)
  boss.ogg      - plays on a loop once the Princess turns on you (boss phase)

Drop .ogg files with exactly those names into this folder and they start working
automatically -- no code changes needed. Until then the game is simply silent
(play_music() no-ops when the file is missing, so there are no errors).

Volume is controlled by the "Music volume" slider in the pause menu (Esc).

Good CC0 (no-attribution) sources for loopable game music:
  - Tallbeard Studios "Music Loop Bundle" (itch.io, CC0)
  - OpenGameArt.org  (filter to CC0)
  - Kenney "Music Jingles" / "Music Loops" (kenney.nl, CC0) -- short, more stingers
