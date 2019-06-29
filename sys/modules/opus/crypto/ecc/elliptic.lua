---- Elliptic Curve Arithmetic

---- About the Curve Itself
-- Field Size: 192 bits
-- Field Modulus (p): 65533 * 2^176 + 3
-- Equation: x^2 + y^2 = 1 + 108 * x^2 * y^2
-- Parameters: Edwards Curve with c = 1, and d = 108
-- Curve Order (n): 4 * 1569203598118192102418711808268118358122924911136798015831
-- Cofactor (h): 4
-- Generator Order (q): 1569203598118192102418711808268118358122924911136798015831
---- About the Curve's Security
-- Current best attack security: 94.822 bits (Pollard's Rho)
-- Rho Security: log2(0.884 * sqrt(q)) = 94.822
-- Transfer Security? Yes: p ~= q; k > 20
-- Field Discriminant Security? Yes: t = 67602300638727286331433024168; s = 2^2; |D| = 5134296629560551493299993292204775496868940529592107064435 > 2^100
-- Rigidity? A little, the parameters are somewhat small.
-- XZ/YZ Ladder Security? No: Single coordinate ladders are insecure, so they can't be used.
-- Small Subgroup Security? Yes: Secret keys are calculated modulo 4q.
-- Invalid Curve Security? Yes: Any point to be multiplied is checked beforehand.
-- Invalid Curve Twist Security? No: The curve is not protected against single coordinate ladder attacks, so don't use them.
-- Completeness? Yes: The curve is an Edwards Curve with non-square d and square a, so the curve is complete.
-- Indistinguishability? No: The curve does not support indistinguishability maps.

local fp = require('opus.crypto.ecc.fp')
local Util = require('opus.util')

local eq = fp.eq
local mul = fp.mul
local sqr = fp.sqr
local add = fp.add
local sub = fp.sub
local shr = fp.shr
local mont = fp.mont
local invMont = fp.invMont
local sub192 = fp.sub192
local unpack = table.unpack

local bits = 192
local pMinusTwoBinary = {1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
local pMinusThreeOverFourBinary = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0}
local ZERO = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
local ONE = mont({1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0})

local p = mont({3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 65533})
local G = {
	mont({30457, 58187, 5603, 63215, 8936, 58151, 26571, 7272, 26680, 23486, 32353, 59456}),
	mont({3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}),
	mont({1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0})
}
local GTable = {G}

local d = mont({108, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0})

local function generator()
	return G
end

local function expMod(a, t)
	local a = {unpack(a)}
	local result = {unpack(ONE)}

	for i = 1, bits do
		if t[i] == 1 then
			result = mul(result, a)
		end
		a = mul(a, a)
	end

	return result
end

-- We're using Projective Coordinates
-- For Edwards curves
-- The identity element is represented by (0:1:1)
local function pointDouble(P1)
	local X1, Y1, Z1 = unpack(P1)

	local b = add(X1, Y1)
	local B = sqr(b)
	local C = sqr(X1)
	local D = sqr(Y1)
	local E = add(C, D)
	local H = sqr(Z1)
	local J = sub(E, add(H, H))
	local X3 = mul(sub(B, E), J)
	local Y3 = mul(E, sub(C, D))
	local Z3 = mul(E, J)

	local P3 = {X3, Y3, Z3}

	return P3
end

local function pointAdd(P1, P2)
	local X1, Y1, Z1 = unpack(P1)
	local X2, Y2, Z2 = unpack(P2)

	local A = mul(Z1, Z2)
	local B = sqr(A)
	local C = mul(X1, X2)
	local D = mul(Y1, Y2)
	local E = mul(d, mul(C, D))
	local F = sub(B, E)
	local G = add(B, E)
	local X3 = mul(A, mul(F, sub(mul(add(X1, Y1), add(X2, Y2)), add(C, D))))
	local Y3 = mul(A, mul(G, sub(D, C)))
	local Z3 = mul(F, G)

	local P3 = {X3, Y3, Z3}

	return P3
end

local function pointNeg(P1)
	local X1, Y1, Z1 = unpack(P1)

	local X3 = sub(p, X1)
	local Y3 = {unpack(Y1)}
	local Z3 = {unpack(Z1)}

	local P3 = {X3, Y3, Z3}

	return P3
end

local function pointSub(P1, P2)
	return pointAdd(P1, pointNeg(P2))
end

local function pointScale(P1)
	local X1, Y1, Z1 = unpack(P1)

	local A = expMod(Z1, pMinusTwoBinary)
	local X3 = mul(X1, A)
	local Y3 = mul(Y1, A)
	local Z3 = {unpack(ONE)}

	local P3 = {X3, Y3, Z3}

	return P3
end

local function pointEq(P1, P2)
	local X1, Y1, Z1 = unpack(P1)
	local X2, Y2, Z2 = unpack(P2)

	local A1 = mul(X1, Z2)
	local B1 = mul(Y1, Z2)
	local A2 = mul(X2, Z1)
	local B2 = mul(Y2, Z1)

	return eq(A1, A2) and eq(B1, B2)
end

local function isOnCurve(P1)
	local X1, Y1, Z1 = unpack(P1)

	local X12 = sqr(X1)
	local Y12 = sqr(Y1)
	local Z12 = sqr(Z1)
	local Z14 = sqr(Z12)
	local a = add(X12, Y12)
	a = mul(a, Z12)
	local b = mul(d, mul(X12, Y12))
	b = add(Z14, b)

	return eq(a, b)
end

local function mods(d)
	-- w = 5
	local result = d[1] % 32

	if result >= 16 then
		result = result - 32
	end

	return result
end

local function NAF(d)
	local t = {}
	local d = {unpack(d)}

	while d[12] >= 0 and not eq(d, ZERO) do
		if d[1] % 2 == 1 then
			t[#t + 1] = mods(d)
			d = sub192(d, {t[#t], 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0})
		else
			t[#t + 1] = 0
		end

		d = shr(d)
	end

	return t
end

local function scalarMul(s, P1)
	local naf = NAF(s)
	local PTable = {P1}
	local P2 = pointDouble(P1)

	for i = 3, 31, 2 do
		PTable[i] = pointAdd(PTable[i - 2], P2)
	end

	local Q = {{unpack(ZERO)}, {unpack(ONE)}, {unpack(ONE)}}
	for i = #naf, 1, -1 do -- can this loop be optimized ?
		local n = naf[i]
		Q = pointDouble(Q)
		if n > 0 then
			Q = pointAdd(Q, PTable[n])
		elseif n < 0 then
			Q = pointSub(Q, PTable[-n])
		end
	end

	return Q
end

local throttle = Util.throttle()
for i = 2, 196 do
	GTable[i] = pointDouble(GTable[i - 1])
	throttle()
end

local function scalarMulG(s)
	local result = {{unpack(ZERO)}, {unpack(ONE)}, {unpack(ONE)}}
	local k = 1

	for i = 1, 12 do
		local w = s[i]

		for j = 1, 16 do
			if w % 2 == 1 then
				result = pointAdd(result, GTable[k])
			end

			k = k + 1

			w = w / 2
			w = w - w % 1
		end
	end

	return result
end

local function pointEncode(P1)
	P1 = pointScale(P1)

	local result = {}
	local x, y = unpack(P1)

	result[1] = x[1] % 2

	for i = 1, 12 do
		local m = y[i] % 256
		result[2 * i] = m
		result[2 * i + 1] = (y[i] - m) / 256
	end

	return result
end

local function pointDecode(enc)
	local y = {}
	for i = 1, 12 do
		y[i] = enc[2 * i]
		y[i] = y[i] + enc[2 * i + 1] * 256
	end

	local y2 = sqr(y)
	local u = sub(y2, ONE)
	local v = sub(mul(d, y2), ONE)
	local u2 = sqr(u)
	local u3 = mul(u, u2)
	local u5 = mul(u3, u2)
	local v3 = mul(v, sqr(v))
	local w = mul(u5, v3)
	local x = mul(u3, mul(v, expMod(w, pMinusThreeOverFourBinary)))

	if x[1] % 2 ~= enc[1] then
		x = sub(p, x)
	end

	local P3 = {x, y, {unpack(ONE)}}

	return P3
end

return {
	generator = generator,
	pointDouble = pointDouble,
	pointAdd = pointAdd,
	pointNeg = pointNeg,
	pointSub = pointSub,
	pointScale = pointScale,
	pointEq = pointEq,
	isOnCurve = isOnCurve,
	scalarMul = scalarMul,
	scalarMulG = scalarMulG,
	pointEncode = pointEncode,
	pointDecode = pointDecode,
}
