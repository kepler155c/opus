-- Fq Integer Arithmetic

local unpack = table.unpack

local n = 0xffff
local m = 0x10000

local q = {1372, 62520, 47765, 8105, 45059, 9616, 65535, 65535, 65535, 65535, 65535, 65532}
local qn = {1372, 62520, 47765, 8105, 45059, 9616, 65535, 65535, 65535, 65535, 65535, 65532, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}

local function eq(a, b)
	for i = 1, 12 do
		if a[i] ~= b[i] then
			return false
		end
	end

	return true
end

local function cmp(a, b)
	for i = 12, 1, -1 do
		if a[i] > b[i] then
			return 1
		elseif a[i] < b[i] then
			return -1
		end
	end

	return 0
end

local function cmp384(a, b)
	for i = 24, 1, -1 do
		if a[i] > b[i] then
			return 1
		elseif a[i] < b[i] then
			return -1
		end
	end

	return 0
end

local function bytes(x)
	local result = {}

	for i = 0, 11 do
		local m = x[i + 1] % 256
		result[2 * i + 1] = m
		result[2 * i + 2] = (x[i + 1] - m) / 256
	end

	return result
end

local function fromBytes(enc)
	local result = {}

	for i = 0, 11 do
		result[i + 1] = enc[2 * i + 1] % 256
		result[i + 1] = result[i + 1] + enc[2 * i + 2] * 256
	end

	return result
end

local function sub192(a, b)
	local r1 = a[1] - b[1]
	local r2 = a[2] - b[2]
	local r3 = a[3] - b[3]
	local r4 = a[4] - b[4]
	local r5 = a[5] - b[5]
	local r6 = a[6] - b[6]
	local r7 = a[7] - b[7]
	local r8 = a[8] - b[8]
	local r9 = a[9] - b[9]
	local r10 = a[10] - b[10]
	local r11 = a[11] - b[11]
	local r12 = a[12] - b[12]

	if r1 < 0 then
		r2 = r2 - 1
		r1 = r1 + m
	end
	if r2 < 0 then
		r3 = r3 - 1
		r2 = r2 + m
	end
	if r3 < 0 then
		r4 = r4 - 1
		r3 = r3 + m
	end
	if r4 < 0 then
		r5 = r5 - 1
		r4 = r4 + m
	end
	if r5 < 0 then
		r6 = r6 - 1
		r5 = r5 + m
	end
	if r6 < 0 then
		r7 = r7 - 1
		r6 = r6 + m
	end
	if r7 < 0 then
		r8 = r8 - 1
		r7 = r7 + m
	end
	if r8 < 0 then
		r9 = r9 - 1
		r8 = r8 + m
	end
	if r9 < 0 then
		r10 = r10 - 1
		r9 = r9 + m
	end
	if r10 < 0 then
		r11 = r11 - 1
		r10 = r10 + m
	end
	if r11 < 0 then
		r12 = r12 - 1
		r11 = r11 + m
	end

	local result = {r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12}

	return result
end

local function reduce(a)
	local result = {unpack(a)}

	if cmp(result, q) >= 0 then
		result = sub192(result, q)
	end

	return result
end

local function add(a, b)
	local r1 = a[1] + b[1]
	local r2 = a[2] + b[2]
	local r3 = a[3] + b[3]
	local r4 = a[4] + b[4]
	local r5 = a[5] + b[5]
	local r6 = a[6] + b[6]
	local r7 = a[7] + b[7]
	local r8 = a[8] + b[8]
	local r9 = a[9] + b[9]
	local r10 = a[10] + b[10]
	local r11 = a[11] + b[11]
	local r12 = a[12] + b[12]

	if r1 > n then
		r2 = r2 + 1
		r1 = r1 - m
	end
	if r2 > n then
		r3 = r3 + 1
		r2 = r2 - m
	end
	if r3 > n then
		r4 = r4 + 1
		r3 = r3 - m
	end
	if r4 > n then
		r5 = r5 + 1
		r4 = r4 - m
	end
	if r5 > n then
		r6 = r6 + 1
		r5 = r5 - m
	end
	if r6 > n then
		r7 = r7 + 1
		r6 = r6 - m
	end
	if r7 > n then
		r8 = r8 + 1
		r7 = r7 - m
	end
	if r8 > n then
		r9 = r9 + 1
		r8 = r8 - m
	end
	if r9 > n then
		r10 = r10 + 1
		r9 = r9 - m
	end
	if r10 > n then
		r11 = r11 + 1
		r10 = r10 - m
	end
	if r11 > n then
		r12 = r12 + 1
		r11 = r11 - m
	end

	local result = {r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12}

	return reduce(result)
