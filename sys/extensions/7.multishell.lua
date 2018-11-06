_G.requireInjector(_ENV)

local Config   = require('config')
local Packages = require('packages')
local Util     = require('util')

local colors     = _G.colors
local fs         = _G.fs
local kernel     = _G.kernel
local keys       = _G.keys
local os         = _G.os
local printError = _G.printError
local shell      = _ENV.shell
local term       = _G.term
local window     = _G.window

local parentTerm = _G.device.terminal
local w,h = parentTerm.getSize()
local overviewId
local tabsDirty = false
local closeInd = Util.getVersion() >= 1.76 and '\215' or '*'
local multishell = { }

shell.setEnv('multishell', multishell)

multishell.term = parentTerm --deprecated

local config = {
	standard = {
		textColor  = colors.lightGray,
		tabBarTextColor = colors.lightGray,
		focusTextColor = colors.white,
		backgroundColor = colors.gray,
		tabBarBackgroundColor = colors.gray,
		focusBackgroundColor = colors.gray,
		errorColor = colors.black,
	},
	color = {
		textColor  = colors.lightGray,
		tabBarTextColor = colors.lightGray,
		focusTextColor = colors.white,
		backgroundColor = colors.gray,
		tabBarBackgroundColor = colors.gray,
		focusBackgroundColor = colors.gray,
		errorColor = colors.red,
	},
}
Config.load('multishell', config)

local _colors = parentTerm.isColor() and config.color or config.standard

local function redrawMenu()
	if not tabsDirty then
		os.queueEvent('multishell_redraw')
		tabsDirty = true
	end
end

function multishell.getFocus()
	local currentTab = kernel.getFocused()
	return currentTab.uid
end

function multishell.setFocus(tabId)
	return kernel.raise(tabId)
end

function multishell.getTitle(tabId)
	local tab = kernel.find(tabId)
	return tab and tab.title
end

function multishell.setTitle(tabId, title)
	local tab = kernel.find(tabId)
	if tab then
		tab.title = title
		redrawMenu()
	end
end

function multishell.getCurrent()
	local runningTab = kernel.getCurrent()
	return runningTab and runningTab.uid
end

function multishell.getTab(tabId)
	return kernel.find(tabId)
end

function multishell.terminate(tabId)
	os.queueEvent('multishell_terminate', tabId)
end

function multishell.getTabs()
	return kernel.routines
end

function multishell.launch( tProgramEnv, sProgramPath, ... )
	-- backwards compatibility
	return multishell.openTab({
		env = tProgramEnv,
		path = sProgramPath,
		args = { ... },
	})
end

function multishell.openTab(tab)
	if not tab.title and tab.path then
		tab.title = fs.getName(tab.path):match('([^%.]+)')
	end
	tab.title = tab.title or 'untitled'
	tab.window = tab.window or window.create(parentTerm, 1, 2, w, h - 1, false)
	tab.terminal = tab.terminal or tab.window

	local routine = kernel.newRoutine(tab)

	routine.co = coroutine.create(function()
		local result, err

		if tab.fn then
			result, err = Util.runFunction(routine.env, tab.fn, table.unpack(tab.args or { } ))
		elseif tab.path then
			result, err = Util.run(routine.env, tab.path, table.unpack(tab.args or { } ))
		else
			err = 'multishell: invalid tab'
		end

		if not result and err and err ~= 'Terminated' then
			if err then
				printError(tostring(err))
			end
			print('\nPress enter to close')
			routine.isDead = true
			routine.hidden = false
			redrawMenu()
			while true do
				local e, code = os.pullEventRaw('key')
				if e == 'terminate' or e == 'key' and code == keys.enter then
					break
				end
			end
		end
	end)

	kernel.launch(routine)

	if tab.focused then
		multishell.setFocus(routine.uid)
	else
		redrawMenu()
	end
	return routine.uid
end

function multishell.hideTab(tabId)
	local tab = kernel.find(tabId)
	if tab then
		tab.hidden = true
		kernel.lower(tab.uid)
		redrawMenu()
	end
end

function multishell.unhideTab(tabId)
	local tab = kernel.find(tabId)
	if tab then
		tab.hidden = false
		redrawMenu()
	end
end

function multishell.getCount()
	return #kernel.routines
end

kernel.hook('kernel_focus', function(_, eventData)
	local previous = eventData[2]
	if previous then
		local routine = kernel.find(previous)
		if routine and routine.window then
			routine.window.setVisible(false)
			if routine.hidden then
				kernel.lower(previous)
			end
		end
	end

	local focused = kernel.find(eventData[1])
	if focused and focused.window then
		focused.window.setVisible(true)
	end

	redrawMenu()
end)

kernel.hook('multishell_terminate', function(_, eventData)
	local tab = kernel.find(eventData[1])
	if tab and not tab.isOverview then
		if coroutine.status(tab.co) ~= 'dead' then
			tab:resume("terminate")
		end
	end
	return true
end)

kernel.hook('terminate', function()
	return kernel.getFocused().isOverview
end)

