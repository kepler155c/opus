if device.wireless_modem then

  requireInjector(getfenv(1))
  local Config = require('config')

  local config = { }
  Config.load('gps', config)

  if config.host and type(config.host) == 'table' then

    multishell.setTitle(multishell.getCurrent(), 'GPS Daemon')

    os.run(getfenv(1), '/rom/programs/gps', 'host', config.host.x, config.host.y, config.host.z)

    print('GPS daemon stopped')
  end
end
