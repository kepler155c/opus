local Util = { }

local fs        = _G.fs
local http      = _G.http
local os        = _G.os
local term      = _G.term
local textutils = _G.textutils

local _sformat  = string.format
local _srep     = string.rep
local _ssub     = string.sub

function Util.hexToByteArray(str)
	local r = {}
	str = tostring(str)
	for b in str:gmatch("%x%x?") do
			r[#r+1] = tonumber(b, 16)
	end
	return r
end

function Util.byteArrayToHex(tbl)
	if not tbl then error('byteArrayToHex: invalid table', 2) end
	return ("%02x"):rep(#tbl):format(table.unpack(tbl))
end

function Util.tryTimed(timeout, f, ...)
	local c = os.clock()
	repeat
		local ret = f(...)
		if ret then
			return ret
		end
	until os.clock()-c >= timeout
end

function Util.tryTimes(attempts, f, ...)
	local result
	for _ = 1, attempts do
		result = { f(...) }
		if result[1] then
			return table.unpack(result)
		end
	end
	return table.unpack(result)
end

function Util.timer()
	local ct = os.clock()
	return function()
		return os.clock() - ct
	end
end

Util.Timer = Util.timer -- deprecate

function Util.throttle(fn)
	local ts = os.clock()
	local timeout = .295
	return function(...)
		local nts = os.clock()
		if nts > ts + timeout then
			os.sleep(0)
			ts = os.clock()
			if fn then
				fn(...)
			end
		end
	end
end

function Util.tostring(pattern, ...)

	local function serialize(tbl, width)
		local str = '{\n'
		for k, v in pairs(tbl) do
			local value
			if type(v) == 'table' then
				value = _sformat('table: %d', Util.size(v))
			else
				value = tostring(v)
			end
			str = str .. _sformat(' %s: %s\n', k, value)
		end
		--if #str < width then
			--str = str:gsub('\n', '') .. ' }'
		--else
			str = str .. '}'
		--end
		return str
	end

	if type(pattern) == 'string' then
		if select('#', ...) == 0 then
			return pattern
		end
		return _sformat(pattern, ...)
	elseif type(pattern) == 'table' then
		return serialize(pattern, term.current().getSize())
	end
	return tostring(pattern)
end

function Util.print(pattern, ...)
	print(Util.tostring(pattern, ...))
end

function Util.getVersion()
	local version

	if _G._CC_VERSION then
		version = tonumber(_G._CC_VERSION:match('[%d]+%.?[%d][%d]'))
	end
	if not version and _G._HOST then
		version = tonumber(_G._HOST:match('[%d]+%.?[%d][%d]'))
	end

	return version or 1.7
end

function Util.getMinecraftVersion()
	local mcVersion = _G._MC_VERSION or 'unknown'
	if _G._HOST then
		local version = _G._HOST:match('%S+ %S+ %((%S.+)%)')
		if version then
			mcVersion = version:match('Minecraft (%S+)') or version
		end
	end
	return mcVersion
end

function Util.checkMinecraftVersion(minVersion)
	local version = Util.getMinecraftVersion()
	local function convert(v)
		local m1, m2, m3 = v:match('(%d)%.(%d)%.?(%d?)')
		return tonumber(m1) * 10000 + tonumber(m2) * 100 + (tonumber(m3) or 0)
	end

	return convert(version) >= convert(tostring(minVersion))
end

function Util.signum(num)
	if num > 0 then
		return 1
	elseif num < 0 then
		return -1
	else
		return 0
	end
end

function Util.clamp(num, low, high)
	return num < low and low or num > high and high or num
end

-- http://lua-users.org/wiki/SimpleRound
function Util.round(num, idp)
	local mult = 10^(idp or 0)
	return Util.signum(num) * math.floor(math.abs(num) * mult + 0.5) / mult
end

function Util.randomFloat(max, min)
	min = min or 0
	max = max or 1
	return (max-min) * math.random() + min
end

--[[ Table functions ]] --
function Util.clear(t)
	local keys = Util.keys(t)
	for _,k in pairs(keys) do
		t[k] = nil
	end
end

function Util.empty(t)
	return not next(t)
end

function Util.key(t, value)
	for k,v in pairs(t) do
		if v == value then
			return k
		end
	end
end

function Util.keys(t)
	local keys = { }
	for k in pairs(t) do
		keys[#keys+1] = k
	end
	return keys
end

function Util.merge(obj, args)
	if args then
		for k,v in pairs(args) do
			obj[k] = v
		end
	end
	return obj
end

function Util.deepMerge(obj, args)
	if args then
		for k,v in pairs(args) do
			if type(v) == 'table' then
				if not obj[k] then
					obj[k] = { }
				end
				Util.deepMerge(obj[k], v)
			else
				obj[k] = v
			end
		end
	end
end

function Util.transpose(t)
	local tt = { }
	for k,v in pairs(t) do
		tt[v] = k
	end
	return tt
end

function Util.contains(t, value)
	for k,v in pairs(t) do
		if v == value then
			return k
		end
	end
end

function Util.find(t, name, value)
	for k,v in pairs(t) do
		if v[name] == value then
			return v, k
		end
	end
end

function Util.findAll(t, name, value)
	local rt = { }
	for _,v in pairs(t) do
		if v[name] == value then
			table.insert(rt, v)
		end
	end
	return rt
end

function Util.shallowCopy(t)
	if not t then error('Util.shallowCopy: invalid table', 2) end
	local t2 = { }
	for k,v in pairs(t) do
		t2[k] = v
	end
	return t2
end

function Util.deepCopy(t)
	if type(t) ~= 'table' then
		return t
	end
	--local mt = getmetatable(t)
	local res = {}
	for k,v in pairs(t) do
		if type(v) == 'table' then
			v = Util.deepCopy(v)
		end
		res[k] = v
	end
	--setmetatable(res,mt)
	return res
end

-- http://snippets.luacode.org/?p=snippets/Filter_a_table_in-place_119
function Util.filterInplace(t, predicate)
	local j = 1

	for i = 1,#t do
		local v = t[i]
		if predicate(v) then
			t[j] = v
			j = j + 1
		end
	end

	while t[j] ~= nil do
		t[j] = nil
		j = j + 1
	end

	return t
end

function Util.filter(it, f)
	local ot = { }
	for k,v in pairs(it) do
		if f(v) then
			ot[k] = v
		end
	end
	return ot
end

function Util.reduce(t, fn, acc)
	acc = acc or 0
	for _, v in pairs(t) do
		acc = fn(acc, v)
	end
	return acc
end

function Util.size(list)
	if type(list) == 'table' then
		local length = 0
		for _ in pairs(list) do
			length = length + 1
		end
		return length
	end
	return 0
end

local function isArray(value)
	-- dubious
	return type(value) == "table" and (value[1] or next(value) == nil)
end

function Util.removeByValue(t, e)
	for k,v in pairs(t) do
		if v == e then
			if isArray(t) then
				table.remove(t, k)
			else
				t[k] = nil
			end
			break
		end
	end
end

function Util.any(t, fn)
	for _,v in pairs(t) do
		if fn(v) then
			return true
		end
	end
end

function Util.every(t, fn)
	for _,v in pairs(t) do
		if not fn(v) then
			return false
		end
	end
	return true
end

function Util.each(list, func)
	for index, value in pairs(list) do
		func(value, index, list)
	end
end

function Util.rpairs(t)
	local tkeys = Util.keys(t)
	local i = #tkeys
	return function()
		local key = tkeys[i]
		local k,v = key, t[key]
		i = i - 1
		if v then
			return k, v
		end
	end
end

-- http://stackoverflow.com/questions/15706270/sort-a-table-in-lua
function Util.spairs(t, order)
	local keys = Util.keys(t)

	-- if order function given, sort by it by passing the table and keys a, b,
	-- otherwise just sort the keys
	if order then
		table.sort(keys, function(a,b) return order(t[a], t[b]) end)
	else
		table.sort(keys)
	end

	-- return the iterator function
	local i = 0
	return function()
		i = i + 1
		if keys[i] then
			return keys[i], t[keys[i]]
		end
	end
end

function Util.first(t, order)
	local keys = Util.keys(t)
	if order then
		table.sort(keys, function(a,b) return order(t[a], t[b]) end)
	else
		table.sort(keys)
	end
	return keys[1], t[keys[1]]
end

--[[ File functions ]]--
function Util.readFile(fname, flags)
	local f = fs.open(fname, flags or "r")
	if f then
		local t = f.readAll()
		f.close()
		return t
	end
end

function Util.backup(fname)
	local backup = fname .. '.bak'
	if backup then
		fs.delete(backup)
	end
	fs.copy(fname, backup)
end

function Util.writeFile(fname, data)
	if not fname or not data then error('Util.writeFile: invalid parameters', 2) end

	if fs.exists(fname) then
		local diff = #data - fs.getSize(fname)
		if diff > 0 then
			if fs.getFreeSpace(fs.getDir(fname)) < diff then
				error('Insufficient disk space for ' .. fname)
			end
		end
	end

	local file = io.open(fname, "w")
	if not file then
		error('Unable to open ' .. fname, 2)
	end
	file:write(data)
	file:close()
end

function Util.readLines(fname)
	local file = fs.open(fname, "r")
	if file then
		local t = {}
		local line = file.readLine()
		while line do
			table.insert(t, line)
			line = file.readLine()
		end
		file.close()
		return t
	end
end

function Util.writeLines(fname, lines)
	local file = fs.open(fname, 'w')
	if file then
		for _,line in ipairs(lines) do
			file.writeLine(line)
		end
		file.close()
		return true
	end
end

function Util.readTable(fname)
	local t = Util.readFile(fname)
	if t then
		return textutils.unserialize(t)
	end
end

function Util.writeTable(fname, data)
	Util.writeFile(fname, textutils.serialize(data))
end

function Util.loadTable(fname)
	local fc = Util.readFile(fname)
	if not fc then
		return false, 'Unable to read file'
	end
	local s, m = loadstring('return ' .. fc, fname)
	if s then
		s, m = pcall(s)
		if s then
			return m
		end
	end
	return s, m
end

--[[ loading and running functions ]] --
function Util.httpGet(url, headers, isBinary)
	local h, msg = http.get(url, headers, isBinary)
	if h then
		local contents = h.readAll()
		h.close()
		return contents
	end
	return h, msg
end

function Util.download(url, filename)
	local contents, msg = Util.httpGet(url)
	if not contents then
		error(_sformat('Failed to download %s\n%s', url, msg), 2)
	end

	if filename then
		Util.writeFile(filename, contents)
	end
	return contents
end

function Util.loadUrl(url, env)  -- loadfile equivalent
	local c, msg = Util.httpGet(url)
	if not c then
		return c, msg
	end
	return load(c, url, nil, env)
end

function Util.runUrl(env, url, ...)   -- os.run equivalent
	setmetatable(env, { __index = _G })
	local fn, m = Util.loadUrl(url, env)
	if fn then
		return pcall(fn, ...)
	end
	return fn, m
end

function Util.run(env, path, ...)
	if type(env) ~= 'table' then error('Util.run: env must be a table', 2) end
	setmetatable(env, { __index = _G })
	local fn, m = loadfile(path, env)
	if fn then
		return pcall(fn, ...)
	end
	return fn, m
end

function Util.runFunction(env, fn, ...)
	setfenv(fn, env)
	setmetatable(env, { __index = _G })
	return pcall(fn, ...)
end

--[[ String functions ]] --
function Util.toBytes(n)
	if not tonumber(n) then error('Util.toBytes: n must be a number', 2) end
	if n >= 1000000 or n <= -1000000 then
		return _sformat('%sM', math.floor(n/1000000 * 10) / 10)
	elseif n >= 10000 or n <= -10000 then
		return _sformat('%sK', math.floor(n/1000))
	elseif n >= 1000 or n <= -1000 then
		return _sformat('%sK', math.floor(n/1000 * 10) / 10)
	end
	return tostring(n)
end

function Util.insertString(str, istr, pos)
	return str:sub(1, pos - 1) .. istr .. str:sub(pos)
end

function Util.split(str, pattern)
	if not str or type(str) ~= 'string' then error('Util.split: Invalid parameters', 2) end
	pattern = pattern or "(.-)\n"
	local t = {}
	local function helper(line) table.insert(t, line) return "" end
	helper((str:gsub(pattern, helper)))
	return t
end

function Util.matches(str, pattern)
	pattern = pattern or '%S+'
	local t = { }
	for s in str:gmatch(pattern) do
		 table.insert(t, s)
	end
	return t
end

function Util.startsWith(s, match)
	return _ssub(s, 1, #match) == match
end

-- return a fixed length string using specified alignment
function Util.widthify(s, len, align)
	s = s or ''
	local slen = #s

	if slen > len then
		return _ssub(s, 1, len)

	elseif slen == len then
		return s

	elseif align == 'center' then
		local space = math.floor((len - slen) / 2)
		s = _srep(' ', space) .. s
		return s .. _srep(' ', len - #s)

	elseif align == 'right' then
		return _srep(' ', len - slen) .. s

	end

	return s .. _srep(' ', len - slen)
end

-- http://snippets.luacode.org/?p=snippets/trim_whitespace_from_string_76
function Util.trim(s)
	return s:find'^%s*$' and '' or s:match'^%s*(.*%S)'
end

-- trim whitespace from left end of string
function Util.triml(s)
	return s:match'^%s*(.*)'
end

-- trim whitespace from right end of string
function Util.trimr(s)
	return s:find'^%s*$' and '' or s:match'^(.*%S)'
end
-- end http://snippets.luacode.org/?p=snippets/trim_whitespace_from_string_76

-- word wrapping based on:
-- https://www.rosettacode.org/wiki/Word_wrap#Lua and
-- http://lua-users.org/wiki/StringRecipes
local function paragraphwrap(text, linewidth, res)
	linewidth = linewidth or 75
	local spaceleft = linewidth
	local line = { }

	for word in text:gmatch("%S+") do
		local len = #word + 1

		--if colorMode then
		--  word:gsub('()@([@%d])', function(pos, c) len = len - 2 end)
		--end

		if len > spaceleft then
			table.insert(res, table.concat(line, ' '))
			line = { word }
			spaceleft = linewidth - len - 1
		else
			table.insert(line, word)
			spaceleft = spaceleft - len
		end
	end

	table.insert(res, table.concat(line, ' '))
	return table.concat(res, '\n')
end
-- end word wrapping

function Util.wordWrap(str, limit)
	local longLines = Util.split(str)
	local lines = { }

	for _,line in ipairs(longLines) do
		paragraphwrap(line, limit, lines)
	end

	return lines
end

-- https://github.com/MightyPirates/OpenComputers
function Util.parse(...)
	local params = table.pack(...)
	local args = {}
	local options = {}
	local doneWithOptions = false
	for i = 1, params.n do
		local param = params[i]
		if not doneWithOptions and type(param) == "string" then
			if param == "--" then
				doneWithOptions = true -- stop processing options at `--`
			elseif param:sub(1, 2) == "--" then
				local key, value = param:match("%-%-(.-)=(.*)")
				if not key then
					key, value = param:sub(3), true
				end
				options[key] = value
			elseif param:sub(1, 1) == "-" and param ~= "-" then
				for j = 2, string.len(param) do
					options[string.sub(param, j, j)] = true
				end
			else
				table.insert(args, param)
			end
		else
			table.insert(args, param)
		end
	end
	return args, options
end

function Util.args(arg)
	local options, args = { }, { }

	local k = 1
	while k <= #arg do
		local v = arg[k]
		if _ssub(v, 1, 1) == '-' then
			local opt = _ssub(v, 2)
			options[opt] = arg[k + 1]
			k = k + 1
		else
			table.insert(args, v)
		end
		k = k + 1
	end
	return options, args
end

-- http://lua-users.org/wiki/AlternativeGetOpt
local function getopt( arg, options )
	local tab = {}
	for k, v in ipairs(arg) do
		if type(v) == 'string' then
			if _ssub( v, 1, 2) == "--" then
				local x = string.find( v, "=", 1, true )
				if x then tab[ _ssub( v, 3, x-1 ) ] = _ssub( v, x+1 )
				else      tab[ _ssub( v, 3 ) ] = true
				end
			elseif _ssub( v, 1, 1 ) == "-" then
				local y = 2
				local l = string.len(v)
				local jopt
				while ( y <= l ) do
					jopt = _ssub( v, y, y )
					if string.find( options, jopt, 1, true ) then
						if y < l then
							tab[ jopt ] = _ssub( v, y+1 )
							y = l
						else
							tab[ jopt ] = arg[ k + 1 ]
						end
					else
						tab[ jopt ] = true
					end
					y = y + 1
				end
			end
		end
	end
	return tab
end

function Util.showOptions(options)
	print('Arguments: ')
	for _, v in pairs(options) do
		print(_sformat('-%s  %s', v.arg, v.desc))
	end
end

function Util.getOptions(options, args, ignoreInvalid)
	local argLetters = ''
	for _,o in pairs(options) do
		if o.type ~= 'flag' then
			argLetters = argLetters .. o.arg
		end
	end
	local rawOptions = getopt(args, argLetters)

	for k,ro in pairs(rawOptions) do
		local found = false
		for _,o in pairs(options) do
			if o.arg == k then
				found = true
				if o.type == 'number' then
					o.value = tonumber(ro)
				elseif o.type == 'help' then
					Util.showOptions(options)
					return false
				else
					o.value = ro
				end
			end
		end
		if not found and not ignoreInvalid then
			print('Invalid argument')
			Util.showOptions(options)
			return false
		end
	end
	return true, Util.size(rawOptions)
end

-- https://www.lua.org/pil/9.3.html
function Util.permutation(tbl)
	local function permgen(a, n)
		if n == 0 then
			coroutine.yield(a)
		else
			for i=1,n do
				a[n], a[i] = a[i], a[n]
				permgen(a, n - 1)
				a[n], a[i] = a[i], a[n]
			end
		end
	end

	local co = coroutine.create(function() permgen(tbl, #tbl) end)
	return function()
		local _, res = coroutine.resume(co)
		return res
	end
end

return Util