end

local function sub(a, b)
	local result = sub192(a, b)

	if result[12] < 0 then
		result = add(result, q)
	end

	return result
end

local function add384(a, b)
	local r1 = a[1] + b[1]
	local r2 = a[2] + b[2]
	local r3 = a[3] + b[3]
	local r4 = a[4] + b[4]
	local r5 = a[5] + b[5]
	local r6 = a[6] + b[6]
	local r7 = a[7] + b[7]
	local r8 = a[8] + b[8]
	local r9 = a[9] + b[9]
	local r10 = a[10] + b[10]
	local r11 = a[11] + b[11]
	local r12 = a[12] + b[12]
	local r13 = a[13] + b[13]
	local r14 = a[14] + b[14]
	local r15 = a[15] + b[15]
	local r16 = a[16] + b[16]
	local r17 = a[17] + b[17]
	local r18 = a[18] + b[18]
	local r19 = a[19] + b[19]
	local r20 = a[20] + b[20]
	local r21 = a[21] + b[21]
	local r22 = a[22] + b[22]
	local r23 = a[23] + b[23]
	local r24 = a[24] + b[24]

	if r1 > n then
		r2 = r2 + 1
		r1 = r1 - m
	end
	if r2 > n then
		r3 = r3 + 1
		r2 = r2 - m
	end
	if r3 > n then
		r4 = r4 + 1
		r3 = r3 - m
	end
	if r4 > n then
		r5 = r5 + 1
		r4 = r4 - m
	end
	if r5 > n then
		r6 = r6 + 1
		r5 = r5 - m
	end
	if r6 > n then
		r7 = r7 + 1
		r6 = r6 - m
	end
	if r7 > n then
		r8 = r8 + 1
		r7 = r7 - m
	end
	if r8 > n then
		r9 = r9 + 1
		r8 = r8 - m
	end
	if r9 > n then
		r10 = r10 + 1
		r9 = r9 - m
	end
	if r10 > n then
		r11 = r11 + 1
		r10 = r10 - m
	end
	if r11 > n then
		r12 = r12 + 1
		r11 = r11 - m
	end
	if r12 > n then
		r13 = r13 + 1
		r12 = r12 - m
	end
	if r13 > n then
		r14 = r14 + 1
		r13 = r13 - m
	end
	if r14 > n then
		r15 = r15 + 1
		r14 = r14 - m
	end
	if r15 > n then
		r16 = r16 + 1
		r15 = r15 - m
	end
	if r16 > n then
		r17 = r17 + 1
		r16 = r16 - m
	end
	if r17 > n then
		r18 = r18 + 1
		r17 = r17 - m
	end
	if r18 > n then
		r19 = r19 + 1
		r18 = r18 - m
	end
	if r19 > n then
		r20 = r20 + 1
		r19 = r19 - m
	end
	if r20 > n then
		r21 = r21 + 1
		r20 = r20 - m
	end
	if r21 > n then
		r22 = r22 + 1
		r21 = r21 - m
	end
	if r22 > n then
		r23 = r23 + 1
		r22 = r22 - m
	end
	if r23 > n then
		r24 = r24 + 1
		r23 = r23 - m
	end

	local result = {r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13, r14, r15, r16, r17, r18, r19, r20, r21, r22, r23, r24}

	return result
end

