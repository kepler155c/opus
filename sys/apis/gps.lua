local GPS = { }

local device = _G.device
local gps    = _G.gps
local turtle = _G.turtle

function GPS.locate(timeout, debug)
	local pt = { }
	timeout = timeout or 10
	pt.x, pt.y, pt.z = gps.locate(timeout, debug)
	if pt.x then
		return pt
	end
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

function GPS.getHeading(timeout)

	if not turtle then
		return
	end

	local apt = GPS.locate(timeout)
	if not apt then
		return
	end

	local heading = turtle.point.heading

	while not turtle.forward() do
		turtle.turnRight()
		if turtle.getHeading() == heading then
			_G.printError('GPS.getPoint: Unable to move forward')
			return
		end
	end

	local bpt = GPS.locate()
	if not bpt then
		return
	end

	if apt.x < bpt.x then
		return 0
	elseif apt.z < bpt.z then
		return 1
	elseif apt.x > bpt.x then
		return 2
	end
	return 3
end

function GPS.getPointAndHeading(timeout)
	local heading = GPS.getHeading(timeout)
	if heading then
		local pt = GPS.getPoint()
		if pt then
			pt.heading = heading
		end
		return pt
	end
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

		local rounded1, rounded2 = result1:round(), result2:round()
		if rounded1.x ~= rounded2.x or rounded1.y ~= rounded2.y or rounded1.z ~= rounded2.z then
			return rounded1, rounded2
		else
			return rounded1
		end
	end
	return result:round()
end

local function narrow( p1, p2, fix )
	local dist1 = math.abs( (p1 - fix.position):length() - fix.distance )
	local dist2 = math.abs( (p2 - fix.position):length() - fix.distance )

	if math.abs(dist1 - dist2) < 0.05 then
		return p1, p2
	elseif dist1 < dist2 then
		return p1:round()
	else
		return p2:round()
	end
end
-- end stock gps api

function GPS.trilaterate(tFixes)
	local pos1, pos2 = trilaterate(tFixes[1], tFixes[2], tFixes[3])

	if pos2 then
		pos1, pos2 = narrow(pos1, pos2, tFixes[4])
	end

	if pos1 and pos2 then
		print("Ambiguous position")
		print("Could be "..pos1.x..","..pos1.y..","..pos1.z.." or "..pos2.x..","..pos2.y..","..pos2.z )
		return
	end

	return pos1
end

return GPS