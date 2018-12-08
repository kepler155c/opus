local Event = require('event')
local Util  = require('util')

local fs    = _G.fs
local modem = _G.device.wireless_modem
local os    = _G.os

local computerId = os.getComputerID()

modem.open(80)

-- https://github.com/golgote/neturl/blob/master/lib/net/url.lua
local function parseQuery(str)
	local sep = '&'

	local values = {}
	for key,val in str:gmatch(string.format('([^%q=]+)(=*[^%q=]*)', sep, sep)) do
		--local key = decode(key)
		local keys = {}
		key = key:gsub('%[([^%]]*)%]', function(v)
				-- extract keys between balanced brackets
				if string.find(v, "^-?%d+$") then
					v = tonumber(v)
				--else
					--v = decode(v)
				end
				table.insert(keys, v)
				return "="
		end)
		key = key:gsub('=+.*$', "")
		key = key:gsub('%s', "_") -- remove spaces in parameter name
		val = val:gsub('^=+', "")

		if not values[key] then
			values[key] = {}
		end
		if #keys > 0 and type(values[key]) ~= 'table' then
			values[key] = {}
		elseif #keys == 0 and type(values[key]) == 'table' then
			values[key] = val --decode(val)
		end

		local t = values[key]
		for i,k in ipairs(keys) do
			if type(t) ~= 'table' then
				t = {}
			end
			if k == "" then
				k = #t+1
			end
			if not t[k] then
				t[k] = {}
			end
			if i == #keys then
				t[k] = val --decode(val)
			end
			t = t[k]
		end
	end
	return values
end

local function getListing(path, recursive)
	local list = { }
	local function listing(p)
		for _, f in pairs(fs.listEx(p)) do
			local abs = fs.combine(p, f.name)
			table.insert(list, {
				isDir = f.isDir,
				path = string.sub(abs, #path + 1),
				size = f.size,
			})
			if recursive and f.isDir then
				listing(abs)
			end
		end
	end
	listing(path)
	return list
end

Event.on('modem_message', function(_, _, dport, dhost, request)
	if dport == 80 and dhost == computerId and type(request) == 'table' then
		if request.method == 'GET' then
			local query
			if not request.path or type(request.path) ~= 'string' then
				return
			end
			local path = request.path:gsub('%?(.*)', function(v)
				query = parseQuery(v)
				return ''
			end)
			if fs.isDir(path) then
			-- TODO: more validation
				modem.transmit(request.replyPort, request.replyAddress, {
					statusCode = 200,
					contentType = 'table/directory',
					data = getListing(path, query and query.recursive == 'true'),
				})
			elseif fs.exists(path) then
				modem.transmit(request.replyPort, request.replyAddress, {
					statusCode = 200,
					contentType = 'table/file',
					data = Util.readFile(path),
				})
			else
				modem.transmit(request.replyPort, request.replyAddress, {
					statusCode = 404,
				})
			end
		end
	end
end)
