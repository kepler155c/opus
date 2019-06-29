local parentShell = _ENV.shell

_ENV.shell = { }

local fs         = _G.fs
local shell      = _ENV.shell

local sandboxEnv = setmetatable({ }, { __index = _G })
for k,v in pairs(_ENV) do
	sandboxEnv[k] = v
end
sandboxEnv.shell = shell

_G.requireInjector(_ENV)

local trace = require('opus.trace')
local Util = require('opus.util')

local DIR = (parentShell and parentShell.dir()) or ""
local PATH = (parentShell and parentShell.path()) or ".:/rom/programs"
local tAliases = (parentShell and parentShell.aliases()) or {}
local tCompletionInfo = (parentShell and parentShell.getCompletionInfo()) or {}

local bExit = false
local tProgramStack = {}

local function tokenise( ... )
	local sLine = table.concat( { ... }, " " )
	local tWords = {}
	local bQuoted = false
	for match in string.gmatch( sLine .. "\"", "(.-)\"" ) do
		if bQuoted then
			table.insert( tWords, match )
		else
			for m in string.gmatch( match, "[^ \t]+" ) do
				table.insert( tWords, m )
			end
		end
		bQuoted = not bQuoted
	end

	return tWords
end

local function run(env, ...)
	local args = tokenise(...)
	local command = table.remove(args, 1) or error('No such program')
	local isUrl = not not command:match("^(https?:)")

	local path, loadFn
	if isUrl then
		path = command
		loadFn = Util.loadUrl
	else
		path = shell.resolveProgram(command) or error('No such program')
		loadFn = loadfile
	end

	local fn, err = loadFn(path, env)
	if not fn then
		error(err)
	end

	if _ENV.multishell then
		_ENV.multishell.setTitle(_ENV.multishell.getCurrent(), fs.getName(path):match('([^%.]+)'))
	end

	if isUrl then
		tProgramStack[#tProgramStack + 1] = path -- path:match("^https?://([^/:]+:?[0-9]*/?.*)$")
	else
		tProgramStack[#tProgramStack + 1] = path
	end

	env[ "arg" ] = { [0] = path, table.unpack(args) }
	local r = { fn(table.unpack(args)) }

	tProgramStack[#tProgramStack] = nil

	return table.unpack(r)
end

-- Install shell API
function shell.run(...)
	local oldTitle

	if _ENV.multishell then
		oldTitle = _ENV.multishell.getTitle(_ENV.multishell.getCurrent())
	end

	local env = setmetatable(Util.shallowCopy(sandboxEnv), { __index = _G })
	_G.requireInjector(env)

	local r = { trace(run, env, ...) }

	if _ENV.multishell then
		_ENV.multishell.setTitle(_ENV.multishell.getCurrent(), oldTitle or 'shell')
	end

	return table.unpack(r)
end

function shell.exit()
	bExit = true
end

function shell.dir() return DIR end
function shell.setDir(d) DIR = d end
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

function shell.resolveProgram( _sCommand )
	if tAliases[_sCommand] ~= nil then
		_sCommand = tAliases[_sCommand]
	end

	if _sCommand:match("^(https?:)") then
		return _sCommand
	end

	local path = shell.resolve(_sCommand)
	if fs.exists(path) and not fs.isDir(path) then
		return path
	end
	if fs.exists(path .. '.lua') then
		return path .. '.lua'
	end

	-- If the path is a global path, use it directly
	local sStartChar = string.sub( _sCommand, 1, 1 )
	if sStartChar == "/" or sStartChar == "\\" then
		local sPath = fs.combine( "", _sCommand )
		if fs.exists( sPath ) and not fs.isDir( sPath ) then
			return sPath
		end
		return nil
	end

	-- Otherwise, look on the path variable
	for sPath in string.gmatch(PATH or '', "[^:]+") do
		sPath = fs.combine(sPath, _sCommand )
		if fs.exists( sPath ) and not fs.isDir( sPath ) then
			return sPath
		end
		if fs.exists(sPath .. '.lua') then
			return sPath .. '.lua'
		end
	end
	-- Not found
	return nil
end

function shell.programs( _bIncludeHidden )
	local tItems = {}

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
	local tItemList = {}
	for sItem in pairs( tItems ) do
		table.insert( tItemList, sItem )
	end
	table.sort( tItemList )
	return tItemList
end

local function completeProgram( sLine )
	if #sLine > 0 and string.sub( sLine, 1, 1 ) == "/" then
		-- Add programs from the root
		return fs.complete( sLine, "", true, false )
	else
		local tResults = {}
		local tSeen = {}

		-- Add aliases
		for sAlias in pairs( tAliases ) do
			if #sAlias > #sLine and string.sub( sAlias, 1, #sLine ) == sLine then
				local sResult = string.sub( sAlias, #sLine + 1 )
				if not tSeen[ sResult ] then
					table.insert( tResults, sResult )
					tSeen[ sResult ] = true
				end
			end
		end

		-- Add programs from the path
		local tPrograms = shell.programs()
		for n=1,#tPrograms do
			local sProgram = tPrograms[n]
			if #sProgram > #sLine and string.sub( sProgram, 1, #sLine ) == sLine then
				local sResult = string.sub( sProgram, #sLine + 1 )
				if not tSeen[ sResult ] then
					table.insert( tResults, sResult )
					tSeen[ sResult ] = true
				end
			end
		end

		-- Sort and return
		table.sort( tResults )
		return tResults
	end
end

local function completeProgramArgument( sProgram, nArgument, sPart, tPreviousParts )
	local tInfo = tCompletionInfo[ sProgram ]
	if tInfo then
		return tInfo.fnComplete( shell, nArgument, sPart, tPreviousParts )
	end
	return nil
end

function shell.complete(sLine)
	if #sLine > 0 then
		local tWords = tokenise( sLine )
		local nIndex = #tWords
		if string.sub( sLine, #sLine, #sLine ) == " " then
			nIndex = nIndex + 1
		end
		if nIndex == 1 then
			local sBit = tWords[1] or ""
			local sPath = shell.resolveProgram( sBit )
			if tCompletionInfo[ sPath ] then
				return { " " }
			else
				local tResults = completeProgram( sBit )
				for n=1,#tResults do
					local sResult = tResults[n]
					local cPath = shell.resolveProgram( sBit .. sResult )
					if tCompletionInfo[ cPath ] then
						tResults[n] = sResult .. " "
					end
				end
				return tResults
			end

		elseif nIndex > 1 then
			local sPath = shell.resolveProgram( tWords[1] )
			local sPart = tWords[nIndex] or ""
			local tPreviousParts = tWords
			tPreviousParts[nIndex] = nil
			return completeProgramArgument( sPath , nIndex - 1, sPart, tPreviousParts )
		end
	end
end

function shell.completeProgram( sProgram )
	return completeProgram( sProgram )
end

function shell.setCompletionFunction(sProgram, fnComplete)
	tCompletionInfo[sProgram] = { fnComplete = fnComplete }
end

function shell.getCompletionInfo()
	return tCompletionInfo
end

function shell.getRunningProgram()
	return tProgramStack[#tProgramStack]
end

function shell.setEnv(name, value)
	_ENV[name] = value
	sandboxEnv[name] = value
end

function shell.getEnv()
	return sandboxEnv
end

function shell.setAlias( _sCommand, _sProgram )
	tAliases[_sCommand] = _sProgram
end

function shell.clearAlias( _sCommand )
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
		tabInfo.env = Util.shallowCopy(sandboxEnv)
		tabInfo.args = args
		tabInfo.title = fs.getName(path):match('([^%.]+)')

		if path ~= 'sys/apps/shell.lua' then
			table.insert(tabInfo.args, 1, tabInfo.path)
			tabInfo.path = 'sys/apps/shell.lua'
		end
		return _ENV.multishell.openTab(tabInfo)
	end
	return nil, 'No such program'
end

function shell.openTab( ... )
	-- needs to use multishell.launch .. so we can run with stock multishell
	local tWords = tokenise( ... )
	local sCommand = tWords[1]
	if sCommand then
		local sPath = shell.resolveProgram(sCommand)
		if sPath == "sys/apps/shell.lua" then
			return _ENV.multishell.launch(Util.shallowCopy(sandboxEnv), sPath, table.unpack(tWords, 2))
		else
			return _ENV.multishell.launch(Util.shallowCopy(sandboxEnv), "sys/apps/shell.lua", sCommand, table.unpack(tWords, 2))
		end
	end
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
	local env = setmetatable(Util.shallowCopy(sandboxEnv), { __index = _G })
	_G.requireInjector(env)

	return run(env, ...)
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
local _rep      = string.rep
local _sub      = string.sub

if not terminal.scrollUp then
	terminal = Terminal.window(term.current())
	terminal.setMaxScroll(200)
	oldTerm = term.redirect(terminal)
end

local config = {
	color = {
		textColor = colors.white,
		commandTextColor = colors.yellow,
		directoryTextColor  = colors.orange,
		directoryBackgroundColor = colors.black,
		promptTextColor = colors.blue,
		promptBackgroundColor = colors.black,
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

local palette = { }
for n = 1, 16 do
	palette[2 ^ (n - 1)] = _sub("0123456789abcdef", n, n)
end

if not term.isColor() then
	_colors = { }
	for k, v in pairs(config.color) do
		_colors[k] = Terminal.colorToGrayscale(v)
	end
	for n = 1, 16 do
		palette[2 ^ (n - 1)] = _sub("088888878877787f", n, n)
	end
end

local function autocompleteArgument(program, words)
	local word = ''
	if #words > 1 then
		word = words[#words]
	end

	local tInfo = tCompletionInfo[program]
	return tInfo.fnComplete(shell, #words - 1, word, words)
end

local function autocompleteAnything(line, words)
	local results = shell.complete(line)

	if results and #results == 0 and #words == 1 then
		results = nil
	end
	if not results then
		results = fs.complete(words[#words] or '', shell.dir(), true, false)
	end

	return results
end

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

	local results

	local program = shell.resolveProgram(words[1])
	if tCompletionInfo[program] then
		results = autocompleteArgument(program, words) or { }
	else
		results = autocompleteAnything(line, words) or { }
	end

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
						words[#words] = string.sub(f, 1, i - 1)
						return table.concat(words, ' ')
					end
					if not ch then
						ch = string.sub(f, i, i)
					elseif string.sub(f, i, i) ~= ch then
						if i == #word + 1 then
							return
						end
						words[#words] = string.sub(f, 1, i - 1)
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
				nMaxLen = math.max(string.len(sItem) + 1, nMaxLen)
			end
			local w = term.getSize()
			local nCols = math.floor(w / nMaxLen)
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
		term.setBackgroundColor(_colors.promptBackgroundColor)
		term.write("$ " )

		term.setTextColour(_colors.commandTextColor)
		term.setBackgroundColor(_colors.backgroundColor)
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
		local filler = #entry.value < lastLen
			and string.rep(' ', lastLen - #entry.value)
			or ''
		local str = string.sub(entry.value, entry.scroll + 1, entry.width + entry.scroll) .. filler
		local fg = _rep(palette[_colors.commandTextColor], #str)
		local bg = _rep(palette[_colors.backgroundColor], #str)
		if entry.mark.active then
			local sx = entry.mark.x - entry.scroll + 1
			local ex = entry.mark.ex - entry.scroll + 1
			bg = string.rep('f', sx - 1) ..
				string.rep('7', ex - sx) ..
				string.rep('f', #str - ex + 1)
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
				if entry.textChanged then
					redraw()
				elseif entry.posChanged then
					updateCursor()
				end
			end

		elseif event == "term_resize" then
			entry.width = term.getSize() - 3
			entry:updateScroll()
			redraw()
		end
	end

	print()
	term.setCursorBlink( false )
	return entry.value
end

local history = History.load('usr/.shell_history', 25)

term.setBackgroundColor(_colors.backgroundColor)
term.clear()

while not bExit do
	if config.displayDirectory then
		term.setTextColour(_colors.directoryTextColor)
		term.setBackgroundColor(_colors.directoryBackgroundColor)
		print('==' .. os.getComputerLabel() .. ':/' .. DIR)
	end
	term.setTextColour(_colors.promptTextColor)
	term.setBackgroundColor(_colors.promptBackgroundColor)
	term.write("$ " )
	term.setTextColour(_colors.commandTextColor)
	term.setBackgroundColor(_colors.backgroundColor)
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
		if not result and err then
			_G.printError(err)
		end
	end
end

if oldTerm then
	term.redirect(oldTerm)
end