local function sub384(a, b)
	local r1 = a[1] - b[1]
	local r2 = a[2] - b[2]
	local r3 = a[3] - b[3]
	local r4 = a[4] - b[4]
	local r5 = a[5] - b[5]
	local r6 = a[6] - b[6]
	local r7 = a[7] - b[7]
	local r8 = a[8] - b[8]
	local r9 = a[9] - b[9]
	local r10 = a[10] - b[10]
	local r11 = a[11] - b[11]
	local r12 = a[12] - b[12]
	local r13 = a[13] - b[13]
	local r14 = a[14] - b[14]
	local r15 = a[15] - b[15]
	local r16 = a[16] - b[16]
	local r17 = a[17] - b[17]
	local r18 = a[18] - b[18]
	local r19 = a[19] - b[19]
	local r20 = a[20] - b[20]
	local r21 = a[21] - b[21]
	local r22 = a[22] - b[22]
	local r23 = a[23] - b[23]
	local r24 = a[24] - b[24]

	if r1 < 0 then
		r2 = r2 - 1
		r1 = r1 + m
	end
	if r2 < 0 then
		r3 = r3 - 1
		r2 = r2 + m
	end
	if r3 < 0 then
		r4 = r4 - 1
		r3 = r3 + m
	end
	if r4 < 0 then
		r5 = r5 - 1
		r4 = r4 + m
	end
	if r5 < 0 then
		r6 = r6 - 1
		r5 = r5 + m
	end
	if r6 < 0 then
		r7 = r7 - 1
		r6 = r6 + m
	end
	if r7 < 0 then
		r8 = r8 - 1
		r7 = r7 + m
	end
	if r8 < 0 then
		r9 = r9 - 1
		r8 = r8 + m
	end
	if r9 < 0 then
		r10 = r10 - 1
		r9 = r9 + m
	end
	if r10 < 0 then
		r11 = r11 - 1
		r10 = r10 + m
	end
	if r11 < 0 then
		r12 = r12 - 1
		r11 = r11 + m
	end
	if r12 < 0 then
		r13 = r13 - 1
		r12 = r12 + m
	end
	if r13 < 0 then
		r14 = r14 - 1
		r13 = r13 + m
	end
	if r14 < 0 then
		r15 = r15 - 1
		r14 = r14 + m
	end
	if r15 < 0 then
		r16 = r16 - 1
		r15 = r15 + m
	end
	if r16 < 0 then
		r17 = r17 - 1
		r16 = r16 + m
	end
	if r17 < 0 then
		r18 = r18 - 1
		r17 = r17 + m
	end
	if r18 < 0 then
		r19 = r19 - 1
		r18 = r18 + m
	end
	if r19 < 0 then
		r20 = r20 - 1
		r19 = r19 + m
	end
	if r20 < 0 then
		r21 = r21 - 1
		r20 = r20 + m
	end
	if r21 < 0 then
		r22 = r22 - 1
		r21 = r21 + m
	end
	if r22 < 0 then
		r23 = r23 - 1
		r22 = r22 + m
	end
	if r23 < 0 then
		r24 = r24 - 1
		r23 = r23 + m
	end

	local result = {r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13, r14, r15, r16, r17, r18, r19, r20, r21, r22, r23, r24}

	return result
end

