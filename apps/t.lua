function doCommand(command, moves)
  --[[
  if command == 'sl' then
    local pt = GPS.getPoint()
    if pt then
      turtle.storeLocation(moves, pt)
    end
    return
  end
  --]]

  local function format(value)
    if type(value) == 'boolean' then
      if value then return 'true' end
      return 'false'
    end
    if type(value) ~= 'table' then
      return value
    end
    local str
    for k,v in pairs(value) do
      if not str then
        str = '{ '
      else
        str = str .. ', '
      end
      str = str .. k .. '=' .. tostring(v)
    end
    if str then
      str = str .. ' }'
    else
      str = '{ }'
    end

    return str
  end

  local function runCommand(fn, arg)
    local r = { fn(arg) }
    if r[2] then
      print(format(r[1]) .. ': ' .. format(r[2]))
    elseif r[1] then
      print(format(r[1]))
    end
    return r[1]
  end

  local cmds = {
    [ 's' ] = turtle.select,
    [ 'rf' ] = turtle.refuel,
    [ 'gh' ] = function() turtle.pathfind({ x = 0, y = 0, z = 0, heading = 0}) end,
  }

  local repCmds = {
    [ 'u' ] = turtle.up,
    [ 'd' ] = turtle.down,
    [ 'f' ] = turtle.forward,
    [ 'r' ] = turtle.turnRight,
    [ 'l' ] = turtle.turnLeft,
    [ 'ta' ] = turtle.turnAround,
    [ 'DD' ] = turtle.digDown,
    [ 'DU' ] = turtle.digUp,
    [ 'D' ] = turtle.dig,
    [ 'p' ] = turtle.place,
    [ 'pu' ] = turtle.placeUp,
    [ 'pd' ] = turtle.placeDown,
    [ 'b' ] = turtle.back,
    [ 'gfl' ] = turtle.getFuelLevel,
    [ 'gp' ] = turtle.getPoint,
    [ 'R' ] = function() turtle.setPoint({x = 0, y = 0, z = 0, heading = 0}) return turtle.point end
  }

  if cmds[command] then
    runCommand(cmds[command], moves)
  elseif repCmds[command] then
    for i = 1, moves do
      if not runCommand(repCmds[command]) then
        break
      end
    end
  end
end

local args = {...}

if #args > 0 then
  doCommand(args[1], args[2] or 1)
else
  print('Enter command (q to quit):')
  while true do
    local cmd = read()
    if cmd == 'q' then break
    end
    args = { }
    cmd:gsub('%w+', function(w) table.insert(args, w) end)
    doCommand(args[1], args[2] or 1)
  end
end
