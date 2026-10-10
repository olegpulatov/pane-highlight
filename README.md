# tern-plugin-base

a copyable foundation for tern plugins: package, config, and dev commands. the example logs a greeting on load.

## start

copy or clone this folder. change the identity in `plugin.toml`, replace the example with your feature, and update this readme and `.agents/manifest.md`.

```fish
just link
```

tern loads the checkout directly and reloads when package files change.

## config

defaults live at the top of `host.luau`. to change them without editing code, create `config.json` in the plugin's data folder:

- macos: `~/Library/Application Support/Tern/plugin-data/tern-plugin-base/config.json`
- linux: `$XDG_STATE_HOME/tern/plugin-data/tern-plugin-base/config.json` (default `~/.local/state/tern/...`)
- windows: `%LOCALAPPDATA%\Tern\plugin-data\tern-plugin-base\config.json`
- with `TERN_CONFIG_DIR` set: `$TERN_CONFIG_DIR/plugin-data/tern-plugin-base/config.json`

example:

```json
{ "greeting": "hi" }
```

missing file or key -> default. reinstall and update keep the file. run `tern plugin reload` after editing.

## develop

install `tern`, `just`, lua, `luau-lsp`, and `stylua` with luau support. run `just` for available commands.

```fish
just test
just lint
just fmt
```

no tests are included yet. lint generates current tern api types and checks plugin source; format covers lua/luau files. generated types are not committed.

`just bump` bumps patch; `just bump minor` and `just bump major` pick another part. only `plugin.toml` holds the version.

## publish

keep `plugin.toml` at the repository root. users install with:

```fish
tern plugin install github.com/OWNER/REPO
```

use `tern plugin install .` for a local copy, and `--force` to update an installed copy. users only need tern.

mit license. retain the notice for reused code.
