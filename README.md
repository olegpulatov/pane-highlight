# pane-highlight

a tern plugin that marks the active pane in split views and recolors it while it works as a given user or on a given host.

- active pane: border and a light tint of the accent color
- other panes: dimmed
- rules: while the active pane works as a matching user or on a matching host, border and tint take the rule's color; back to accent when the session ends or focus moves

out of the box: `root` ember, `prod-*` hosts red, `dev-*` hosts mint.

what a rule sees:

- the command line running in the pane, from tern's shell integration: `ssh [user@]host`, `tern ssh …`, `su [user]`, `sudo [-u user] …`. `su` and `sudo` without a user mean `root`
- the pane's foreground program, from `tern process`: an `ssh deploy@web1` session counts for its whole length, also after commands typed on the remote machine
- tern remoting: the host name and login user of a remote pane
- tern's own user, for local panes

limits:

- inside an ssh session, a remote `sudo -i` or `su` counts only while tern's shell integration on the remote machine reports it as the running command
- `tern process` must be on PATH or at its default install path; without it, only the running command line counts
- a plugin cannot learn its own window key, so the lookup asks window keys 1 to 9 in turn. panes in a window with another key keep only the running command line
- only the active pane gets the rule color; tern gives inactive panes no per-pane style hook
- sudo's cached password ("no password for 5 minutes") is per terminal and not visible to plugins; a prompt module such as starship's `sudo` shows it

styling uses tern's internal pane selectors (`.tn-pane.on`, `.tn-body`, `.tn-veil`). a tern update may rename them; then the highlight disappears until the plugin is updated.

## install

```fish
tern plugin install github.com/OWNER/pane-highlight
```

for a local checkout: `just link`. tern loads the checkout directly; `tern plugin reload` applies edits.

## config

defaults live at the top of `window.luau`. to change them without editing code, create `config.json` in the plugin's data folder:

- macos: `~/Library/Application Support/Tern/plugin-data/pane-highlight/config.json`
- linux: `$XDG_STATE_HOME/tern/plugin-data/pane-highlight/config.json` (default `~/.local/state/tern/...`)
- windows: `%LOCALAPPDATA%\Tern\plugin-data\pane-highlight\config.json`
- with `TERN_CONFIG_DIR` set: `$TERN_CONFIG_DIR/plugin-data/pane-highlight/config.json`

defaults:

```json
{
  "tint": { "light": 7, "dark": 3 },
  "border": 1,
  "dim": 0.3,
  "colors": {},
  "rules": [
    { "user": "root", "color": "ember" },
    { "host": "prod-*", "color": "red" },
    { "host": "dev-*", "color": "mint" }
  ]
}
```

- `tint`: % of the color mixed into the terminal background, per theme appearance. dark themes need less
- `border`: border width in px, 0 = none. its color follows the tint color
- `dim`: veil opacity over inactive panes, 0 = no dimming
- `colors`: your own named colors; they add to or replace the built-in palette: `amber` `#F2B04C`, `red` `#E85B5B`, `magma` `#FF7A3D`, `ember` `#b84a2c`, `sage` `#6a9a6a`, `mint` `#35C28A`, `sky` `#6FB3FF`, `blue` `#5AA4FF`, `cyan` `#3FD3FF`, `rose` `#e5b4d4`
- `rules`: each has `color` (palette name or any css color) and `user`, `host`, or both. `host` takes `*` and `?` globs and matches the name as typed after `ssh`, so ssh config aliases work. the innermost login decides (`sudo -i` inside `ssh deploy@web1` is `root`); for it, rules are checked in order and the first match wins. your `rules` replace the default list

example: amber for user `ops`, keep the defaults:

```json
{
  "rules": [
    { "user": "ops", "color": "amber" },
    { "user": "root", "color": "ember" },
    { "host": "prod-*", "color": "red" },
    { "host": "dev-*", "color": "mint" }
  ]
}
```

missing file or key -> default. a broken file stops the plugin with an error toast that names the problem. reinstall and update keep the file. after editing, run `tern plugin reload`.

## develop

install `tern`, `just`, lua, `luau-lsp`, and `stylua` with luau support. run `just` for available commands.

```fish
just lint
just fmt
```

lint generates current tern api types and checks plugin source; format covers lua/luau files. generated types are not committed. there are no automated tests: the plugin uses luau-only syntax, so check changes live with `tern plugin reload`.

`just bump` bumps patch; `just bump minor` and `just bump major` pick another part. only `plugin.toml` holds the version.

## license

mit, see `LICENSE`.
