local Util = require('opus.util')

local fs    = _G.fs

local Config = { }

function Config.load(fname, data)
	local filename = 'usr/config/' .. fname
	data = data or { }

	if not fs.exists('usr/config') then
		fs.makeDir('usr/config')
	end

	if not fs.exists(filename) then
		Util.writeTable(filename, data)
	else
		local contents = Util.readTable(filename) or
			error('Configuration file is corrupt:' .. filename)

		Util.merge(data, contents)
	end

	return data
end

function Config.update(fname, data)
	local filename = 'usr/config/' .. fname
	Util.writeTable(filename, data)
end

return Config
