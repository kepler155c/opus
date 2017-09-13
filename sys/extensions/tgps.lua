if not turtle or turtle.enableGPS then
  return
end

requireInjector(getfenv(1))

local GPS    = require('gps')
local Config = require('config')

function turtle.enableGPS(timeout)
  if turtle.point.gps then
    return turtle.point
  end

  local pt = GPS.getPointAndHeading(timeout)
  if pt then
    turtle.setPoint(pt, true)
    return turtle.point
  end
end

function turtle.gotoGPSHome()
  local config = { }
  Config.load('gps', config)

  if config.home then
    if turtle.enableGPS() then
      turtle.pathfind(config.home)
    end
  end
end

function turtle.setGPSHome()
  local config = { }
  Config.load('gps', config)

  if turtle.enableGPS() then
    config.home = turtle.point
    Config.update('gps', config)
    turtle.gotoPoint(turtle.point)
  end
end
