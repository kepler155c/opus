local Config = require('opus.config')
local ECC    = require('opus.crypto.ecc')
local Util   = require('opus.util')

local Security = { }

function Security.verifyPassword(password)
	local current = Security.getPassword()
	return current and password == current
end

function Security.hasPassword()
	return not not Security.getPassword()
end

local function genKey()
	local key = { }
	for _ = 1, 32 do
		table.insert(key, ("%02x"):format(math.random(0, 0xFF)))
	end
	return table.concat(key)
end

function Security.getSecretKey()
	local config = Config.load('os')
	if not config.secretKey then
		config.secretKey = genKey()
		Config.update('os', config)
	end
	return Util.hexToByteArray(config.secretKey)
end

function Security.getIdentifier()
	local config = Config.load('os')
	if config.identifier then
		return config.identifier
	end
	-- preserve the hash the user generated
	local identifier = ECC.publicKey(Security.getSecretKey())
	config.identifier = Util.byteArrayToHex(identifier)
	Config.update('os', config)

	return config.identifier
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
