local Event = require('event')
local Socket = require('socket')
local Util   = require('util')

local Peripheral = Util.shallowCopy(_G.peripheral)

function Peripheral.getList()
  if _G.device then
    return _G.device
  end

  local deviceList = { }
  for _,side in pairs(Peripheral.getNames()) do
    Peripheral.addDevice(deviceList, side)
  end

  return deviceList
end

function Peripheral.addDevice(deviceList, side)
  local name = side
  local ptype = Peripheral.getType(side)

  if not ptype then
    return
  end

  if ptype == 'modem' then
    if Peripheral.call(name, 'isWireless') then
      ptype = 'wireless_modem'
    else
      ptype = 'wired_modem'
    end
  end

  local sides = {
    front = true,
    back = true,
    top = true,
    bottom = true,
    left = true,
    right = true
  }

  if sides[name] then
    local i = 1
    local uniqueName = ptype
    while deviceList[uniqueName] do
      uniqueName = ptype .. '_' .. i
      i = i + 1
    end
    name = uniqueName
  end

  local s, m = pcall(function() deviceList[name] = Peripheral.wrap(side) end)
  if not s and m then
    _G.printError('wrap failed')
    _G.printError(m)
  end

  if deviceList[name] then
    Util.merge(deviceList[name], {
      name = name,
      type = ptype,
      side = side,
    })

    return deviceList[name]
  end
end

function Peripheral.getBySide(side)
  return Util.find(Peripheral.getList(), 'side', side)
end

function Peripheral.getByType(typeName)
  return Util.find(Peripheral.getList(), 'type', typeName)
end

function Peripheral.getByMethod(method)
  for _,p in pairs(Peripheral.getList()) do
    if p[method] then
      return p
    end
  end
end

-- match any of the passed arguments
function Peripheral.get(args)

  if type(args) == 'string' then
    args = { type = args }
  end

  if args.device then
    return _G.device[args.device]
  end

  if args.type then
    local p = Peripheral.getByType(args.type)
    if p then
      return p
    end
  end

  if args.method then
    local p = Peripheral.getByMethod(args.method)
    if p then
      return p
    end
  end

  if args.side then
    local p = Peripheral.getBySide(args.side)
    if p then
      return p
    end
  end
end

local function getProxy(pi)
  local socket = Socket.connect(pi.host, 189)

  if not socket then
    error("Timed out attaching peripheral: " .. pi.uri)
  end

  socket:write(pi.path)
  local proxy = socket:read(3)

  if not proxy then
    error("Timed out attaching peripheral: " .. pi.uri)
  end

  local methods = proxy.methods
  proxy.methods = nil

  for _,method in pairs(methods) do
    proxy[method] = function(...)
      socket:write({ fn = method, args = { ... } })
      local resp = socket:read()
      if not resp then
        error("Timed out communicating with peripheral: " .. pi.uri)
      end
      return table.unpack(resp)
    end
  end

  if proxy.blit then
    local methods = { 'clear', 'clearLine', 'setCursorPos', 'write', 'blit',
                      'setTextColor', 'setTextColour', 'setBackgroundColor',
                      'setBackgroundColour', 'scroll', 'setCursorBlink', }
    local queue = nil

    for _,method in pairs(methods) do
      proxy[method] = function(...)
        if not queue then
          queue = { }
          Event.onTimeout(0, function()
            socket:write({ fn = 'fastBlit', args = { queue } })
            queue = nil
            socket:read()
          end)
        end

        table.insert(queue, {
          fn = method,
          args = { ... },
        })
      end
    end
  end

  if proxy.type == 'monitor' then
    Event.addRoutine(function()
      while true do
        local event = socket:read()
        if not event then
          break
        end
        if not Util.empty(event) then
          os.queueEvent(table.unpack(event))
        end
      end
    end)
  end

  return proxy
end

--[[
  Parse a uri into it's components

  Examples:
    monitor             = { device = 'monitor' }
    side/top            = { side = 'top' }
    method/list         = { method = 'list' }
    12://device/monitor = { host = 12, device = 'monitor' }
]]--
local function parse(uri)
  local pi = Util.split(uri:gsub('^%d*://', ''), '(.-)/')

  if #pi == 1 then
    pi = {
      'device',
      pi[1],
    }
  end

  return {
    host = uri:match('^(%d*)%:'),      -- 12
    uri  = uri,                        -- 12://device/monitor
    path = uri:gsub('^%d*://', ''),    -- device/monitor
    [ pi[1] ] = pi[2],                 -- device = 'monitor'
  }
end

function Peripheral.lookup(uri)
  local pi = parse(uri)

  if pi.host then
    return getProxy(pi)
  end

  return Peripheral.get(pi)
end

return Peripheral
