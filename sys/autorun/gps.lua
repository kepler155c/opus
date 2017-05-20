if turtle and device.wireless_modem then

  local s, m = turtle.run(function()
    local homePt = turtle.loadLocation('gpsHome')

    if homePt then

      require = requireInjector(getfenv(1))
      local Config = require('config')
      local config = {
        destructive = false,
      }
      Config.load('gps', config)

      local GPS = require('gps')
      local pt
      for i = 1, 3 do
        pt = GPS.getPointAndHeading(2)
        if pt then
          break
        end
      end

      if not pt and config.destructive then
        turtle.setPolicy('turtleSafe')
        pt = GPS.getPointAndHeading(2)
      end

      if not pt then
        error('Unable to get GPS position')
      end

      if config.destructive then
        turtle.setPolicy('turtleSafe')
      end

      Util.print('Setting turtle point to %d %d %d', pt.x, pt.y, pt.z)
      turtle.setPoint(pt)
      turtle.getState().coordSystem = 'GPS'

      if not turtle.pathfind(homePt) then
        error('Failed to return home')
      end
    end
  end)

  turtle.setPolicy('none')

  if not s and m then
    error(m)
  end
end
