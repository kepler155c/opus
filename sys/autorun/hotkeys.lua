local Util = require('opus.util')

local kernel     = _G.kernel
local keyboard   = _G.device.keyboard
local multishell = _ENV.multishell

if multishell and multishell.getTabs then
	-- restart tab
	keyboard.addHotkey('control-backspace', function()
		local tab = kernel.getFocused()
		if tab and not tab.noTerminate then
			multishell.terminate(tab.uid)
			multishell.openTab(tab.env, {
				path = tab.path,
				args = tab.args,
				focused = true,
			})
		end
	end)
end

-- next tab
keyboard.addHotkey('control-tab', function()
	local visibleTabs = { }
	local currentTab = kernel.getFocused()

	local function compareTab(a, b)
		return a.uid < b.uid
	end
	for _,tab in Util.spairs(kernel.routines, compareTab) do
		if not tab.hidden and not tab.noFocus then
			table.insert(visibleTabs, tab)
		end
	end

	for k,tab in ipairs(visibleTabs) do
		if tab.uid == currentTab.uid then
			if k < #visibleTabs then
				kernel.raise(visibleTabs[k + 1].uid)
				return
			end
		end
	end
	if #visibleTabs > 0 then
		kernel.raise(visibleTabs[1].uid)
	end
end)
