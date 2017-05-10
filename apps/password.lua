require = requireInjector(getfenv(1))
local Config = require('config')
local SHA1 = require('sha1')
local Terminal = require('terminal')

local config = {
  enable = false,
  pocketId = 10,
  distance = 8,
}

Config.load('os', config)

local password = Terminal.readPassword('Enter new password: ')

if password then
  config.password = SHA1.sha1(password)
  Config.update('os', config)
  print('Password updated')
end
