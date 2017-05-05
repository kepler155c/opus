require = requireInjector(getfenv(1))
local Config = require('config')
local SHA1 = require('sha1')

local config = {
  enable = false,
  pocketId = 10,
  distance = 8,
}

Config.load('os', config)

print('Enter new password')
local password = read()

config.password = SHA1.sha1(password)

Config.update('os', config)
