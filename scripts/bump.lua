local level = arg[1] or "patch"
local index = ({ major = 1, minor = 2, patch = 3 })[level]
assert(index and #arg <= 1, "usage: lua scripts/bump.lua [major|minor|patch]")

local file = assert(io.open("plugin.toml", "rb"))
local manifest = assert(file:read("*a"))
assert(file:close())

local root = ("\n" .. manifest):match("^(.-)\n[ \t]*%[") or "\n" .. manifest
root = root .. "\n"
local _, count = root:gsub("\n[ \t]*version[ \t]*=", "")
assert(count == 1, "plugin.toml must have exactly one root version key")
local first, major, minor, patch, after = root:match('\nversion = "()(%d+)%.(%d+)%.(%d+)()"\r?\n')
assert(first, 'plugin.toml must use a plain root version = "major.minor.patch" line')

local parts = { tonumber(major), tonumber(minor), tonumber(patch) }
parts[index] = parts[index] + 1
for trailing = index + 1, 3 do
	parts[trailing] = 0
end
local next_version = string.format("%d.%d.%d", parts[1], parts[2], parts[3])
local updated = manifest:sub(1, first - 2) .. next_version .. manifest:sub(after - 1)

file = assert(io.open("plugin.toml", "wb"))
assert(file:write(updated))
assert(file:close())
io.stdout:write(major .. "." .. minor .. "." .. patch .. " -> " .. next_version .. "\n")
