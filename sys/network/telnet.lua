local Event  = require('event')
local Socket = require('socket')
local Util   = require('util')

local kernel = _G.kernel
local term   = _G.term
local window = _G.window

local function telnetHost(socket)
	local methods = { 'clear', 'clearLine', 'setCursorPos', 'write', 'blit',
										'setTextColor', 'setTextColour', 'setBackgroundColor',
										'setBackgroundColour', 'scroll', 'setCursorBlink', }

	local termInfo = socket:read(5)
	if not termInfo then
		_G.printError('read failed')
		return
	end

	local win = window.create(_G.device.terminal, 1, 1, termInfo.width, termInfo.height, false)
	win.setCursorPos(table.unpack(termInfo.pos))

	for _,k in pairs(methods) do
		local fn = win[k]
		win[k] = function(...)

			if not socket.queue then
				socket.queue = { }
				Event.onTimeout(0, function()
					socket:write(socket.queue)
					socket.queue = nil
				end)
			end

			table.insert(socket.queue, {
				f = k,
				args = { ... },
			})
			fn(...)
		end
	end

	local shellThread = kernel.run({
		terminal = win,
		window = win,
		title = 'Telnet client',
		hidden = true,
		co = coroutine.create(function()
			Util.run(_ENV, 'sys/apps/shell', table.unpack(termInfo.program))
			if socket.queue then
				socket:write(socket.queue)
			end
			socket:close()
		end)
	})

	Event.addRoutine(function()
		while true do
			local data = socket:read()
			if not data then
				shellThread:resume('terminate')
				break
			end
			local previousTerm = term.current()
			shellThread:resume(table.unpack(data))
			term.redirect(previousTerm)
		end
	end)
end

Event.addRoutine(function()
	print('telnet: listening on port 23')
	while true do
		local socket = Socket.server(23)

		print('telnet: connection from ' .. socket.dhost)

		Event.addRoutine(function()
			telnetHost(socket)
		end)
	end
end)
