--[[
	Adds a task and the control-d hotkey to view the kernel log.
--]]

local kernel     = _G.kernel
local keyboard   = _G.device.keyboard
local os         = _G.os

local function systemLog()
	local routine = kernel.getCurrent()

	kernel.hook('mouse_scroll', function(_, eventData)
		local dir, y = eventData[1], eventData[3]

		if y > 1 then
			local currentTab = kernel.getFocused()
			if currentTab == routine then
				if currentTab.terminal.scrollUp then
					if dir == -1 then
						currentTab.terminal.scrollUp()
					else
						currentTab.terminal.scrollDown()
					end
				end
			end
		end
	end)

	keyboard.addHotkey('control-d', function()
		local current = kernel.getFocused()
		if current.uid ~= routine.uid then
			kernel.raise(routine.uid)
		elseif kernel.routines[2] then
			kernel.raise(kernel.routines[2].uid)
		end
	end)

	os.pullEventRaw('terminate')
	keyboard.removeHotkey('control-d')
end

kernel.run(_ENV, {
	title = 'System Log',
	fn = systemLog,
	noTerminate = true,
	hidden = true,
})
