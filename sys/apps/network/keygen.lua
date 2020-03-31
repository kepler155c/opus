local ECC    = require('opus.crypto.ecc')
local Event  = require('opus.event')
local Util   = require('opus.util')

local network = _G.network
local os      = _G.os

local keyPairs = { }

local function generateKeyPair()
	local key = { }
	for _ = 1, 32 do
		table.insert(key, math.random(0, 0xFF))
	end
	local privateKey = setmetatable(key, Util.byteArrayMT)
	return privateKey, ECC.publicKey(privateKey)
end

getmetatable(network).__index.getKeyPair = function()
	local keys = table.remove(keyPairs)
	os.queueEvent('generate_keypair')
	if not keys then
		return generateKeyPair()
	end
	return table.unpack(keys)
end

-- Generate key pairs in the background as this is a time-consuming process
Event.on('generate_keypair', function()
	while true do
		os.sleep(5)
		local timer = Util.timer()
		table.insert(keyPairs, { generateKeyPair() })
		_G._syslog('Generated keypair in ' .. timer())
		if #keyPairs >= 3 then
			break
		end
	end
end)
