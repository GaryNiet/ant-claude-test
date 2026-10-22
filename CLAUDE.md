# Rules for working on this project

This is a Godot 4 (GDScript) video game prototype. Follow these rules on every request:

1. **Readable code first.** Short functions, descriptive names, a `##` doc comment at the
   top of each script and on non-obvious functions. Prefer plain, simple GDScript over clever tricks.
2. **No hard-coded values in code.** Every tunable number, color, text, key binding, etc.
   goes in `game_settings.cfg` (with a short comment) and is read via the `GameSettings`
   autoload (`get_setting`, `get_color`, `get_list`). Never add fallback defaults in code.
3. **Log every request** in `REQUEST_LOG.md`: add a new entry at the top with the date
   (YYYY-MM-DD), the user's request quoted verbatim, a short summary of what was done, and
   the commit(s) it produced. Since a commit can't contain its own hash, commit the work
   first, then add the hash(es) to the log in a follow-up commit `Log: request #N commits`.
4. Develop on the designated branch and push when done, so the user can `git pull` it.
5. **Use Godot 4.7** (the user's editor version) for every run, import and test, so the `.import`
   and `.uid` files stay identical to what the user's editor writes. After adding a script,
   image or sound, run `--headless --import` with 4.7 and commit the `.uid` / `.import` files it creates.
