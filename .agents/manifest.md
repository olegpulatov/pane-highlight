# pane-highlight manifest

source of truth for goals and decisions. agents check their work against it and discuss core changes with the owner before applying them.

in a plugin made from this base: replace "what it is" with the plugin's own purpose and features; the other sections stay as shared rules until changed.

## what it is

tern window plugin that marks the active pane in split views and recolors it while it works as a given user or on a given host. made to be shared as open source: published defaults are universal (`root`, `prod-*`, `dev-*`); personal rules live in each user's `config.json`.

features:

- active pane: inset border and a tint of the accent color over the terminal background, tint % separate for light and dark appearance (`light-dark()`)
- inactive panes: dimmed
- rules: ordered `{user?, host?, color}`, first match wins; colors are palette names or css colors; user palette entries add to the built-in one
- detection, window-scoped only: running command line from `cx.session:pane()` and command events, split into commands at `;`, `&&`, `||`, `|` (`ssh`, `tern ssh`, `su`, `sudo`, `sudo su`; no user = root), remoting host name and login user from `cx.hosts`, tern's own user. no `tern process` lookup: the plugin cannot learn its window key, so that cli reads the wrong window

limits, by tern: inactive panes have no per-pane css hook, so only the active pane takes a rule color; panes without shell integration report no command line; sudo credential caching is per terminal, so it is not detected.

## open work

bug: `ssh ops@n1` flashes the rule color, then falls back to accent. live trace in a pane with shell integration on the remote host:

- while ssh starts: `running.line = "ssh ops@n1"`, title `ssh ops@n1 …`
- remote prompt up: title `[n1] ~`, cwd `/home/ops`; running still the ssh line at first
- first remote command (`true`): running becomes nil, `last.line = "true"`. the remote shell's own command events replace the ssh context
- the flash itself is likely a `command_finished` for the ssh line when the remote prompt appears; not yet confirmed: the start/finish trace did not run
- root "works" only because `sudo -i` typed on n1 is itself a remote command line; it will drop the same way after the first command in the root shell
- `[host]` title prefix comes from tern's ssh-hop tracking (OSC 7); it carries the host, not the user

fix direction, not decided: remember the target per pane when an ssh/su/sudo-shell command starts, and keep it while the pane is inside that hop instead of trusting `running.line` alone. candidate lifetime signals to check in a trace: the `[host]` title prefix, `cx.session:pane().program` (earlier showed `ssh` for an ssh pane), local cwd returning. next step: trace start/finish/cwd/title events plus `program` while doing `ssh ops@n1`, a remote command, `exit`; same for `sudo -i` on the remote. the user left two test panes in window `--window 2` (ops at `[n1] ~`, root via `sudo -i`); test there only, never in window 1

requested, not yet done:

- default `border` 1px instead of 2px
- gentler red for the default `root` rule; add palette names `magma` `#FF7A3D` and `ember` `#b84a2c` (user named them magmaOrange and emberRed)

testing notes: offline matcher check lives outside the repo (`/tmp/ph-test/`: fake `tern` prelude + `window.luau` + cases, run with `luau`); lint needs `luau-lsp` on PATH (downloaded to `/tmp/luau-lsp/`). css rendering can be checked without touching user windows: `tern serve --control SOCK`, `tern ctl --control SOCK css pane-highlight FILE`, `split right`, `dump SELECTOR`, `appearance dark`, `shot NAME`

styling relies on tern's internal pane selectors (`.tn-pane.on`, `.tn-body`, `.tn-veil`); they are undocumented and may change between tern versions.

keep it readable and maintainable for future contributors. code, tooling, and documentation must earn their place.

## parts

- plugin package: `plugin.toml` + luau entry file(s), `--!strict`, at repo root
- user config: defaults in code, optional user file overrides them
- justfile: link, reload, types, test, lint, fmt, bump
- offline check: optional `check.lua` with a fake `tern`, run by stock lua. it never shapes the plugin code: when the entry file needs luau-only features, delete the check and verify live
- texts: `README.md` (what, install, config), `LICENSE`, `.agents/AGENTS.md`, this manifest
- tern awareness: agent rules point to public tern docs (https://docs.stencil.so/tern/), `tern help`, generated api types

## key decisions

layout

- one plugin per repo, package at repo root -> `tern plugin install github.com/OWNER/REPO` works with no path
- copy, not dependency: nothing from this repo is loaded at run time, so plugins never break when the base changes
- portable: runs wherever tern runs plugins (macos, linux, windows; window half also on ios). no owner-specific paths, nothing depends on files around the repo. paths from tern apis are fine
- the example feature is tiny and lives in the entry file only. a new plugin replaces it; no example tests or docs to clean up

code

- tern apis first: before own helpers or os-specific code, use what tern docs, api types, and cli offer
- tunable numbers and values are named constants in a header block at the top of the file
- api types come from `tern plugin types .` (writes `tern.d.luau` for luau-lsp); generated per tern version, not committed

config

- tern has no per-plugin settings, so the plugin reads its own file
- defaults = the constants in the header block. user-facing ones are documented in README
- user overrides live in `config.json` in the plugin data folder (`tern.plugin.data`). tern resolves this path on every os, and the folder survives reinstall and update
- users must find the file without reading code: README gives its full path for each os
- json only, because tern decodes it; other formats need a parser copied into every plugin. a missing file or key means the default. changes apply on `tern plugin reload`

versioning

- `plugin.toml` `version` is the only version
- each finished change to plugin code or `plugin.toml` gets one bump, not each edit. docs-only or tooling-only changes may skip it
- `just bump` bumps patch; an argument picks minor or major

## development

- order: finish the whole change -> run tests -> lint -> format (lint and format may swap)
- all checks run locally through `just`. no ci, no git hooks: hooks that rewrite files force agents to reread them
- lint = `luau-lsp analyze` with the generated types; format = `stylua`
- live check: `tern plugin reload` reloads host and window halves; its exit code reports host failures, window failures show as a toast

## tests

no test is better than a bad test. keep tests few.

- a test proves a claim: a decision in this manifest, a promise in README, or a bug a user really hit
- test behavior a user or caller sees, not how the code is split inside
- no copied logic: expected values are written by hand, not computed the way the code computes them
- a fake `tern` stubs only what tern provides; never mock the behavior under test
