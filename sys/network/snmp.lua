local Event  = require('event')
local GPS    = require('gps')
local Socket = require('socket')
local Util   = require('util')

local device  = _G.device
local kernel  = _G.kernel
local network = _G.network
local os      = _G.os
local turtle  = _G.turtle

-- move this into gps api
local gpsRequested
local gpsLastPoint
local gpsLastRequestTime

local function snmpConnection(socket)
	while true do
		local msg = socket:read()
		if not msg then
			break
		end

		if msg.type == 'reboot' then
			os.reboot()

		elseif msg.type == 'shutdown' then
			os.shutdown()

		elseif msg.type == 'ping' then
			socket:write('pong')

		elseif msg.type == 'script' then
			local env = setmetatable(Util.shallowCopy(_ENV), { __index = _G })
			local fn, err = load(msg.args, 'script', nil, env)
			if fn then
				kernel.run({
					fn = fn,
					env = env,
					title = 'script',
				})
			else
				_G.printError(err)
			end

		elseif msg.type == 'scriptEx' then
			local s, m = pcall(function()
				local env = setmetatable(Util.shallowCopy(_ENV), { __index = _G })
				local fn, m = load(msg.args, 'script', nil, env)
				if not fn then
					error(m)
				end
				return { fn() }
			end)
			if s then
				socket:write(m)
			else
				socket:write({ s, m })
			end

		elseif msg.type == 'gps' then
			if gpsRequested then
				repeat
					os.sleep(0)
				until not gpsRequested
			end

			if gpsLastPoint and os.clock() - gpsLastRequestTime < .5 then
				socket:write(gpsLastPoint)
			else

				gpsRequested = true
				local pt = GPS.getPoint(2)
				if pt then
					socket:write(pt)
				else
					print('snmp: Unable to get GPS point')
				end
				gpsRequested = false
				gpsLastPoint = pt
				if pt then
					gpsLastRequestTime = os.clock()
				end
			end

		elseif msg.type == 'info' then
			local info = {
				id = os.getComputerID(),
				label = os.getComputerLabel(),
				uptime = math.floor(os.clock()),
			}
			if turtle then
				info.fuel = turtle.getFuelLevel()
				info.status = turtle.getStatus()
			end
			socket:write(info)
		end
	end
end

Event.addRoutine(function()
	print('snmp: listening on port 161')

	while true do
		local socket = Socket.server(161)

		Event.addRoutine(function()
			print('snmp: connection from ' .. socket.dhost)
			snmpConnection(socket)
			print('snmp: closing connection to ' .. socket.dhost)
		end)
	end
end)

device.wireless_modem.open(999)
print('discovery: listening on port 999')

Event.on('modem_message', function(_, _, sport, id, info, distance)
	if sport == 999 and tonumber(id) and type(info) == 'table' then
		if not network[id] then
			network[id] = { }
		end
		Util.merge(network[id], info)
		network[id].distance = distance
		network[id].timestamp = os.clock()

		if not network[id].active then
			network[id].active = true
			os.queueEvent('network_attach', network[id])
		end
	end
end)

local info = {
	id = os.getComputerID()
}
local infoTimer = os.clock()

local function sendInfo()
	if os.clock() - infoTimer >= 1 then -- don't flood
		infoTimer = os.clock()
		info.label = os.getComputerLabel()
		info.uptime = math.floor(os.clock())
		if turtle then
			info.fuel = turtle.getFuelLevel()
			info.status = turtle.getStatus()
			info.point = turtle.point
			info.inventory = turtle.getInventory()
			info.slotIndex = turtle.getSelectedSlot()
		end
		if device.neuralInterface then
			info.status = device.neuralInterface.status
			pcall(function()
				if not info.status and device.neuralInterface.getMetaOwner then
					info.status = 'health: ' ..
						math.floor(device.neuralInterface.getMetaOwner().health /
							device.neuralInterface.getMetaOwner().maxHealth * 100)
				end
			end)
		end
		device.wireless_modem.transmit(999, os.getComputerID(), info)
	end
end

-- every 10 seconds, send out this computer's info
Event.onInterval(10, function()
	sendInfo()
	for _,c in pairs(_G.network) do
		local elapsed = os.clock()-c.timestamp
		if c.active and elapsed > 15 then
			c.active = false
			os.queueEvent('network_detach', c)
		end
	end
end)

Event.on('turtle_response', function()
	if turtle.getStatus() ~= info.status or
		 turtle.fuel ~= info.fuel then
		sendInfo()
	end
end)
