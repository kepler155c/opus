local Config = require('config')

local config = { }

local Security = { }

function Security.verifyPassword(password)
	Config.load('os', config)
	return config.password and password == config.password
end

function Security.hasPassword()
	return not not config.password
end

function Security.getSecretKey()
	Config.load('os', config)
	if not config.secretKey then
		config.secretKey = math.random(100000, 999999)
		Config.update('os', config)
	end
	return config.secretKey
end

function Security.getPublicKey()

	local exchange = {
		base = 11,
		primeMod = 625210769
	}

	local function modexp(base, exponent, modulo)
		local remainder = base

		for _ = 1, exponent-1 do
			remainder = remainder * remainder
			if remainder >= modulo then
				remainder = remainder % modulo
			end
		end

		return remainder
	end

	local secretKey = Security.getSecretKey()
	return modexp(exchange.base, secretKey, exchange.primeMod)
end

function Security.updatePassword(password)
	Config.load('os', config)
	config.password = password
	Config.update('os', config)
end

function Security.getPassword()
	Config.load('os', config)
	return config.password
end

return Security
