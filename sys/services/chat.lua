local device     = _G.device
local multishell = _ENV.multishell
local os         = _G.os

if device.wireless_modem then

	multishell.setTitle(multishell.getCurrent(), 'Chat')

	multishell.openTab({
		path   = 'rom/programs/rednet/chat',
		args   = { 'host', 'opusChat-' .. os.getComputerID() },
		title  = 'Chat Daemon',
		hidden = true,
	})

	local tab = multishell.getTab(multishell.getCurrent())

  _G.requireInjector()

	local Event = require('event')
	local Util  = require('util')

	local h = Event.addRoutine(function()
		while true do
			Util.run(_ENV, 'rom/programs/rednet/chat',
				'join', 'opusChat-' .. os.getComputerID(), 'owner')
		end
	end)

	while true do
		local e = { os.pullEventRaw() }
		if e[1] == 'terminate' then
			multishell.hideTab(tab.tabId)
		else
			if e[1] == 'rednet_message' and e[4] == 'chat' and e[3].sType == 'chat' then
				if tab.hidden then
					multishell.unhideTab(tab.tabId)
				end
			end
			h:resume(table.unpack(e))
		end
	end
end
