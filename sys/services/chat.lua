local device     = _G.device
local multishell = _ENV.multishell
local os         = _G.os
local parallel   = _G.parallel

if device.wireless_modem then

	multishell.setTitle(multishell.getCurrent(), 'Chat Daemon')

	local tab

	local function chatClient()

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
				h:resume(unpack(e))
			end
		end
	end

	parallel.waitForAll(
		function()
			os.run(_ENV, 'rom/programs/rednet/chat',
				'host', 'opusChat-' .. os.getComputerID())
		end,
		function()
			os.sleep(3)
			local tabId = multishell.openTab({
				fn     = chatClient,
				title  = 'Chat',
				hidden = true,
			})
			tab = multishell.getTab(tabId)
		end
	)

	print('Chat daemon stopped')
end
