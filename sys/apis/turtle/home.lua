local Config = require('config')
local GPS    = require('gps')

local turtle = _G.turtle

local Home = { }

function Home.go()
  local config = { }
  Config.load('gps', config)

  if config.home then
    if turtle.enableGPS() then
      return turtle.pathfind(config.home)
    end
  end
end

function Home.set()
  local config = { }
  Config.load('gps', config)

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
      turtle._goto(config.home)
      return config.home
    end
  end
end

return Home
