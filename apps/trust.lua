require = requireInjector(getfenv(1))
local Socket = require('socket')
local SHA1 = require('sha1')
local Terminal = require('terminal')
local Crypto = require('crypto')

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
local password = Terminal.readPassword('Enter password: ')

if not password then
  error('Invalid password')
end

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
local password = SHA1.sha1(password)

socket:write(Crypto.encrypt({ pk = publicKey, dh = os.getComputerID() }, password))

print(socket:read(2) or 'No response')

socket:close()
