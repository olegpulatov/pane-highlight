set windows-shell := ["cmd.exe", "/c"]

# List available commands.
default:
    @just --list --unsorted

# Link this package into Tern for local development.
link:
    tern plugin link .

# Reload all plugins; exits 1 on host load failures.
reload:
    tern plugin reload

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
