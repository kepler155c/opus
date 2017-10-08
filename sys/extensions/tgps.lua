local turtle = _G.turtle

if not turtle or turtle.enableGPS then
  return
end

_G.requireInjector()

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

  if turtle.point.gps then
    config.home = turtle.point
    Config.update('gps', config)
  else
    local pt = GPS.getPoint()
    if pt then
      local originalHeading = turtle.point.heading
      local heading = GPS.getHeading()
      if heading then
        local turns = (turtle.point.heading - originalHeading) % 4
        pt.heading = (heading - turns) % 4
        config.home = pt
        Config.update('gps', config)

        pt = GPS.getPoint()
        pt.heading = heading
        turtle.setPoint(pt, true)
        turtle.gotoPoint(config.home)
      end
    end
  end
end
