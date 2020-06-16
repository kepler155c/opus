local parentShell = _ENV.shell
_ENV.shell = { }

local trace = require('opus.trace')
local Util  = require('opus.util')

local fs       = _G.fs
local settings = _G.settings
local shell    = _ENV.shell

local DIR = (parentShell and parentShell.dir()) or ""
local PATH = (parentShell and parentShell.path()) or ".:/rom/programs"
local tAliases = (parentShell and parentShell.aliases()) or {}
local tCompletionInfo = (parentShell and parentShell.getCompletionInfo()) or {}

local bExit = false
local tProgramStack = {}

local function tokenise(...)
	local sLine = table.concat({ ... }, ' ')
	local tWords = { }
	local bQuoted = false
	for match in string.gmatch(sLine .. "\"", "(.-)\"") do
		if bQuoted then
			table.insert(tWords, match)
		else
			for m in string.gmatch(match, "[^ \t]+") do
				table.insert(tWords, m)
			end
		end
		bQuoted = not bQuoted
	end

	return tWords
end

local defaultHandlers = {
	function(env, command, args)
		return command:match("^(https?:)") and {
			title = fs.getName(command),
			path  = command,
			args  = args,
			load  = Util.loadUrl,
			env   = env,
		}
	end,

	function(env, command, args)
		command = env.shell.resolveProgram(command)
			or error('No such program')

		_G.requireInjector(env, fs.getDir(command))
		return {
			title = fs.getName(command):match('([^%.]+)'),
			path  = command,
			args  = args,
			load  = loadfile,
			env   = env,
		}
	end,
}

function shell.getHandlers()
	if parentShell and parentShell.getHandlers then
		return parentShell.getHandlers()
	end
	return defaultHandlers
end

local handlers = shell.getHandlers()

function shell.registerHandler(fn)
	table.insert(handlers, 1, fn)
end

local function handleCommand(env, command, args)
	for _,v in pairs(handlers) do
		local pi = v(env, command, args)
		if pi then
			return pi
		end
	end
end

