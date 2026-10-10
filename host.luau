--!strict

local DEFAULT_GREETING = "hello from tern-plugin-base"
local CONFIG_MAX_BYTES = 64 * 1024

local config_path = tern.plugin.data .. "/config.json"
local greeting = DEFAULT_GREETING

if tern.fs.exists(config_path) then
	local text = tern.fs.read(config_path, CONFIG_MAX_BYTES)
	local config = tern.json.decode(text)
	-- Arrays also decode to tables; require an object in the source.
	if type(config) ~= "table" or not text:match("^%s*{") then
		error(config_path .. ": expected a JSON object")
	end
	if config.greeting ~= nil then
		if type(config.greeting) ~= "string" then
			error(config_path .. ": greeting must be a string")
		end
		greeting = config.greeting
	end
end

tern.log.info(greeting)
