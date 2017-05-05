require = requireInjector(getfenv(1))
local Socket = require('socket')
local SHA1 = require('sha1')

local remoteId
local args = { ... }
local exchange = {
  base = 11,
  primeMod = 625210769
}

if #args == 1 then
  remoteId = tonumber(args[1])
else
  print('Enter host ID')
  remoteId = tonumber(read())
end

if not remoteId then
  error('Syntax: trust <host ID>')
end

print('Password')
local password = read()

print('connecting...')
local socket = Socket.connect(remoteId, 19)

if not socket then
  error('Unable to connect to ' .. remoteId .. ' on port 19')
end

local function modexp(base, exponent, modulo)
  local remainder = base

  for i = 1, exponent-1 do
    remainder = remainder * remainder
    if remainder >= modulo then
      remainder = remainder % modulo
    end
  end

  return remainder
end

local secretKey = os.getSecretKey()
local publicKey = modexp(exchange.base, secretKey, exchange.primeMod)

socket:write({
  password = SHA1.sha1(password),
  publicKey = publicKey,
})

print(socket:read(2) or 'No response')

socket:close()
