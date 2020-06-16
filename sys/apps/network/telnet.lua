local Event  = require('opus.event')
local Socket = require('opus.socket')
local Util   = require('opus.util')

local kernel = _G.kernel
local shell  = _ENV.shell
local term   = _G.term
local window = _G.window

local function telnetHost(socket, mode)
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

	local shellThread = kernel.run(_ENV, {
		window = win,
		title = mode .. ' client',
		hidden = true,
		fn = function()
			Util.run(kernel.makeEnv(_ENV), shell.resolveProgram('shell'), table.unpack(termInfo.program))
			if socket.queue then
				socket:write(socket.queue)
			end
			socket:close()
		end,
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
	print('ssh: listening on port 22')
	while true do
		local socket = Socket.server(22, { ENCRYPT = true })

		print('ssh: connection from ' .. socket.dhost)

		Event.addRoutine(function()
			local s, m = pcall(telnetHost, socket, 'SSH')
			if not s and m then
				print('ssh error')
				_G.printError(m)
			end
		end)
	end
end)

Event.addRoutine(function()
	print('telnet: listening on port 23')
	while true do
		local socket = Socket.server(23)

		print('telnet: connection from ' .. socket.dhost)

		Event.addRoutine(function()
			local s, m = pcall(telnetHost, socket, 'Telnet')
			if not s and m then
				print('Telnet error')
				_G.printError(m)
			end
		end)
	end
end)
