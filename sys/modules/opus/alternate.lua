local Array  = require('opus.array')
local Config = require('opus.config')
local Util   = require('opus.util')

local function getConfig()
	return Config.load('alternate', {
		shell = {
			'sys/apps/shell.lua',
			'rom/programs/shell.lua',
		},
		lua = {
			'sys/apps/Lua.lua',
			'rom/programs/lua.lua',
		},
		files = {
			'sys/apps/Files.lua',
		}
	})
end

local Alt = { }

function Alt.get(key)
	return getConfig()[key][1]
end

function Alt.set(key, value)
	local config = getConfig()
	Array.removeByValue(config[key], value)
	table.insert(config[key], 1, value)
	Config.update('alternate', config)
end

function Alt.remove(key, value)
	local config = getConfig()
	Array.removeByValue(config[key], value)
	Config.update('alternate', config)
end

function Alt.add(key, value)
	local config = getConfig()
	if not Util.contains(config[key], value) then
		table.insert(config[key], value)
		Config.update('alternate', config)
	end
end

return Alt
