# Request log

Newest first. Each entry: date, request (verbatim), what was done, commits.

---

## #1 — 2026-10-20

**Request:**
> I'm making a prototype for a video game using Godot.
> I want you to generate the code, keep it as readable as possible by humans, make all hard
> coded variables modifiable on a single text file. Keep a log in a file, dated, of all my
> request and log which commits correspond to the demand.
> I just want to pull the code from my home PC when it's done. Is this possible?

**Done:**
- Set up a minimal Godot 4 project: a colored square you move with arrows/WASD.
- `game_settings.cfg`: single text file holding every tunable value, read by the
  `GameSettings` autoload (`scripts/game_settings.gd`).
- This request log, plus `CLAUDE.md` rules so every future change follows the same conventions.
- README with instructions to pull and run on your PC.

**Commits:**
- `67f89cb` — Set up Godot prototype with central settings file and request log
