local Config = require('opus.config')

local Security = { }

function Security.verifyPassword(password)
	local current = Security.getPassword()
	return current and password == current
end

function Security.hasPassword()
	return not not Security.getPassword()
end

function Security.getIdentifier()
	local config = Config.load('os')

	if not config.identifier then
		local key = { }
		for _ = 1, 32 do
			table.insert(key, ("%02x"):format(math.random(0, 0xFF)))
		end
		config.identifier = table.concat(key)

		Config.update('os', config)
	end

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
