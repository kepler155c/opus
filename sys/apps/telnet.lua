local Event    = require('opus.event')
local Socket   = require('opus.socket')
local Terminal = require('opus.terminal')
local Util     = require('opus.util')

local multishell = _ENV.multishell
local os         = _G.os
local read       = _G.read
local shell      = _ENV.shell
local term       = _G.term

local args, options = Util.parse(...)

local remoteId = tonumber(table.remove(args, 1) or '')
if not remoteId then
	print('Enter host ID')
	remoteId = tonumber(read())
end

if not remoteId then
	error('Syntax: telnet ID [PROGRAM] [ARGS]')
end

if multishell then
	multishell.setTitle(multishell.getCurrent(),
		(options.s and 'Secure ' or 'Telnet ') .. remoteId)
end

local socket, msg, reason

while true do
	socket, msg, reason = Socket.connect(remoteId, options.s and 22 or 23)

	if socket then
		break
	elseif reason ~= 'NOTRUST' then
		error(msg)
	end

	local s, m = shell.run('trust ' .. remoteId)
	if not s then
		error(m)
	end
end

local ct = Util.shallowCopy(term.current())
if not ct.isColor() then
	Terminal.toGrayscale(ct)
end

local w, h = ct.getSize()
socket:write({
	width = w,
	height = h,
	isColor = ct.isColor(),
	program = args,
	pos = { ct.getCursorPos() },
})

Event.addRoutine(function()
	while true do
		local data = socket:read()
		if not data then
			break
		end
		for _,v in ipairs(data) do
			ct[v.f](table.unpack(v.args))
		end
	end
end)

--ct.clear()
--ct.setCursorPos(1, 1)

local filter = Util.transpose {
	'char', 'paste', 'key', 'key_up', 'terminate',
	'mouse_scroll', 'mouse_click', 'mouse_drag', 'mouse_up',
}

while true do
	local e = { os.pullEventRaw() }
	local event = e[1]

	if filter[event] then
		socket:write(e)
	else
		Event.processEvent(e)
	end

	if not socket.connected then
--    print()
--    print('Connection lost')
--    print('Press enter to exit')
--    pcall(read)
		break
	end
end
