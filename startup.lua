local colors   = _G.colors
local os       = _G.os
local settings = _G.settings
local term     = _G.term

local bootOptions = {
	{ prompt = os.version() },
	{ prompt = 'Opus'         , args = { '/sys/boot/opus.boot' } },
	{ prompt = 'Opus Shell'   , args = { '/sys/boot/opus.boot', 'sys/apps/shell.lua' } },
	{ prompt = 'Opus Kiosk'   , args = { '/sys/boot/kiosk.boot' } },
}
local bootOption = 2
if settings then
	settings.load('.settings')
	bootOption = tonumber(settings.get('opus.boot_option')) or bootOption
end

local function startupMenu()
	local x, y = term.getSize()
	local align, selected = 0, 1
	local function redraw()
		local title = "Boot Options:"
		term.clear()
		term.setTextColor(colors.white)
		term.setCursorPos((x/2)-(#title/2), (y/2)-(#bootOptions/2)-1)
		term.write(title)
		for i = 1, #bootOptions do
			local txt = i..". "..bootOptions[i].prompt
			term.setCursorPos((x/2)-(align/2), (y/2)-(#bootOptions/2)+i)
			term.write(txt)
		end
	end

	for i = 1, #bootOptions do
		if (bootOptions[i].prompt):len() > align then
			align = (bootOptions[i].prompt):len()
		end
	end

	redraw()
	repeat
		term.setCursorPos((x/2)-(align/2)-2, (y/2)-(#bootOptions/2)+selected)
		if term.isColor() then
			term.setTextColor(colors.yellow)
		else
			term.setTextColor(colors.lightGray)
		end
		term.write(">")
		local k = ({os.pullEvent()})
		if k[1] == "mouse_scroll" then
			if k[2] == 1 then 
				k = keys.down
			else
				k = keys.up
			end
		elseif k[1] == "key" then
			k = k[2]
		else
			k = nil
		end
		if k then
			if k == keys.enter or k == keys.right then
				return selected
			elseif k == keys.down then 
				if selected == #bootOptions then 
					selected = 0 
				end
				selected = selected+1 
			elseif k == keys.up then 
				if selected == 1 then 
					selected = #bootOptions+1 
				end
				selected = selected-1 
			elseif k >= keys.one and k <= #bootOptions+1 and k < keys.zero then 
				selected = k-1
				return selected
			end
			local cx, cy = term.getCursorPos()
			term.setCursorPos(cx-1, cy)
			term.write(" ")
		end
	until true == false
end

local function splash()
	local w, h = term.current().getSize()

	term.setTextColor(colors.white)
	if not term.isColor() then
		local str = 'Opus OS'
		term.setCursorPos((w - #str) / 2, h / 2)
		term.write(str)
	else
		term.setBackgroundColor(colors.black)
		term.clear()
		local opus = {
			'fffff00',
			'ffff07000',
			'ff00770b00 4444',
			'ff077777444444444',
			'f07777744444444444',
			'f0000777444444444',
			'070000111744444',
			'777770000',
			'7777000000',
			'70700000000',
			'077000000000',
		}
		for k,line in ipairs(opus) do
			term.setCursorPos((w - 18) / 2, k + (h - #opus) / 2)
			term.blit(string.rep(' ', #line), string.rep('a', #line), line)
		end
	end

	local str = 'Press any key for menu'
	term.setCursorPos((w - #str) / 2, h)
	term.write(str)
end

term.clear()
splash()

local timerId = os.startTimer(1.5)
while true do
	local e, id = os.pullEvent()
	if e == 'timer' and id == timerId then
		break
	end
	if e == 'char' then
		bootOption = startupMenu()
		if settings then
			settings.set('opus.boot_option', bootOption)
			settings.save('.settings')
		end
		break
	end
end

term.clear()
term.setCursorPos(1, 1)
if bootOptions[bootOption].args then
	os.run(_ENV, table.unpack(bootOptions[bootOption].args))
else
	print(bootOptions[bootOption].prompt)
end

