if turtle and device.wireless_modem then

  local s, m = turtle.run(function()
    local homePt = turtle.loadLocation('gpsHome')

    if homePt then

      requireInjector(getfenv(1))

      local Config = require('config')
      local config = {
        destructive = false,
      }
      Config.load('gps', config)

      local s = turtle.enableGPS(2)
      if not s then
        s = turtle.enableGPS(2)
      end
      if not s and config.destructive then
        turtle.setPolicy('turtleSafe')
        s = turtle.enableGPS(2)
      end

      if not s then
        error('Unable to get GPS position')
      end

      if config.destructive then
        turtle.setPolicy('turtleSafe')
      end

      if not turtle.pathfind(homePt) then
        error('Failed to return home')
      end
    end
  end)

  if not s and m then
    error(m)
  end
end
