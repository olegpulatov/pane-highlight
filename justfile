set windows-shell := ["cmd.exe", "/c"]

# The plugin's data folder, as README lists it per os.
data_dir := if env("TERN_CONFIG_DIR", "") != "" {
    env("TERN_CONFIG_DIR") / "plugin-data/pane-highlight"
} else if os() == "macos" {
    home_directory() / "Library/Application Support/Tern/plugin-data/pane-highlight"
} else if os() == "windows" {
    env("LOCALAPPDATA", "") / "Tern/plugin-data/pane-highlight"
} else {
    env("XDG_STATE_HOME", home_directory() / ".local/state") / "tern/plugin-data/pane-highlight"
}
config_dir := if os() == "windows" { replace(data_dir, "/", "\\") } else { data_dir }

# List available commands.
default:
    @just --list --unsorted

# Link this package into Tern for local development.
link:
    tern plugin link .

# Reload all plugins; exits 1 on host load failures.
reload:
    tern plugin reload

# Open the user config.json in $EDITOR; run `tern plugin reload` after saving.
[unix]
edit-config:
    mkdir -p "{{ config_dir }}"
    {{ env("EDITOR", "vi") }} "{{ config_dir }}/config.json"

[windows]
edit-config:
    if not exist "{{ config_dir }}" mkdir "{{ config_dir }}"
    {{ env("EDITOR", "notepad") }} "{{ config_dir }}\config.json"

# Generate API definitions from the installed Tern version.
types:
    tern plugin types .

# Run tests (none yet).
test:
    @echo "No tests defined."

# Generate current definitions and type-check plugin source.
lint: types
    luau-lsp analyze --platform=standard --definitions=@tern=tern.d.luau --ignore=tern.d.luau --ignore="scripts/**" .

# Format source and helper files, never generated definitions.
fmt:
    stylua --glob "**/*.{lua,luau}" --glob "!tern.d.luau" .

# Bump only plugin.toml's version; no commit or tag.
bump level="patch":
    lua scripts/bump.lua "{{ level }}"
