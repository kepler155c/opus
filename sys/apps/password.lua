local Security = require('opus.security')
local SHA      = require('opus.crypto.sha2')
local Terminal = require('opus.terminal')

local password = Terminal.readPassword('Enter new password: ')

if password then
	Security.updatePassword(SHA.compute(password))
	print('Password updated')
end
