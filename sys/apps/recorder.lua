-- +---------------------+------------+---------------------+
-- |                     |            |                     |
-- |                     |   RecGif   |                     |
-- |                     |            |                     |
-- +---------------------+------------+---------------------+

local version = "Version 1.1.6"

-- Records your terminal and saves the result as an animating GIF.
-- http://www.computercraft.info/forums2/index.php?/topic/24840-recgif/

-- ----------------------------------------------------------

-- Original code by Bomb Bloke
-- Modified to integrate with opus os

requireInjector(getfenv(1))

local Util = require('util')

local recTerm, oldTerm, arg, showInput, skipLast, lastDelay, curInput = {}, Util.shallowCopy(multishell.term), {...}, false, false, 2, ""
local curBlink, oldBlink, tTerm, buffer, colourNum, xPos, yPos, oldXPos, oldYPos, tCol, bCol, xSize, ySize = false, false, {}, {}, {}, 1, 1, 1, 1, colours.white, colours.black, oldTerm.getSize()
local greys, buttons = {["0"] = true, ["7"] = true, ["8"] = true, ["f"] = true}, {"l", "r", "m"}
local charW, charH, chars, resp
local filename

local calls = { }
local curCalls = { delay = 0 }
local callListCount = 0
local callCount = 0

local function showSyntax()
	print('Gif Recorder by Bomb Bloke\n')
	print('Syntax: recGif [-i] [-s] [-ld:<delay>] filename')
	print('  -i  : show input')
	print('  -s  : skip last')
	print('  -ld : last delay')
end

for i = #arg, 1, -1 do
	local curArg = arg[i]:lower()
	
	if curArg == "-i" then
		showInput, ySize = true, ySize + 1
		table.remove(arg, i)
	elseif curArg == "-s" then
		skipLast = true
		table.remove(arg, i)
	elseif curArg:sub(1, 4) == "-ld:" then
		curArg = tonumber(curArg:sub(5))
		if curArg then lastDelay = curArg end
		table.remove(arg, i)
	elseif curArg == '-?' then
		showSyntax()
		return
	elseif i ~= #arg then
		showSyntax()
		printError('\nInvalid argument')
		return
	end
end

print('Press control-p to stop recording')

