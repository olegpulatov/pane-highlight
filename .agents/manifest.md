# tern-plugin-base manifest

source of truth for goals and decisions. agents check their work against it and discuss core changes with the owner before applying them.

in a plugin made from this base: replace "what it is" with the plugin's own purpose and features; the other sections stay as shared rules until changed.

## what it is

starter repo for my tern terminal plugins. a new plugin starts as a plain copy or clone of this folder. my plugins share structure, install the standard tern way, and are ready to publish as open source.

goal: run 5-50 plugins without friction. agents spend effort on features; i change params, check, and publish without thinking about the base.

it offers a usable default, not a framework. a plugin may delete any part or ignore the base completely.

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