local function run(...)
	local args = tokenise(...)
	if #args == 0 then
		error('No such program')
	end

	local pi = handleCommand(shell.makeEnv(_ENV), table.remove(args, 1), args)

	local O_v_O, err = pi.load(pi.path, pi.env)
	if not O_v_O then
		error(err, -1)
	end

	if _ENV.multishell then
		_ENV.multishell.setTitle(_ENV.multishell.getCurrent(), pi.title)
	end

	tProgramStack[#tProgramStack + 1] = pi

	pi.env[ "arg" ] = { [0] = pi.path, table.unpack(pi.args) }
	local r = { O_v_O(table.unpack(pi.args)) }

	tProgramStack[#tProgramStack] = nil

	return table.unpack(r)
end

-- Install shell API
function shell.run(...)
	local oldTitle

	if _ENV.multishell then
		oldTitle = _ENV.multishell.getTitle(_ENV.multishell.getCurrent())
	end

	local r = { trace(run, ...) }

	if _ENV.multishell then
		_ENV.multishell.setTitle(_ENV.multishell.getCurrent(), oldTitle or 'shell')
	end

	return table.unpack(r)
end

function shell.exit()
	bExit = true
end

function shell.dir() return DIR end
function shell.setDir(d)
	d = fs.combine(d, '')
	if not fs.isDir(d) then
		error("Not a directory", 2)
	end
	DIR = d
end

function shell.path() return PATH end
function shell.setPath(p) PATH = p end

function shell.resolve( _sPath )
	local sStartChar = string.sub( _sPath, 1, 1 )
	if sStartChar == "/" or sStartChar == "\\" then
		return fs.combine( "", _sPath )
	else
		return fs.combine(DIR, _sPath )
	end
end

function shell.resolveProgram(_sCommand)
	if tAliases[_sCommand] ~= nil then
		_sCommand = tAliases[_sCommand]
	end

	local function check(f)
		return fs.exists(f) and not fs.isDir(f) and f
	end

	local function inPath()
		-- Otherwise, look on the path variable
		for sPath in string.gmatch(PATH or '', "[^:]+") do
			sPath = fs.combine(sPath, _sCommand )
			if check(sPath) then
				return sPath
			end
			if check(sPath .. '.lua') then
				return sPath .. '.lua'
			end
		end
	end

	if not _sCommand:find('/') then
		return inPath()
	end

	-- so... even if you are in the rom directory and you run:
	-- 'packages/common/edit.lua', allow this even though it
	-- does not use a leading slash. Ideally, fs.combine would
	-- provide the leading slash... but it does not.
	return check(shell.resolve(_sCommand))
		or check(shell.resolve(_sCommand) .. '.lua')
		or check(_sCommand)
		or check(_sCommand .. '.lua')
end

function shell.programs(_bIncludeHidden)
	local tItems = { }

	-- Add programs from the path
	for sPath in string.gmatch(PATH, "[^:]+") do
		sPath = shell.resolve(sPath)
		if fs.isDir( sPath ) then
			local tList = fs.list( sPath )
			for _,sFile in pairs( tList ) do
				if not fs.isDir( fs.combine( sPath, sFile ) ) and
					(_bIncludeHidden or string.sub( sFile, 1, 1 ) ~= ".") then
					tItems[ sFile ] = true
				end
			end
		end
	end

	-- Sort and return
	local tItemList = { }
	for sItem in pairs(tItems) do
		table.insert(tItemList, sItem)
	end
	table.sort(tItemList)
	return tItemList
end

function shell.completeProgram(sLine)
	if #sLine > 0 and string.sub(sLine, 1, 1) == '/' then
		-- Add programs from the root
		return fs.complete(sLine, '', true, false)
	end

	local tResults = { }
	local tSeen = { }

	-- Add aliases
	for sAlias in pairs( tAliases ) do
		if #sAlias > #sLine and string.sub(sAlias, 1, #sLine) == sLine then
			local sResult = string.sub(sAlias, #sLine + 1)
			if not tSeen[sResult] then
				table.insert(tResults, sResult .. ' ')
				tSeen[sResult] = true
			end
		end
	end

	-- Add programs from the path
	local tPrograms = shell.programs()
	for n=1,#tPrograms do
		local sProgram = tPrograms[n]
		if #sProgram >= #sLine and string.sub(sProgram, 1, #sLine) == sLine then
			local sResult = string.sub(sProgram, #sLine + 1)
			if not tSeen[sResult] then
				table.insert(tResults, sResult .. ' ')
				tSeen[sResult] = true
			end
		end
	end

	-- Sort and return
	table.sort(tResults)
	return tResults
end

function shell.complete(sLine)
	local tWords = tokenise(sLine)
	local nIndex = #tWords
	if string.sub(sLine, #sLine, #sLine) == ' ' and #Util.trim(sLine) > 0 then
		nIndex = nIndex + 1
	end

	if nIndex == 0 then
		return fs.complete('', shell.dir(), true, false)

	elseif nIndex == 1 then
		local results = shell.completeProgram(tWords[1] or '')
		for _, v in pairs(fs.complete(table.concat(tWords, ' '), shell.dir(), true, false)) do
			table.insert(results, v)
		end
		return results

	else
		local sPath = shell.resolveProgram(tWords[1])
		local sPart = tWords[nIndex] or ''
		local tPreviousParts = tWords
		tPreviousParts[nIndex] = nil
		local results
		local tInfo = tCompletionInfo[sPath]
		if tInfo then
			results = tInfo.fnComplete(shell, nIndex - 1, sPart, tPreviousParts)
		end
		return results and #results > 0 and results
			or fs.complete(sPart, shell.dir(), true, false)
	end
end

function shell.setCompletionFunction(sProgram, fnComplete)
	tCompletionInfo[sProgram] = { fnComplete = fnComplete }
end

function shell.getCompletionInfo()
	return tCompletionInfo
end

function shell.getRunningProgram()
	return tProgramStack[#tProgramStack] and tProgramStack[#tProgramStack].path
end

function shell.getRunningInfo()
	return tProgramStack[#tProgramStack]
end

-- convenience function for making a runnable env
function shell.makeEnv(env, dir)
	env = setmetatable(Util.shallowCopy(env), { __index = _G })
	_G.requireInjector(env, dir)
	return env
end

function shell.setAlias(_sCommand, _sProgram)
	tAliases[_sCommand] = _sProgram
end

function shell.clearAlias(_sCommand)
	tAliases[_sCommand] = nil
end

function shell.aliases()
	local tCopy = {}
	for sAlias, sCommand in pairs(tAliases) do
		tCopy[sAlias] = sCommand
	end
	return tCopy
end

function shell.newTab(tabInfo, ...)
	local args = tokenise(...)
	local path = table.remove(args, 1)
	path = shell.resolveProgram(path)

	if path then
		tabInfo.path = path
		tabInfo.args = args
		tabInfo.title = fs.getName(path):match('([^%.]+)')

		if path ~= 'sys/apps/shell.lua' then
			table.insert(tabInfo.args, 1, tabInfo.path)
			tabInfo.path = 'sys/apps/shell.lua'
		end
		return _ENV.multishell.openTab(_ENV, tabInfo)
	end
	return nil, 'No such program'
end

if not _ENV.multishell then
	function shell.newTab()
		error('Multishell is not available')
	end
end

function shell.openTab(...)
	return shell.newTab({ }, ...)
end

function shell.openForegroundTab( ... )
	return shell.newTab({ focused = true }, ...)
end

function shell.openHiddenTab( ... )
	return shell.newTab({ hidden = true }, ...)
end

function shell.switchTab(tabId)
	_ENV.multishell.setFocus(tabId)
end

local tArgs = { ... }
if #tArgs > 0 then
	return run(...)
end

local Config   = require('opus.config')
local Entry    = require('opus.entry')
local History  = require('opus.history')
local Input    = require('opus.input')
local Sound    = require('opus.sound')
local Terminal = require('opus.terminal')

local colors    = _G.colors
local os        = _G.os
local term      = _G.term
local textutils = _G.textutils

local oldTerm
local terminal  = term.current()
local _len      = string.len
local _rep      = string.rep
local _sub      = string.sub

local config = {
	color = {
		textColor = colors.white,
		commandTextColor = colors.yellow,
		directoryTextColor  = colors.orange,
		promptTextColor = colors.blue,
		directoryColor = colors.green,
		fileColor = colors.white,
		backgroundColor = colors.black,
	},
	displayDirectory = true,
}

Config.load('shellprompt', config)

local _colors = config.color
-- temp
if not _colors.backgroundColor then
  _colors.backgroundColor = colors.black
  _colors.fileColor = colors.white
end

if not terminal.scrollUp then
	terminal = Terminal.window(term.current())
	terminal.setMaxScroll(200)
	oldTerm = term.redirect(terminal)
	term.setBackgroundColor(_colors.backgroundColor)
	term.clear()
end

local palette = terminal.canvas.palette

local function autocomplete(line)
	local words = { }
	for word in line:gmatch("%S+") do
		table.insert(words, word)
	end
	if line:match(' $') then
		table.insert(words, '')
	end
	if #words == 0 then
		words = { '' }
	end

	local results = shell.complete(line) or { }

	Util.filterInplace(results, function(f)
		return not Util.key(results, f .. '/')
	end)
	local w = words[#words] or ''
	for k,arg in pairs(results) do
		results[k] = w .. arg
	end

	if #results == 1 then
		words[#words] = results[1]
		return table.concat(words, ' ')

	elseif #results > 1 then
		local function someComplete()
			-- ugly (complete as much as possible)
			local word = words[#words] or ''
			local i = #word + 1
			while true do
				local ch
				for _,f in ipairs(results) do
					if #f < i then
						words[#words] = _sub(f, 1, i - 1)
						return table.concat(words, ' ')
					end
					if not ch then
						ch = _sub(f, i, i)
					elseif _sub(f, i, i) ~= ch then
						if i == #word + 1 then
							return
						end
						words[#words] = _sub(f, 1, i - 1)
						return table.concat(words, ' ')
					end
				end
				i = i + 1
			end
		end

		local t = someComplete()
		if t then
			return t
		end

		print()

		local word = words[#words] or ''
		local prefix = word:match("(.*/)") or ''
		if #prefix > 0 then
			for _,f in ipairs(results) do
				if f:match("^" .. prefix) ~= prefix then
					prefix = ''
					break
				end
			end
		end

		local tDirs, tFiles = { }, { }
		for _,f in ipairs(results) do
			if fs.isDir(shell.resolve(f)) then
				f = f:gsub(prefix, '', 1)
				table.insert(tDirs, f)
			else
				f = f:gsub(prefix, '', 1)
				table.insert(tFiles, f)
			end
		end
		table.sort(tDirs)
		table.sort(tFiles)

		if #tDirs > 0 and #tDirs < #tFiles then
			local tw = term.getSize()
			local nMaxLen = tw / 8
			for _,sItem in pairs(results) do
				nMaxLen = math.max(_len(sItem) + 1, nMaxLen)
			end
			local nCols = math.floor(tw / nMaxLen)
			if #tDirs < nCols then
				for _ = #tDirs + 1, nCols do
					table.insert(tDirs, '')
				end
			end
		end

		if #tDirs > 0 then
			textutils.tabulate(_colors.directoryColor, tDirs, _colors.fileColor, tFiles)
		else
			textutils.tabulate(_colors.fileColor, tFiles)
		end

		term.setTextColour(_colors.promptTextColor)
		term.write("$ " )

		term.setTextColour(_colors.commandTextColor)
		return line
	end
end

local function shellRead(history)
	local lastLen = 0
	local entry = Entry({
		width = term.getSize() - 3,
		offset = 3,
	})

	history:reset()
	term.setCursorBlink(true)

	local function updateCursor()
		term.setCursorPos(3 + entry.pos - entry.scroll, select(2, term.getCursorPos()))
	end

	local function redraw()
		if terminal.scrollBottom then
			terminal.scrollBottom()
		end
		local _,cy = term.getCursorPos()
		term.setCursorPos(3, cy)
		entry.value = entry.value or ''
		local filler = #entry.value < lastLen
			and _rep(' ', lastLen - #entry.value)
			or ''
		local str = _sub(entry.value, entry.scroll + 1, entry.width + entry.scroll) .. filler
		local fg = _rep(palette[_colors.commandTextColor], #str)
		local bg = _rep(palette[_colors.backgroundColor], #str)
		if entry.mark.active then
			bg = _rep('f', entry.mark.x) ..
				_rep('7', entry.mark.ex - entry.mark.x) ..
				_rep('f', #entry.value - entry.mark.ex + #filler + 1)
			bg = _sub(bg, entry.scroll + 1, entry.scroll + #str)
		end
		term.blit(str, fg, bg)
		updateCursor()
		lastLen = #entry.value
	end

	while true do
		local event, p1, p2, p3 = os.pullEventRaw()

		local ie = Input:translate(event, p1, p2, p3)
		if ie then
			if ie.code == 'scroll_up' and terminal.scrollUp then
				terminal.scrollUp()

			elseif ie.code == 'scroll_down' and terminal.scrollDown then
				terminal.scrollDown()

			elseif ie.code == 'terminate' then
				bExit = true
				break

			elseif ie.code == 'enter' then
				break

			elseif ie.code == 'up'   or ie.code == 'control-p' or
						 ie.code == 'down' or ie.code == 'control-n' then
				entry:reset()
				if ie.code == 'up' or ie.code == 'control-p' then
					entry.value = history:back() or ''
				else
					entry.value = history:forward() or ''
				end
				entry.pos = #entry.value
				entry:updateScroll()
				redraw()

			elseif ie.code == 'tab' then
				entry.value = entry.value or ''
				if entry.pos == #entry.value then
					local cline = autocomplete(entry.value)
					if cline then
						entry.value = cline
						entry.pos = #entry.value
						entry:unmark()
						entry:updateScroll()
						redraw()
					else
						Sound.play('entity.villager.no')
					end
				end

			else
				entry:process(ie)
				entry.value = entry.value or ''
				if entry.textChanged then
					redraw()
				elseif entry.posChanged then
					updateCursor()
				end
			end

		elseif event == "term_resize" then
			terminal.reposition(1, 1, oldTerm.getSize())
			entry.width = term.getSize() - 3
			entry:updateScroll()
			redraw()
		end
	end

	print()
	term.setCursorBlink(false)
	return entry.value or ''
end

local history = History.load('usr/.shell_history', 100)

term.setBackgroundColor(_colors.backgroundColor)

if settings.get("motd.enable") then
	shell.run("motd")
end

while not bExit do
	if config.displayDirectory then
		term.setTextColour(_colors.directoryTextColor)
		print('==' .. os.getComputerLabel() .. ':/' .. DIR)
	end
	term.setTextColour(_colors.promptTextColor)
	term.write("$ " )
	term.setTextColour(_colors.commandTextColor)
	local sLine = shellRead(history)
	if bExit then -- terminated
		break
	end
	sLine = Util.trim(sLine)
	if #sLine > 0 and sLine ~= 'exit' then
		history:add(sLine)
	end
	term.setTextColour(_colors.textColor)
	if #sLine > 0 then
		local result, err = shell.run(sLine)
		local cx = term.getCursorPos()
		if cx ~= 1 then
			print()
		end
		term.setBackgroundColor(_colors.backgroundColor)
		if not result and err then
			_G.printError(err)
		end
	end
end

if oldTerm then
	term.redirect(oldTerm)
end
