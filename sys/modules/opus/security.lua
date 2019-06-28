local Config = require('opus.config')
local Util   = require('opus.util')
local ECC    = require('opus.crypto.ecc')

local Security = { }

function Security.verifyPassword(password)
	local current = Security.getPassword()
	return current and password == current
end

function Security.hasPassword()
	return not not Security.getPassword()
end

function Security.getSecretKey()
	local config = Config.load('os')
	if not config.secretKey then
		config.secretKey = ""
		for _ = 1, 32 do
			config.secretKey = config.secretKey .. ("%02x"):format(math.random(0, 0xFF))
		end
		Config.update('os', config)
	end
	return Util.hexToByteArray(config.secretKey)
end

function Security.getPublicKey()
	local secretKey = Security.getSecretKey()
	return ECC.publicKey(secretKey)
end

function Security.updatePassword(password)
	local config = Config.load('os')
	config.password = password
	Config.update('os', config)
end

function Security.getPassword()
	return Config.load('os').password
end

return Security
