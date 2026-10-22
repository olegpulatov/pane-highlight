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
- tern 0.7.2 (5d1cc64), proven: in windows 2 and 3, `cx.session:pane(cx.session:focused())` is nil; `cx.session:pane("@focused")` and `cx.session:panes()` list the same id. example: window half `6180457938948` (0x59f00000004), cli `23772643983364` (0x159f00000004), and `tern process --window 2 6180457938948` says `no block is called`. a cli/window id difference alone is documented (remote host tag moved from bit 56 to bit 44, `docs/tern/concepts/runtime.md`); the nil round trip is the defect. hypotheses, not verified: it hits all panes with cli id ≥ 2^44, also in window 1, and those are panes made after a tern start

commands and ssh

- `tern process --window K <pane> --json` gives `foreground.argv`, e.g. `ssh user@host`, for the whole ssh session
- PaneInfo has no argv or command field; `running.line` is the only command text. a pane made with `tern split ... -- cmd` runs `fish -l -c "cmd"`
- with tern shell integration on the remote host, remote commands replace the pane's command state: after the first remote command `running` is nil and `last.line` is that command
- interactive `ssh host` with remote shell integration: `command_finished` status 0 fires ~300 ms after start, when the remote prompt shows. a failed ssh finishes with 255; `ssh host cmd` finishes when cmd ends
- Ctrl-D out of a hop fires only `cwd` and `title` events, and only when the directory differs; between two hops in the same directory it fires nothing
- one `command_started` can arrive twice within 1 ms in the same plugin copy
- one `cd` in a local fish pane fired `command_started`, `command_finished`, `cwd` and several `title` events; a lookup per event cost 7 processes, so the plugin does not hook `title`

styling

- `.tn-pane` carries classes `on`, `dim`, `multi`, and `headed` when pane headers are visible; `data-pane` exists only on tab-bar dots. inactive panes cannot get per-pane css
- `tern.css` replaces the whole sheet, so the window restyles on each call: call it only when the css text changes (docs say "replaces"; the restyle cost itself was not measured)

testing and debugging

- `tern plugin reload` reloads the plugin in every window; each window runs its own VM, so log lines from all windows mix. put the pane id in debug lines
- `tern.log.warn` goes to the app log (macos: `~/Library/Logs/Tern/tern.log`)
- `tern.process.run` raises when the program cannot start: wrap it in `pcall`. an app started from the dock may not have `tern` on PATH
- css without touching real windows: `tern serve --control SOCK`, then `tern ctl --control SOCK ready|split right|css pane-highlight FILE|dump SELECTOR|appearance dark|shot NAME|quit`
- test only in a window made for testing; `tern run|focus|capture --window KEY` reach it from outside
- `luau-lsp` is not in homebrew: download the release binary and put it on PATH for `just lint`
