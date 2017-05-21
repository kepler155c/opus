local Socket = require('socket')
local GPS = require('gps')
local process = require('process')

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

      local fn, msg = loadstring(msg.args, 'script')
      if fn then
        multishell.openTab({
          fn = fn,
          env = getfenv(1),
          title = 'script',
        })
      else
        printError(msg)
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
        info.status = turtle.status
      end
      socket:write(info)
    end
  end
end

process:newThread('snmp_server', function()

  print('snmp: listening on port 161')

  while true do
    local socket = Socket.server(161)
    print('snmp: connection from ' .. socket.dhost)

    process:newThread('snmp_connection', function()
      snmpConnection(socket)
      print('snmp: closing connection to ' .. socket.dhost)
    end)
  end
end)

process:newThread('discovery_server', function()
  device.wireless_modem.open(999)

  --os.sleep(1) -- allow services a chance to startup
  print('discovery: listening on port 999')

  while true do
    local e, s, sport, id, info, distance = os.pullEvent('modem_message')

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
  end
end)

local info = {
  id = os.getComputerID()
}

local function sendInfo()
  info.label = os.getComputerLabel()
  info.uptime = math.floor(os.clock())
  if turtle then
    info.fuel = turtle.getFuelLevel()
    info.status = turtle.status
    info.point = turtle.point
    info.inventory = turtle.getInventory()
    info.coordSystem = turtle.getState().coordSystem
    info.slotIndex = turtle.getSelectedSlot()
  end
  device.wireless_modem.transmit(999, os.getComputerID(), info)
end

-- every 10 seconds, send out this computer's info
process:newThread('discovery_heartbeat', function()
  --os.sleep(1)

  while true do
    sendInfo()

    for _,c in pairs(_G.network) do
      local elapsed = os.clock()-c.timestamp
      if c.active and elapsed > 15 then
        c.active = false
        os.queueEvent('network_detach', c)
      end
    end

    os.sleep(10)
  end
end)

if os.isTurtle() then
  process:newThread('turtle_heartbeat', function()

    while true do
      os.pullEvent('turtle_response')
      if turtle.status ~= info.status or
         turtle.fuel ~= info.fuel then
        sendInfo()
      end
    end
  end)
end