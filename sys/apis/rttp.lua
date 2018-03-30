local device = _G.device
local os     = _G.os

local rttp = { }
local computerId = os.getComputerID()

local function parse(url, default)
	-- initialize default parameters
	local parsed = {}
	local authority

	for i,v in pairs(default or parsed) do parsed[i] = v end
	-- remove whitespace
	-- url = string.gsub(url, "%s", "")
	-- Decode unreserved characters
	url = string.gsub(url, "%%(%x%x)", function(hex)
			local char = string.char(tonumber(hex, 16))
			if string.match(char, "[a-zA-Z0-9._~-]") then
				return char
			end
			-- Hex encodings that are not unreserved must be preserved.
			return nil
		end)
	-- get fragment
	url = string.gsub(url, "#(.*)$", function(f)
		parsed.fragment = f
		return ""
	end)
	-- get scheme. Lower-case according to RFC 3986 section 3.1.
	url = string.gsub(url, "^(%w[%w.+-]*):",
	function(s) parsed.scheme = string.lower(s); return "" end)
	-- get authority
	url = string.gsub(url, "^//([^/]*)", function(n)
		authority = n
		return ""
	end)
	-- get query stringing
	url = string.gsub(url, "%?(.*)", function(q)
		parsed.query = q
		return ""
	end)
	-- get params
	url = string.gsub(url, "%;(.*)", function(p)
		parsed.params = p
		return ""
	end)

	-- path is whatever was left
	parsed.path = url

	-- Represents host:port, port = nil if not used.
	if authority then
		authority = string.gsub(authority, ":(%d+)$",
								function(p) parsed.port = tonumber(p); return "" end)
		if authority ~= "" then
			parsed.host = authority
		end
	end
	return parsed
end

function rttp.get(url)
	local modem  = device.wireless_modem or error('Modem not found')
	local parsed = parse(url, { port = 80 })

	parsed.host = tonumber(parsed.host) or error('Invalid url')

	for i = 16384, 32767 do
		if not modem.isOpen(i) then
			modem.open(i)
			local path = parsed.query and parsed.path .. '?' .. parsed.query or parsed.path

			modem.transmit(parsed.port, parsed.host, {
				method = 'GET',
				replyAddress = computerId,
				replyPort = i,
				path = path,
			})
			local timerId = os.startTimer(3)
			repeat
				local event, id, dport, dhost, response = os.pullEvent()
				if event == 'modem_message' and
					dport == i and
					dhost == computerId and
					type(response) == 'table' then
					modem.close(i)
					return true, response
				end
			until event == 'timer' and id == timerId
			return false, 'timeout'
		end
	end
end

return rttp
