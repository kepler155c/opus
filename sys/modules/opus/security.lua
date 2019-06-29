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

local function genKey()
	local key = { }
	for _ = 1, 32 do
		table.insert(key, ("%02x"):format(math.random(0, 0xFF)))
	end
	return table.concat(key)
end

function Security.generateKeyPair()
	local privateKey = Util.hexToByteArray(genKey())
	return privateKey, ECC.publicKey(privateKey)
end

function Security.getIdentifier()
	return Security.geetPublicKey()
end

-- deprecate - will use getIdentifier
function Security.getSecretKey()
	local config = Config.load('os')
	if not config.secretKey then
		config.secretKey = genKey()
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
