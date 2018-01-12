if _G.device.wireless_modem then

  _G.requireInjector()
  local Config = require('config')

  local config = { }
  Config.load('gps', config)

  if config.host and type(config.host) == 'table' then
    _ENV._APP_TITLE = 'GPS Daemon'
    os.run(_ENV, '/rom/programs/gps', 'host', config.host.x, config.host.y, config.host.z)
    print('GPS daemon stopped')
  end
end