kernel.hook('multishell_redraw', function()
	tabsDirty = false

	local function write(x, text, bg, fg)
		parentTerm.setBackgroundColor(bg)
		parentTerm.setTextColor(fg)
		parentTerm.setCursorPos(x, 1)
		parentTerm.write(text)
	end

	local bg = _colors.tabBarBackgroundColor
	parentTerm.setBackgroundColor(bg)
	parentTerm.setCursorPos(1, 1)
	parentTerm.clearLine()

	local currentTab = kernel.getFocused()

	for _,tab in pairs(kernel.routines) do
		if tab.hidden and tab ~= currentTab then
			tab.width = 0
		else
			tab.width = #tab.title + 1
		end
	end

	local function width()
		local tw = 0
		Util.each(kernel.routines, function(t) tw = tw + t.width end)
		return tw
	end

	while width() > w - 3 do
		local tab = select(2,
			Util.spairs(kernel.routines, function(a, b) return a.width > b.width end)())
		tab.width = tab.width - 1
	end

	local function compareTab(a, b)
		if a.hidden then return false end
		return b.hidden or a.uid < b.uid
	end

	local tabX = 0
	for _,tab in Util.spairs(kernel.routines, compareTab) do
		if tab.width > 0 then
			tab.sx = tabX + 1
			tab.ex = tabX + tab.width
			tabX = tabX + tab.width
			if tab ~= currentTab then
				local textColor = tab.isDead and _colors.errorColor or _colors.textColor
				write(tab.sx, tab.title:sub(1, tab.width - 1),
					_colors.backgroundColor, textColor)
			end
		end
	end

	if currentTab then
		write(currentTab.sx - 1,
			' ' .. currentTab.title:sub(1, currentTab.width - 1) .. ' ',
			_colors.focusBackgroundColor, _colors.focusTextColor)
		if not currentTab.isOverview then
			write(w, closeInd, _colors.backgroundColor, _colors.focusTextColor)
		end
	end

	if currentTab and currentTab.window then
		currentTab.window.restoreCursor()
	end

	return true
end)

kernel.hook('term_resize', function(_, eventData)
	if not eventData[1] then                            --- TEST
		w,h = parentTerm.getSize()

		local windowHeight = h-1

		for _,key in pairs(Util.keys(kernel.routines)) do
			local tab = kernel.routines[key]
			local x,y = tab.window.getCursorPos()
			if y > windowHeight then
				tab.window.scroll(y - windowHeight)
				tab.window.setCursorPos(x, windowHeight)
			end
			tab.window.reposition(1, 2, w, windowHeight)
		end

		redrawMenu()
	end
end)

kernel.hook('mouse_click', function(_, eventData)
	local x, y = eventData[2], eventData[3]

	if y == 1 then
		if x == 1 then
			multishell.setFocus(overviewId)
		elseif x == w then
			local currentTab = kernel.getFocused()
			if currentTab then
				multishell.terminate(currentTab.uid)
			end
		else
			for _,tab in pairs(kernel.routines) do
				if not tab.hidden and tab.sx then
					if x >= tab.sx and x <= tab.ex then
						multishell.setFocus(tab.uid)
						break
					end
				end
			end
		end
		return true
	end
	eventData[3] = eventData[3] - 1
end)

kernel.hook({ 'mouse_up', 'mouse_drag' }, function(_, eventData)
	eventData[3] = eventData[3] - 1
end)

kernel.hook('mouse_scroll', function(_, eventData)
	if eventData[3] == 1 then
		return true
	end
	eventData[3] = eventData[3] - 1
end)

local function startup()
	local success = true

	local function runDir(directory, open)
		if not fs.exists(directory) then
			return true
		end

		local files = fs.list(directory)
		table.sort(files)

		for _,file in ipairs(files) do
			os.sleep(0)
			local result, err = open(directory .. '/' .. file)

			if result then
				if term.isColor() then
					term.setTextColor(colors.green)
				end
				term.write('[PASS] ')
				term.setTextColor(colors.white)
				term.write(fs.combine(directory, file))
				print()
			else
				if term.isColor() then
					term.setTextColor(colors.red)
				end
				term.write('[FAIL] ')
				term.setTextColor(colors.white)
				term.write(fs.combine(directory, file))
				if err then
					_G.printError('\n' .. err)
				end
				print()
				success = false
			end
		end
	end

	runDir('sys/autorun', shell.run)
	for name in pairs(Packages:installed()) do
		local packageDir = 'packages/' .. name .. '/autorun'
		runDir(packageDir, shell.run)
	end
	runDir('usr/autorun', shell.run)

	if not success then
		multishell.setFocus(multishell.getCurrent())
		printError('\nA startup program has errored')
		os.pullEvent('terminate')
	end
end

kernel.hook('kernel_ready', function()
	overviewId = multishell.openTab({
		path = 'sys/apps/Overview.lua',
		isOverview = true,
		focused = true,
		title = '+',
	})

	multishell.openTab({
		fn = startup,
		title = 'Autorun',
	})
end)
