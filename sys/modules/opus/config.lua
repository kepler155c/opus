local Util = require('opus.util')

local fs    = _G.fs
local shell = _ENV.shell

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

function Config.loadWithCheck(fname, data)
	local filename = 'usr/config/' .. fname

	if not fs.exists(filename) then
		Config.load(fname, data)
		print()
		print('The configuration file has been created.')
		print('The file name is: ' .. filename)
		print()
		_G.printError('Press enter to configure')
		_G.read()
		shell.run('edit ' .. filename)
	end

	return Config.load(fname, data)
end

function Config.update(fname, data)
	local filename = 'usr/config/' .. fname
	Util.writeTable(filename, data)
end

return Config
