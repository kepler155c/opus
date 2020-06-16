local kernel = _G.kernel
local os     = _G.os
local shell  = _ENV.shell

local launcherTab = kernel.getCurrent()
launcherTab.noFocus = true

kernel.hook('kernel_focus', function(_, eventData)
	local focusTab = eventData and eventData[1]
	if focusTab == launcherTab.uid then
		local previousTab = eventData[2]
		local nextTab = launcherTab
		if not previousTab then
			for _, v in pairs(kernel.routines) do
				if not v.hidden and v.uid > nextTab.uid then
					nextTab = v
				end
			end
		end
		if nextTab == launcherTab then
			shell.switchTab(shell.openTab('shell'))
		else
			shell.switchTab(nextTab.uid)
		end
	end
end)

os.pullEventRaw('kernel_halt')
