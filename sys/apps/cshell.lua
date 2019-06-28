local Config     = require('opus.config')

local read  = _G.read
local shell = _ENV.shell

if not _G.http.websocket then
	error('Requires CC: Tweaked')
end

if not _G.cloud_catcher then
	local key = Config.load('cloud').key

	if not key then
		print('Visit https://cloud-catcher.squiddev.cc')
		print('Paste key: ')
		key = read()
		if #key == 0 then
			return
		end
	end
	print('Connecting...')
	shell.run('cloud ' .. key)
end
