local Security = require('security')
local SHA2     = require('sha2')
local Terminal = require('terminal')

local password = Terminal.readPassword('Enter new password: ')

if password then
	Security.updatePassword(SHA2.digest(password):toHex())
	print('Password updated')
end
