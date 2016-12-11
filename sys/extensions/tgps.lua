if not turtle then
  return
end

require = requireInjector(getfenv(1))
local GPS = require('gps')

function turtle.enableGPS()
  local pt = GPS.getPointAndHeading()
  if pt then
    turtle.setPoint(pt)
    return true
  end
end

function turtle.gotoGPSHome()
  local homePt = turtle.loadLocation('gpsHome')
  if homePt then
    local pt = GPS.getPointAndHeading()
    if pt then
      turtle.setPoint(pt)
      turtle.pathfind(homePt)
    end
  end
end

function turtle.setGPSHome()
  local GPS = require('gps')

  local pt = GPS.getPoint()
  if pt then
    turtle.setPoint(pt)
    pt.heading = GPS.getHeading()
    if pt.heading then
      turtle.point.heading = pt.heading
      turtle.storeLocation('gpsHome', pt)
      turtle.gotoPoint(pt)
    end
  end
end
