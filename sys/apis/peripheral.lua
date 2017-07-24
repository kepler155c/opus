local Peripheral = { }

local function getDeviceList()

  if _G.device then
    return _G.device
  end

  local deviceList = { }

  for _,side in pairs(peripheral.getNames()) do
    Peripheral.addDevice(deviceList, side)
  end

  return deviceList
end

function Peripheral.addDevice(deviceList, side)
  local name = side
  local ptype = peripheral.getType(side)

  if not ptype then
    return
  end

  if ptype == 'modem' then
    if peripheral.call(name, 'isWireless') then
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

  local s, m pcall(function() deviceList[name] = peripheral.wrap(side) end)
  if not s and m then
    printError('wrap failed')
    printError(m)
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
  return Util.find(getDeviceList(), 'side', side)
end

function Peripheral.getByType(typeName)
  return Util.find(getDeviceList(), 'type', typeName)
end

function Peripheral.getByMethod(method)
  for _,p in pairs(getDeviceList()) do
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

  args = args or { type = pType }

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

return Peripheral
