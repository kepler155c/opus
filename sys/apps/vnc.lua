_G.requireInjector(_ENV)

local Event      = require('event')
local Socket     = require('socket')
local Terminal   = require('terminal')
local Util       = require('util')

local colors     = _G.colors
local multishell = _ENV.multishell
local os         = _G.os
local term       = _G.term

local remoteId
local args = { ... }
if #args == 1 then
	remoteId = tonumber(args[1])
else
	print('Enter host ID')
	remoteId = tonumber(_G.read())
end

if not remoteId then
	error('Syntax: vnc <host ID>')
end

if multishell then
	multishell.setTitle(multishell.getCurrent(), 'VNC-' .. remoteId)
end

local function connect()
	local socket, msg = Socket.connect(remoteId, 5900)

	if not socket then
		return false, msg
	end

	local function writeTermInfo()
		local w, h = term.getSize()
		socket:write({
			type = 'termInfo',
			width = w,
			height = h,
			isColor = term.isColor(),
		})
	end

	writeTermInfo()

	local ct = Util.shallowCopy(term.current())

	if not ct.isColor() then
		Terminal.toGrayscale(ct)
	end

	ct.clear()
	ct.setCursorPos(1, 1)

	Event.addRoutine(function()
		while true do
			local data = socket:read()
			if not data then
				break
			end
			for _,v in ipairs(data) do
				ct[v.f](unpack(v.args))
			end
		end
	end)

	local filter = Util.transpose({
		'char', 'paste', 'key', 'key_up',
		'mouse_scroll', 'mouse_click', 'mouse_drag', 'mouse_up',
	})

	while true do
		local e = Event.pullEvent()
		local event = e[1]

		if not socket.connected then
			break
		end

		if filter[event] then
			socket:write({
				type = 'shellRemote',
				event = e,
			})
		elseif event == 'term_resize' then
			writeTermInfo()
		elseif event == 'terminate' then
			socket:close()
			ct.setBackgroundColor(colors.black)
			ct.clear()
			ct.setCursorPos(1, 1)
			return true
		end
	end
	return false, "Connection Lost"
end

while true do
	term.clear()
	term.setCursorPos(1, 1)

	print('connecting...')
	local s, m = connect()
	if s then
		break
	end

	term.setBackgroundColor(colors.black)
	term.setTextColor(colors.white)
	term.clear()
	term.setCursorPos(1, 1)
	print(m)
	print('\nPress any key to exit')
	print('\nRetrying in ... ')
	local x, y = term.getCursorPos()
	for i = 5, 1, -1 do
		local timerId = os.startTimer(1)
		term.setCursorPos(x, y)
		term.write(i)
		repeat
			local e, id = os.pullEvent()
			if e == 'char' or e == 'key' then
				return
			end
		until e == 'timer' and id == timerId
	end
end
