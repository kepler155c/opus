local Config = require('config')

local shell = _ENV.shell

local config = Config.load('os')
if not config.welcomed and shell.openForegroundTab then
	config.welcomed = true
	Config.update('os', config)

	shell.openForegroundTab('Welcome')
end
