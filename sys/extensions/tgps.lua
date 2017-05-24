if not turtle then
  return
end

require = requireInjector(getfenv(1))
local GPS = require('gps')

function turtle.enableGPS(timeout)
  if turtle.getState().coordSystem == 'GPS' then
    return turtle.point
  end

  local pt = GPS.getPointAndHeading(timeout)
  if pt then
    turtle.setPoint(pt)
    turtle.getState().coordSystem = 'GPS'
    return true
  end
end

function turtle.gotoGPSHome()
  local homePt = turtle.loadLocation('gpsHome')
  if homePt then
    if turtle.enableGPS() then
      turtle.pathfind(homePt)
    end
  end
end

function turtle.setGPSHome()
  if turtle.enableGPS() then
    turtle.storeLocation('gpsHome', turtle.point)
    turtle.gotoPoint(tturtle.point)
  end
end