local filename = arg[#arg]
if not filename then
	print('Enter file name:')
	filename = read()
end

if #filename == 0 then
	showSyntax()
	print()
	error('Invalid file name')
end

print('Initializing...')

-- don't pollute global env
-- convert these to require style apis
local function loadAPI(url, env)
	local apiEnv = Util.shallowCopy(env)
	apiEnv.shell = nil
	apiEnv.multishell = nil
	setmetatable(apiEnv, { __index = _G })
	local fn = Util.loadUrl(url, apiEnv)
	fn()
	return apiEnv
end

bbpack  = loadAPI('http://pastebin.com/raw/PdrJjb5S', getfenv(1))
GIF     = loadAPI('http://pastebin.com/raw/5uk9uRjC', getfenv(1))

Util.runUrl(getfenv(1), 'http://pastebin.com/raw/cUYTGbpb', 'get', 'Y0eLUPtr')

local function snooze()
	local myEvent = tostring({})
	os.queueEvent(myEvent)
	os.pullEvent(myEvent)
end

local function safeString(text)
	local newText = {}
	
	for i = 1, #text do
		local val = text:byte(i)
		newText[i] = (val > 31 and val < 127) and val or 63
	end
	
	return string.char(unpack(newText))
end

local function safeCol(text, subst)
	local newText = {}
	
	for i = 1, #text do
		local val = text:sub(i, i)
		newText[i] = greys[val] and val or subst
	end
	
	return table.concat(newText)
end

-- Build a terminal that records stuff:

recTerm = multishell.term

for key, func in pairs(oldTerm) do
	recTerm[key] = function(...)
		local result = { func(...) }

		if callCount == 0 then
			os.queueEvent('capture_frame')
		end
		callCount = callCount + 1
		curCalls[callCount] = { key, ... }
		return unpack(result)
	end
end

local tabId = multishell.getCurrent()

multishell.addHotkey(25, function()
  os.queueEvent('recorder_stop')
end)

local tabs = multishell.getTabs()
for _,tab in pairs(tabs) do
	if tab.isOverview then
		multishell.hideTab(tabId)
		multishell.setFocus(tab.tabId)
		os.queueEvent('term_resize')
		break
	end
end

local curTime = os.clock() - 1

while true do
	local event = { os.pullEventRaw() }

	if event[1] == 'recorder_stop' or event[1] == 'terminate' then
		break
	end

	if event[1] == 'capture_frame' then
		local newTime = os.clock()

		if callListCount > 0 then
			calls[callListCount].delay = (newTime - curTime)
		end

		curTime = newTime
		callListCount = callListCount + 1
		calls[callListCount] = curCalls

		curCalls, callCount = { delay = 0 }, 0
	end
end

multishell.removeHotkey(25)

for k,fn in pairs(oldTerm) do
	multishell.term[k] = fn
end

multishell.unhideTab(tabId)
multishell.setFocus(tabId)

if #calls[#calls] == 0 then calls[#calls] = nil end
if skipLast and #calls > 1 then calls[#calls] = nil end

calls[#calls].delay = lastDelay

print(string.format("Encoding %d frames...", #calls))
--Util.writeTable('tmp/raw.txt', calls)

-- Perform a quick re-parse of the recorded data (adding frames for when the cursor blinks):

do
	local callListCount, tempCalls, blink, oldBlink, curBlink, blinkDelay = 1, {}, false, false, true, 0
	
	for i = 1, #calls - 1 do
		curCalls = calls[i]
		tempCalls[callListCount] = curCalls
		for j = 1, #curCalls do if curCalls[j][1] == "setCursorBlink" then blink = curCalls[j][2] end end
		
		if blink then
			if blinkDelay == 0 then
				curCalls[#curCalls + 1] = {"toggleCur", curBlink}
				blinkDelay, curBlink = 0.4, not curBlink
			end
			
			while tempCalls[callListCount].delay > blinkDelay do
				local remainder = tempCalls[callListCount].delay - blinkDelay
				tempCalls[callListCount].delay = blinkDelay
				callListCount = callListCount + 1
				tempCalls[callListCount] = {{"toggleCur", curBlink}, ["delay"] = remainder}
				blinkDelay, curBlink = 0.4, not curBlink
			end
			
			blinkDelay = blinkDelay - tempCalls[callListCount].delay
		else
			if oldBlink then curCalls[#curCalls + 1] = {"toggleCur", false} end
			blinkDelay = (curCalls.delay - blinkDelay) % 0.4
		end
		
		callListCount, oldBlink = callListCount + 1, blink
	end
	
	tempCalls[callListCount] = calls[#calls]
	tempCalls[callListCount][#tempCalls[callListCount] + 1] = {"toggleCur", false}
	
	calls, curCalls = tempCalls, nil
end

snooze()

-- Load font data:
do
	local ascii, counter = GIF.toPaintutils(GIF.flattenGIF(GIF.loadGIF("ascii.gif"))), 0
	local newFont, ybump, xbump = #ascii ~= #ascii[1], 0, 0
	charW, charH, chars = newFont and #ascii[1] / 16 or #ascii[1] * 3 / 64, #ascii / 16, {}

	for yy = 0, newFont and 15 or 7 do
		for xx = 0, 15 do
			local newChar, length = {}, 0

			-- Place in 2d grid of bools:
			for y = 1, charH do
				local newRow = {}

				for x = 1, charW do
					local set = ascii[y + ybump][x + xbump] == 1
					if set and x > length then length = x end
					newRow[x] = set
				end

				newChar[y] = newRow
			end

			-- Center:
			if not newFont then for y = 1, charH do for x = 1, math.floor((charW - length) / 2) do table.insert(newChar[y], 1, false) end end end

			chars[counter] = newChar
			counter, xbump = counter + 1, xbump + (newFont and charW or charH)
		end
		xbump, ybump = 0, ybump + charH
	end
end

snooze()

-- Terminal data translation:

do
	local hex, counter = "0123456789abcdef", 1

	for i = 1, 16 do
		colourNum[counter] = hex:sub(i, i)
		counter = counter * 2
	end
end

for y = 1, ySize do
	buffer[y] = {}
	for x = 1, xSize do buffer[y][x] = {" ", colourNum[tCol], colourNum[bCol]} end
end

if showInput then for x = 1, xSize do buffer[ySize][x][3] = colourNum[colours.lightGrey] end end

tTerm.blit = function(text, fgCol, bgCol)
	if xPos > xSize or xPos + #text - 1 < 1 or yPos < 1 or yPos > ySize then return end
	
	if not _HOST then text = safeString(text) end
	
	if not term.isColour() then
		fgCol = safeCol(fgCol, "0")
		bgCol = safeCol(bgCol, "f")
	end
	
	if xPos < 1 then
		text = text:sub(2 - xPos)
		fgCol = fgCol:sub(2 - xPos)
		bgCol = bgCol:sub(2 - xPos)
		xPos = 1
	end
	
	if xPos + #text - 1 > xSize then
		text = text:sub(1, xSize - xPos + 1)
		fgCol = fgCol:sub(1, xSize - xPos + 1)
		bgCol = bgCol:sub(1, xSize - xPos + 1)
	end
	
	for x = 1, #text do
		buffer[yPos][xPos + x - 1][1] = text:sub(x, x)
		buffer[yPos][xPos + x - 1][2] = fgCol:sub(x, x)
		buffer[yPos][xPos + x - 1][3] = bgCol:sub(x, x)
	end
	
	xPos = xPos + #text
end

tTerm.write = function(text)
	text = tostring(text)
	tTerm.blit(text, string.rep(colourNum[tCol], #text), string.rep(colourNum[bCol], #text))
end

tTerm.clearLine = function()
	local oldXPos = xPos
	
	xPos = 1
	tTerm.write(string.rep(" ", xSize))
	
	xPos = oldXPos
end

tTerm.clear = function()
	local oldXPos, oldYPos = xPos, yPos
	
	for y = 1, ySize do
		xPos, yPos = 1, y
		tTerm.write(string.rep(" ", xSize))
	end
	
	xPos, yPos = oldXPos, oldYPos
end

tTerm.setCursorPos = function(x, y)
	xPos, yPos = math.floor(x), math.floor(y)
end

tTerm.setTextColour = function(col)
	tCol = col
end

tTerm.setTextColor = function(col)
	tCol = col
end

tTerm.setBackgroundColour = function(col)
	bCol = col
end

tTerm.setBackgroundColor = function(col)
	bCol = col
end

tTerm.scroll = function(lines)
	if math.abs(lines) < ySize then
		local oldXPos, oldYPos = xPos, yPos
		
		for y = 1, ySize do
			if y + lines > 0 and y + lines <= ySize then
				for x = 1, xSize do
					xPos, yPos = x, y
					tTerm.blit(buffer[y + lines][x][1], buffer[y + lines][x][2], buffer[y + lines][x][3])
				end
			else
				yPos = y
				tTerm.clearLine()
			end
		end
		
		xPos, yPos = oldXPos, oldYPos
	else tTerm.clear() end
end

tTerm.toggleCur = function(newBlink)
	curBlink = newBlink
end

tTerm.newInput = function(input)
	local oldTC, oldBC, oldX, oldY = tCol, bCol, xPos, yPos
	tCol, bCol, xPos, yPos, ySize, input = colours.grey, colours.lightGrey, 1, ySize + 1, ySize + 1, input .. " "
	
	while #curInput + #input + 1 > xSize do curInput = curInput:sub(curInput:find(" ") + 1) end
	curInput = curInput .. input .. " "
	tTerm.clearLine()
	tTerm.write(curInput)
	
	tCol, bCol, xPos, yPos, ySize = oldTC, oldBC, oldX, oldY, ySize - 1
end

tTerm.key = function(key)
	tTerm.newInput((not keys.getName(key)) and "unknownKey" or keys.getName(key))
end

tTerm.mouse_click = function(button, x, y)
	tTerm.newInput(buttons[button] .. "C@" .. tostring(x) .. "x" .. tostring(y))
end

local image = {["width"] = xSize * charW, ["height"] = ySize * charH}

for i = 1, #calls do
	local xMin, yMin, xMax, yMax, oldBuffer, curCalls, changed = xSize + 1, ySize + 1, 0, 0, {}, calls[i], false
	calls[i] = nil
	
	for y = 1, ySize do
		oldBuffer[y] = {}
		for x = 1, xSize do oldBuffer[y][x] = {buffer[y][x][1], buffer[y][x][2], buffer[y][x][3], buffer[y][x][4]} end
	end
	
	snooze()
	
	if showInput then ySize = ySize - 1 end
	for j = 1, #curCalls do if tTerm[curCalls[j][1]] then tTerm[curCalls[j][1]](unpack(curCalls[j], 2)) end end
	if showInput then ySize = ySize + 1 end
	
	if i > 1 then
		for yy = 1, ySize do for xx = 1, xSize do if buffer[yy][xx][1] ~= oldBuffer[yy][xx][1] or (buffer[yy][xx][2] ~= oldBuffer[yy][xx][2] and buffer[yy][xx][1] ~= " ") or buffer[yy][xx][3] ~= oldBuffer[yy][xx][3] then
			changed = true
			if xx < xMin then xMin = xx end
			if xx > xMax then xMax = xx end
			if yy < yMin then yMin = yy end
			if yy > yMax then yMax = yy end
		end end end
	else xMin, yMin, xMax, yMax, changed = 1, 1, xSize, ySize, true end
	
	if oldBlink and (xPos ~= oldXPos or yPos ~= oldYPos or not curBlink) and oldXPos > 0 and oldYPos > 0 and oldXPos <= xSize and oldYPos <= ySize then
		changed = true
		if oldXPos < xMin then xMin = oldXPos end
		if oldXPos > xMax then xMax = oldXPos end
		if oldYPos < yMin then yMin = oldYPos end
		if oldYPos > yMax then yMax = oldYPos end
		buffer[oldYPos][oldXPos][4] = false
	end
	
	if curBlink and (xPos ~= oldXPos or yPos ~= oldYPos or not oldBlink) and xPos > 0 and yPos > 0 and xPos <= xSize and yPos <= ySize then
		changed = true
		if xPos < xMin then xMin = xPos end
		if xPos > xMax then xMax = xPos end
		if yPos < yMin then yMin = yPos end
		if yPos > yMax then yMax = yPos end
		buffer[yPos][xPos][4] = true
	end
	
	oldBlink, oldXPos, oldYPos = curBlink, xPos, yPos
	
	local thisFrame = {
		["xstart"] = (xMin - 1) * charW,
		["ystart"] = (yMin - 1) * charH,
		["xend"] = (xMax - xMin + 1) * charW,
		["yend"] = (yMax - yMin + 1) * charH,
		["delay"] = curCalls.delay,
		["disposal"] = 1
	}
	
	for y = 1, (yMax - yMin + 1) * charH do
		local row = {}
		for x = 1, (xMax - xMin + 1) * charW do row[x] = " " end
		thisFrame[y] = row
	end
	
	snooze()
	
	for yy = yMin, yMax do
		local yBump = (yy - yMin) * charH
		
		for xx = xMin, xMax do if buffer[yy][xx][1] ~= oldBuffer[yy][xx][1] or (buffer[yy][xx][2] ~= oldBuffer[yy][xx][2] and buffer[yy][xx][1] ~= " ") or buffer[yy][xx][3] ~= oldBuffer[yy][xx][3] or buffer[yy][xx][4] ~= oldBuffer[yy][xx][4] or  i == 1 then
			local thisChar, thisT, thisB, xBump = chars[buffer[yy][xx][1]:byte()], buffer[yy][xx][2], buffer[yy][xx][3], (xx - xMin) * charW
if thisChar then
			for y = 1, charH do
				for x = 1, charW do
					local ch = thisChar[y][x] and thisT or thisB
					thisFrame[y + yBump][x + xBump] = ch
				end
			end
end

			if buffer[yy][xx][4] then
				thisT, thisChar = colourNum[tCol], chars[95]
				for y = 1, charH do for x = 1, charW do if thisChar[y][x] then thisFrame[y + yBump][x + xBump] = thisT end end end
			end
		end end
		
		for y = yBump + 1, yBump + charH do
			local skip, chars, row = 0, {}, {}
			
			for x = 1, #thisFrame[y] do
				if thisFrame[y][x] == " " then
					if #chars > 0 then
						row[#row + 1] = table.concat(chars)
						chars = {}
					end
					
					skip = skip + 1
				else
					if skip > 0 then
						row[#row + 1] = skip
						skip = 0
					end
					
					chars[#chars + 1] = thisFrame[y][x]
				end
			end
			
			if #chars > 0 then row[#row + 1] = table.concat(chars) end
			thisFrame[y] = row
		end
		
		snooze()
	end
	
	if changed then 
		image[#image + 1] = thisFrame
	else
		image[#image].delay = image[#image].delay + curCalls.delay
	end
end

buffer = nil

GIF.saveGIF(image, filename)

fs.delete('ascii.gif')

print("Encode complete")
