_G.requireInjector(_ENV)

local Util = require('util')

local kernel     = _G.kernel
local keyboard   = _G.device.keyboard
local multishell = _ENV.multishell

-- overview
keyboard.addHotkey('control-o', function()
	for _,tab in pairs(multishell.getTabs()) do
		if tab.isOverview then
			multishell.setFocus(tab.uid)
		end
	end
end)

-- restart tab
keyboard.addHotkey('control-backspace', function()
	local uid = multishell.getFocus()
	local tab = kernel.find(uid)
	if not tab.isOverview then
		multishell.terminate(uid)
		tab = Util.shallowCopy(tab)
		tab.isDead = false
		tab.focused = true
		multishell.openTab(tab)
	end
end)

-- next tab
keyboard.addHotkey('control-tab', function()
	local tabs = multishell.getTabs()
	local visibleTabs = { }
	local currentTabId = multishell.getFocus()

	local function compareTab(a, b)
		return a.uid < b.uid
	end
	for _,tab in Util.spairs(tabs, compareTab) do
		if not tab.hidden then
			table.insert(visibleTabs, tab)
		end
	end

	for k,tab in ipairs(visibleTabs) do
		if tab.uid == currentTabId then
			if k < #visibleTabs then
				multishell.setFocus(visibleTabs[k + 1].uid)
				return
			end
		end
	end
	if #visibleTabs > 0 then
		multishell.setFocus(visibleTabs[1].uid)
	end
end)
