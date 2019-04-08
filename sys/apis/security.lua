local Config = require('config')

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
	local config = Config.load('os')
	config.password = password
	Config.update('os', config)
end

function Security.getPassword()
	return Config.load('os').password
end

return Security
