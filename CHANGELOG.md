# changelog

changes users see, newest first. the version is `version` in `plugin.toml`.

## 0.2.0 - 2026-10-22

- new `single` config switch: also mark a pane shown alone, the only pane of a tab or a zoomed one. off by default; with it on, a single pane gets the border, the opaque tint and rule colors, so it stands out of a translucent window

## 0.1.8 - 2026-10-22

- panes with visible headers: the border goes around header and body together, and both take the tint. before, only the body was marked

## 0.1.7 - 2026-10-11

- logins typed in a pane are remembered: in `ssh a`, then `ssh b` on `a`, the pane keeps `b`'s color after commands typed there. `exit`, `logout`, a failed login, or a return to the directory a login was typed in (Ctrl-D) ends that login
- reads the focused pane in a way that works around a tern 0.7.2 bug with some pane ids
- a pane `tern process` cannot find is not asked again

## 0.1.6 - 2026-10-10

- the window that answered a `tern process` lookup is remembered: one lookup per check instead of a scan

## 0.1.5 - 2026-10-10

- agent and plugin panes get the foreground lookup too: they run programs

## 0.1.4 - 2026-10-10

- less work: only the focused pane is checked; browser, file and other panes without a program get no lookup; the style sheet is installed only when the color changes

## 0.1.3 - 2026-10-10

- the lookup asks the first window without `--window` first: its panes are not reached by any key
- default tint 3% light, 5% dark

## 0.1.2 - 2026-10-10

- the pane is checked again when its directory changes: leaving ssh may report no command finish

## 0.1.1 - 2026-10-10

- the pane's foreground program counts again (`ssh deploy@web1` for the whole session)
- the innermost login decides the color (`sudo -i` inside `ssh` is `root`)
- the lookup tries window keys 1 to 9
- 1px border, `ember` for `root`, new palette colors `magma` and `ember`

## 0.1.0 - 2026-10-10

- first release: border and tint on the active pane, dimmed inactive panes, user and host color rules, `config.json` overrides