local function mul384(a, b)
	local a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12 = unpack(a)
	local b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12 = unpack(b)

	local r1 = a1 * b1

	local r2 = a1 * b2
	r2 = r2 + a2 * b1

	local r3 = a1 * b3
	r3 = r3 + a2 * b2
	r3 = r3 + a3 * b1

	local r4 = a1 * b4
	r4 = r4 + a2 * b3
	r4 = r4 + a3 * b2
	r4 = r4 + a4 * b1

	local r5 = a1 * b5
	r5 = r5 + a2 * b4
	r5 = r5 + a3 * b3
	r5 = r5 + a4 * b2
	r5 = r5 + a5 * b1

	local r6 = a1 * b6
	r6 = r6 + a2 * b5
	r6 = r6 + a3 * b4
	r6 = r6 + a4 * b3
	r6 = r6 + a5 * b2
	r6 = r6 + a6 * b1

	local r7 = a1 * b7
	r7 = r7 + a2 * b6
	r7 = r7 + a3 * b5
	r7 = r7 + a4 * b4
	r7 = r7 + a5 * b3
	r7 = r7 + a6 * b2
	r7 = r7 + a7 * b1

	local r8 = a1 * b8
	r8 = r8 + a2 * b7
	r8 = r8 + a3 * b6
	r8 = r8 + a4 * b5
	r8 = r8 + a5 * b4
	r8 = r8 + a6 * b3
	r8 = r8 + a7 * b2
	r8 = r8 + a8 * b1

	local r9 = a1 * b9
	r9 = r9 + a2 * b8
	r9 = r9 + a3 * b7
	r9 = r9 + a4 * b6
	r9 = r9 + a5 * b5
	r9 = r9 + a6 * b4
	r9 = r9 + a7 * b3
	r9 = r9 + a8 * b2
	r9 = r9 + a9 * b1

	local r10 = a1 * b10
	r10 = r10 + a2 * b9
	r10 = r10 + a3 * b8
	r10 = r10 + a4 * b7
	r10 = r10 + a5 * b6
	r10 = r10 + a6 * b5
	r10 = r10 + a7 * b4
	r10 = r10 + a8 * b3
	r10 = r10 + a9 * b2
	r10 = r10 + a10 * b1

	local r11 = a1 * b11
	r11 = r11 + a2 * b10
	r11 = r11 + a3 * b9
	r11 = r11 + a4 * b8
	r11 = r11 + a5 * b7
	r11 = r11 + a6 * b6
	r11 = r11 + a7 * b5
	r11 = r11 + a8 * b4
	r11 = r11 + a9 * b3
	r11 = r11 + a10 * b2
	r11 = r11 + a11 * b1

	local r12 = a1 * b12
	r12 = r12 + a2 * b11
	r12 = r12 + a3 * b10
	r12 = r12 + a4 * b9
	r12 = r12 + a5 * b8
	r12 = r12 + a6 * b7
	r12 = r12 + a7 * b6
	r12 = r12 + a8 * b5
	r12 = r12 + a9 * b4
	r12 = r12 + a10 * b3
	r12 = r12 + a11 * b2
	r12 = r12 + a12 * b1

	local r13 = a2 * b12
	r13 = r13 + a3 * b11
	r13 = r13 + a4 * b10
	r13 = r13 + a5 * b9
	r13 = r13 + a6 * b8
	r13 = r13 + a7 * b7
	r13 = r13 + a8 * b6
	r13 = r13 + a9 * b5
	r13 = r13 + a10 * b4
	r13 = r13 + a11 * b3
	r13 = r13 + a12 * b2

	local r14 = a3 * b12
	r14 = r14 + a4 * b11
	r14 = r14 + a5 * b10
	r14 = r14 + a6 * b9
	r14 = r14 + a7 * b8
	r14 = r14 + a8 * b7
	r14 = r14 + a9 * b6
	r14 = r14 + a10 * b5
	r14 = r14 + a11 * b4
	r14 = r14 + a12 * b3

	local r15 = a4 * b12
	r15 = r15 + a5 * b11
	r15 = r15 + a6 * b10
	r15 = r15 + a7 * b9
	r15 = r15 + a8 * b8
	r15 = r15 + a9 * b7
	r15 = r15 + a10 * b6
	r15 = r15 + a11 * b5
	r15 = r15 + a12 * b4

	local r16 = a5 * b12
	r16 = r16 + a6 * b11
	r16 = r16 + a7 * b10
	r16 = r16 + a8 * b9
	r16 = r16 + a9 * b8
	r16 = r16 + a10 * b7
	r16 = r16 + a11 * b6
	r16 = r16 + a12 * b5

	local r17 = a6 * b12
	r17 = r17 + a7 * b11
	r17 = r17 + a8 * b10
	r17 = r17 + a9 * b9
	r17 = r17 + a10 * b8
	r17 = r17 + a11 * b7
	r17 = r17 + a12 * b6

	local r18 = a7 * b12
	r18 = r18 + a8 * b11
	r18 = r18 + a9 * b10
	r18 = r18 + a10 * b9
	r18 = r18 + a11 * b8
	r18 = r18 + a12 * b7

	local r19 = a8 * b12
	r19 = r19 + a9 * b11
	r19 = r19 + a10 * b10
	r19 = r19 + a11 * b9
	r19 = r19 + a12 * b8

	local r20 = a9 * b12
	r20 = r20 + a10 * b11
	r20 = r20 + a11 * b10
	r20 = r20 + a12 * b9

	local r21 = a10 * b12
	r21 = r21 + a11 * b11
	r21 = r21 + a12 * b10

	local r22 = a11 * b12
	r22 = r22 + a12 * b11

	local r23 = a12 * b12

	local r24 = 0

	r2 = r2 + (r1 / m)
	r2 = r2 - r2 % 1
	r1 = r1 % m
	r3 = r3 + (r2 / m)
	r3 = r3 - r3 % 1
	r2 = r2 % m
	r4 = r4 + (r3 / m)
	r4 = r4 - r4 % 1
	r3 = r3 % m
	r5 = r5 + (r4 / m)
	r5 = r5 - r5 % 1
	r4 = r4 % m
	r6 = r6 + (r5 / m)
	r6 = r6 - r6 % 1
	r5 = r5 % m
	r7 = r7 + (r6 / m)
	r7 = r7 - r7 % 1
	r6 = r6 % m
	r8 = r8 + (r7 / m)
	r8 = r8 - r8 % 1
	r7 = r7 % m
	r9 = r9 + (r8 / m)
	r9 = r9 - r9 % 1
	r8 = r8 % m
	r10 = r10 + (r9 / m)
	r10 = r10 - r10 % 1
	r9 = r9 % m
	r11 = r11 + (r10 / m)
	r11 = r11 - r11 % 1
	r10 = r10 % m
	r12 = r12 + (r11 / m)
	r12 = r12 - r12 % 1
	r11 = r11 % m
	r13 = r13 + (r12 / m)
	r13 = r13 - r13 % 1
	r12 = r12 % m
	r14 = r14 + (r13 / m)
	r14 = r14 - r14 % 1
	r13 = r13 % m
	r15 = r15 + (r14 / m)
	r15 = r15 - r15 % 1
	r14 = r14 % m
	r16 = r16 + (r15 / m)
	r16 = r16 - r16 % 1
	r15 = r15 % m
	r17 = r17 + (r16 / m)
	r17 = r17 - r17 % 1
	r16 = r16 % m
	r18 = r18 + (r17 / m)
	r18 = r18 - r18 % 1
	r17 = r17 % m
	r19 = r19 + (r18 / m)
	r19 = r19 - r19 % 1
	r18 = r18 % m
	r20 = r20 + (r19 / m)
	r20 = r20 - r20 % 1
	r19 = r19 % m
	r21 = r21 + (r20 / m)
	r21 = r21 - r21 % 1
	r20 = r20 % m
	r22 = r22 + (r21 / m)
	r22 = r22 - r22 % 1
	r21 = r21 % m
	r23 = r23 + (r22 / m)
	r23 = r23 - r23 % 1
	r22 = r22 % m
	r24 = r24 + (r23 / m)
	r24 = r24 - r24 % 1
	r23 = r23 % m

	local result = {r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13, r14, r15, r16, r17, r18, r19, r20, r21, r22, r23, r24}

	return result
end

local function reduce384(a)
	local result = {unpack(a)}

	while cmp384(result, qn) >= 0 do
		local qn = {unpack(qn)}
		local qn2 = add384(qn, qn)
		while cmp384(result, qn2) > 0 do
			qn = qn2
			qn2 = add384(qn2, qn2)
		end
		result = sub384(result, qn)
	end

	result = {unpack(result, 1, 12)}

	return result
end

local function mul(a, b)
	return reduce384(mul384(a, b))
end

return {
	eq = eq,
	cmp = cmp,
	bytes = bytes,
	fromBytes = fromBytes,
	reduce = reduce,
	add = add,
	sub = sub,
	mul = mul,
}
