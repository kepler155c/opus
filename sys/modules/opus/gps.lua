local Util = require('opus.util')

local GPS = { }
GPS.CHANNEL_GPS = 65534

local device = _G.device
local vector = _G.vector

function GPS.locate(timeout, debug)
	if not device.wireless_modem then
		if debug then
			print('No wireless modem attached')
		end
		return nil
	end

	if debug then
		print('Finding position...')
	end

	local modem = device.wireless_modem
	local closeChannel = false
	if not modem.isOpen(GPS.CHANNEL_GPS) then
		modem.open(GPS.CHANNEL_GPS)
		closeChannel = true
	end

	modem.transmit(GPS.CHANNEL_GPS, GPS.CHANNEL_GPS, "PING")

	local fixes = {}
	local pos = nil
	local timer = os.startTimer(timeout or 1)
	while true do
		local e, side, chan, reply, msg, dist = os.pullEvent()
		if e == "modem_message" then
			if side == modem.side and chan == GPS.CHANNEL_GPS and reply == GPS.CHANNEL_GPS and dist then
				if type(msg) == "table" and #msg == 3 and tonumber(msg[1]) and tonumber(msg[2]) and tonumber(msg[3]) then
					local fix = {
						position = vector.new(unpack(msg)),
						distance = dist,
					}
					if debug then
						print(fix.distance..' meters from '..fix.position:tostring())
					end
					if fix.distance == 0 then
						pos = fix.position
					else
						fixes[#fixes+1] = fix
						if #fixes > 3 then
							pos = GPS.trilaterate(fixes)
							if pos then break end
						end
					end
				end
			end
		elseif e == "timer" and side == timer then
			break
		end
	end

	if closeChannel then
		modem.close(GPS.CHANNEL_GPS)
	end
	if debug then
		print("Position is "..pos.x..","..pos.y..","..pos.z)
	end
	return pos and vector.new(pos.x, pos.y, pos.z)
end

function GPS.isAvailable()
	return device.wireless_modem and GPS.locate()
end

function GPS.getPoint(timeout, debug)
	local pt = GPS.locate(timeout, debug)
	if not pt then
		return
	end

	pt.x = math.floor(pt.x)
	pt.y = math.floor(pt.y)
	pt.z = math.floor(pt.z)

	if _G.pocket then
		pt.y = pt.y - 1
	end

	return pt
end

-- from stock gps API
local function trilaterate(A, B, C)
	local a2b = B.position - A.position
	local a2c = C.position - A.position

	if math.abs( a2b:normalize():dot( a2c:normalize() ) ) > 0.999 then
		return
	end

	local d = a2b:length()
	local ex = a2b:normalize( )
	local i = ex:dot( a2c )
	local ey = (a2c - (ex * i)):normalize()
	local j = ey:dot( a2c )
	local ez = ex:cross( ey )

	local r1 = A.distance
	local r2 = B.distance
	local r3 = C.distance

	local x = (r1*r1 - r2*r2 + d*d) / (2*d)
	local y = (r1*r1 - r3*r3 - x*x + (x-i)*(x-i) + j*j) / (2*j)

	local result = A.position + (ex * x) + (ey * y)

	local zSquared = r1*r1 - x*x - y*y
	if zSquared > 0 then
		local z = math.sqrt( zSquared )
		local result1 = result + (ez * z)
		local result2 = result - (ez * z)

		local rounded1, rounded2 = result1:round(0.01), result2:round(0.01)
		if rounded1.x ~= rounded2.x or rounded1.y ~= rounded2.y or rounded1.z ~= rounded2.z then
			return rounded1, rounded2
		else
			return rounded1
		end
	end
	return result:round(0.01)
end

local function narrow( p1, p2, fix )
	local dist1 = math.abs( (p1 - fix.position):length() - fix.distance )
	local dist2 = math.abs( (p2 - fix.position):length() - fix.distance )

	if math.abs(dist1 - dist2) < 0.01 then
		return p1, p2
	elseif dist1 < dist2 then
		return p1:round(0.01)
	else
		return p2:round(0.01)
	end
end
-- end stock gps api

function GPS.trilaterate(tFixes)
	local attemps = 0
	for tFixes in Util.permutation(tFixes) do
		attemps = attemps + 1
		local pos1, pos2 = trilaterate(tFixes[4], tFixes[3], tFixes[2])
		if pos2 then
			pos1, pos2 = narrow(pos1, pos2, tFixes[1])
		end
		if not pos2 and pos1 and not (pos1.x ~= pos1.x) then
			return pos1, attemps
		end
	end
end

return GPS