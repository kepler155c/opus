require = requireInjector(getfenv(1))
local SHA1 = require('sha1')
local Terminal = require('terminal')

local password = Terminal.readPassword('Enter new password: ')

if password then
  os.updatePassword(SHA1.sha1(password))
  print('Password updated')
end
