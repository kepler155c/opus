local fq = require('crypto.ecc.fq')
local elliptic = require('crypto.ecc.elliptic')
local sha256 = require('crypto.sha2')

local q = {1372, 62520, 47765, 8105, 45059, 9616, 65535, 65535, 65535, 65535, 65535, 65532}

local sLen = 24
local eLen = 24

local function hashModQ(sk)
	local hash = sha256.hmac({0x00}, sk)
	local x
	repeat
		hash = sha256.digest(hash)
		x = fq.fromBytes(hash)
	until fq.cmp(x, q) <= 0

	return x
end

local function publicKey(sk)
	local x = hashModQ(sk)

	local Y = elliptic.scalarMulG(x)
	local pk = elliptic.pointEncode(Y)

	return pk
end

local function exchange(sk, pk)
	local Y = elliptic.pointDecode(pk)
	local x = hashModQ(sk)

	local Z = elliptic.scalarMul(x, Y)
	Z = elliptic.pointScale(Z)

	local ss = fq.bytes(Z[2])
	local ss = sha256.digest(ss)

	return ss
end

local function sign(sk, message)
	message = type(message) == "table" and string.char(unpack(message)) or message
	sk = type(sk) == "table" and string.char(unpack(sk)) or sk
	local epoch = tostring(os.epoch("utc"))
	local x = hashModQ(sk)
	local k = hashModQ(message .. epoch .. sk)
	
	local R = elliptic.scalarMulG(k)
	R = string.char(unpack(elliptic.pointEncode(R)))
	local e = hashModQ(R .. message)
	local s = fq.sub(k, fq.mul(x, e))

	e = fq.bytes(e)
	s = fq.bytes(s)

	local sig = {unpack(e)}

	for i = 1, #s do
		sig[#sig + 1] = s[i]
	end

	return sig
end

local function verify(pk, message, sig)
	local Y = elliptic.pointDecode(pk)
	local e = {unpack(sig, 1, eLen)}
	local s = {unpack(sig, eLen + 1, eLen + sLen)}

	e = fq.fromBytes(e)
	s = fq.fromBytes(s)

	local R = elliptic.pointAdd(elliptic.scalarMulG(s), elliptic.scalarMul(e, Y))
	R = string.char(unpack(elliptic.pointEncode(R)))
	local e2 = hashModQ(R .. message)

	return fq.eq(e2, e)
end

return {
	publicKey = publicKey,
	exchange = exchange,
	sign = sign,
	verify = verify,
}
