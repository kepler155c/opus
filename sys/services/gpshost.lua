if device.wireless_modem then

  requireInjector(getfenv(1))
  local Config = require('config')
  local config = {
    host = false,
    auto = false,
    x = 0,
    y = 0,
    z = 0,
  }

  Config.load('gps', config)

  if config.host then

    multishell.setTitle(multishell.getCurrent(), 'GPS Daemon')

    if config.auto then
      local GPS = require('gps')
      local pt

      for i = 1, 3 do
        pt = GPS.getPoint(10, true)
        if pt then
          break
        end
      end

      if not pt then
        error('Unable to get GPS coordinates')
      end

      config.x = pt.x
      config.y = pt.y
      config.z = pt.z
    end

    os.run(getfenv(1), '/rom/programs/gps', 'host', config.x, config.y, config.z)

    print('GPS daemon stopped')
  end
end
