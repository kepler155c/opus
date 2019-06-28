local Security = require('security')
local SHA      = require('crypto.sha2')
local Terminal = require('terminal')

local password = Terminal.readPassword('Enter new password: ')

if password then
	Security.updatePassword(SHA.compute(password))
	print('Password updated')
end
