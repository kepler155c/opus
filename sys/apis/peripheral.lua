local Peripheral = { }

function Peripheral.addDevice(side)
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
    while device[uniqueName] do
      uniqueName = ptype .. '_' .. i
      i = i + 1
    end
    name = uniqueName
  end

  device[name] = peripheral.wrap(side)
  Util.merge(device[name], {
    name = name,
    type = ptype,
    side = side,
  })

  return device[name]
end

function Peripheral.getBySide(side)
  return Util.find(device, 'side', side)
end

function Peripheral.getByType(typeName)
  return Util.find(device, 'type', typeName)
end

function Peripheral.getByMethod(method)
  for _,p in pairs(device) do
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
