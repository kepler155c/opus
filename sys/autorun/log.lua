--[[
	Adds a task and the control-d hotkey to view the kernel log.
--]]

local kernel     = _G.kernel
local keyboard   = _G.device.keyboard
local multishell = _ENV.multishell
local os         = _G.os
local term       = _G.term

local function systemLog()
	local routine = kernel.getCurrent()

	if multishell and multishell.openTab then
		local w, h = kernel.window.getSize()
		kernel.window.reposition(1, 2, w, h - 1)

		routine.terminal = kernel.window
		routine.window = kernel.window
		term.redirect(kernel.window)
	end

	kernel.hook('mouse_scroll', function(_, eventData)
		local dir, y = eventData[1], eventData[3]

		if y > 1 then
			local currentTab = kernel.getFocused()
			if currentTab == routine then
				if currentTab.terminal.scrollUp and not currentTab.terminal.noAutoScroll then
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

if multishell and multishell.openTab then
	multishell.openTab({
		title = 'System Log',
		fn = systemLog,
		hidden = true,
	})
else
	kernel.run({
		title = 'Syslog',
		fn = systemLog,
	})
end
