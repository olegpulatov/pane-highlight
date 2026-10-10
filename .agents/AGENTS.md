@manifest.md

tern docs: https://docs.stencil.so/tern/
installed cli: `tern help`, `tern COMMAND --help`
api types: `just types` -> `tern.d.luau`

## tern 0.7.1 quirks

observed live with tern 0.7.1 (487bca1); recheck after a tern update.

windows and the cli

- a window half does not know its window key: `tern.getenv("TERN_WINDOW_KEY")` is nil (it reads the daemon's env) and no api field has it
- every `tern` verb works on one window: `--window KEY`, else `$TERN_WINDOW_KEY`, else the first window. a `tern` spawned by `tern.process.run` or from an agent shell without that variable hits the first window
- a pane of another window, or an unknown window key, gives the same error: `no block is called <id>`, status 1
- the first window's panes have an empty `TERN_WINDOW_KEY` and are reached only without `--window` (`--window 1` is not it). windows opened later had keys like `2`. so the plugin asks without `--window`, then `--window 1..9`, until status 0
- pane ids differed across windows in every check; the docs do not promise it
- `tern split ... --json` prints `{session, tab, block}`: the new id is `block`, not `id`

commands and ssh

- `tern process --window K <pane> --json` gives `foreground.argv`, e.g. `ssh user@host`, for the whole ssh session
- PaneInfo has no argv or command field; `running.line` is the only command text. a pane made with `tern split ... -- cmd` runs `fish -l -c "cmd"`
- with tern shell integration on the remote host, remote commands replace the pane's command state: after the first remote command `running` is nil and `last.line` is that command
- leaving a real ssh session kept the rule color until the plugin also rechecked on `cwd` events; with that recheck the color resets (confirmed by the owner). not traced: whether `command_finished` for the local `ssh` line is missing, and whether `cwd` is the event that fixed it
- one `cd` in a local fish pane fired `command_started`, `command_finished`, `cwd` and several `title` events; a lookup per event cost 7 processes, so the plugin does not hook `title`

styling

- `.tn-pane` carries only classes `on`, `dim`, `multi`; `data-pane` exists only on tab-bar dots. inactive panes cannot get per-pane css

testing and debugging

- `tern plugin reload` reloads the plugin in every window; each window runs its own VM, so log lines from all windows mix. put the pane id in debug lines
- `tern.log.warn` goes to the app log (macos: `~/Library/Logs/Tern/tern.log`)
- `tern.process.run` raises when the program cannot start: wrap it in `pcall`. an app started from the dock may not have `tern` on PATH
- css without touching real windows: `tern serve --control SOCK`, then `tern ctl --control SOCK ready|split right|css pane-highlight FILE|dump SELECTOR|appearance dark|shot NAME|quit`
- test only in a window made for testing; `tern run|focus|capture --window KEY` reach it from outside
- `luau-lsp` is not in homebrew: download the release binary and put it on PATH for `just lint`
