--[[
	.startup.boot
		delay
			description:	delays amount before starting the default selection
			default:		1.5

		preload
			description :	runs before menu is displayed, can be used for password
							locking, drive encryption, etc.
			example :		{ [1] = '/path/somefile.lua', [2] = 'path2/another.lua' }

		menu
			description:	array of menu entries (see .startup.boot for examples)
]]

local colors    = _G.colors
local fs        = _G.fs
local keys      = _G.keys
local os        = _G.os
local settings  = _G.settings
local term      = _G.term
local textutils = _G.textutils

local function loadBootOptions()
	if not fs.exists('.startup.boot') then
		local f = fs.open('.startup.boot', 'w')
		f.write(textutils.serialize({
			delay = 1.5,
			preload = { },
			menu = {
				{ prompt = os.version() },
				{ prompt = 'Opus'         , args = { '/sys/boot/opus.lua' } },
				{ prompt = 'Opus Shell'   , args = { '/sys/boot/opus.lua', '/sys/apps/shell.lua' } },
				{ prompt = 'Opus Kiosk'   , args = { '/sys/boot/kiosk.lua' } },
				{ prompt = 'Opus TLCO'    , args = { '/sys/boot/tlco.lua' } },
			},
		}))
		f.close()
	end

	local f = fs.open('.startup.boot', 'r')
	local options = textutils.unserialize(f.readAll())
	f.close()

	-- Backwards compatibility for .startup.boot files created before sys/boot files' extensions were changed
	local changed = false
	for _, item in pairs(options.menu) do
		if item.args and item.args[1]:match("/?sys/boot/%l+%.boot") then
			item.args[1] = item.args[1]:gsub("%.boot", "%.lua")
			changed = true
		end
	end
	if changed then 
		local f = fs.open(".startup.boot", "w")
		f.write(textutils.serialize(options))
		f.close()
	end

	return options
end

local bootOptions = loadBootOptions()

local bootOption = 2
if settings then
	settings.load('.settings')
	bootOption = tonumber(settings.get('opus.boot_option')) or bootOption
end

local function startupMenu()
	local x, y = term.getSize()
	local align, selected = 0, bootOption

	local function redraw()
		local title = "Boot Options:"
		term.clear()
		term.setTextColor(colors.white)
		term.setCursorPos((x/2)-(#title/2), (y/2)-(#bootOptions.menu/2)-1)
		term.write(title)
		for i, item in pairs(bootOptions.menu) do
			local txt = i .. ". " .. item.prompt
			term.setCursorPos((x/2)-(align/2), (y/2)-(#bootOptions.menu/2)+i)
			term.write(txt)
		end
	end

	for _, item in pairs(bootOptions.menu) do
		if #item.prompt > align then
			align = #item.prompt
		end
	end

	redraw()
	while true do
		term.setCursorPos((x/2)-(align/2)-2, (y/2)-(#bootOptions.menu/2)+selected)
		term.setTextColor(term.isColor() and colors.yellow or colors.lightGray)

		term.write(">")
		local event, key = os.pullEvent()
		if event == "mouse_scroll" then
			key = key == 1 and keys.down or keys.up
		elseif event == 'key_up' then
			key = nil  -- only process key events
		end

		if key == keys.enter or key == keys.right then
			return selected
		elseif key == keys.down then
			if selected == #bootOptions.menu then
				selected = 0
			end
			selected = selected + 1
		elseif key == keys.up then
			if selected == 1 then
				selected = #bootOptions.menu + 1
			end
			selected = selected - 1
		elseif event == 'char' then
			key = tonumber(key) or 0
			if bootOptions.menu[key] then
				return key
			end
		end

		local cx, cy = term.getCursorPos()
		term.setCursorPos(cx-1, cy)
		term.write(" ")
	end
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
			'ff00770b00f4444',
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

for _, v in pairs(bootOptions.preload) do
	os.run(_ENV, v)
end

term.clear()
splash()

local timerId = os.startTimer(bootOptions.delay)
while true do
	local e, id = os.pullEvent()
	if e == 'timer' and id == timerId then
		break
	end
	if e == 'char' or e == 'key' then
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
if bootOptions.menu[bootOption].args then
	os.run(_ENV, table.unpack(bootOptions.menu[bootOption].args))
else
	print(bootOptions.menu[bootOption].prompt)
end

