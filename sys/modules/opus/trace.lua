-- stack trace by SquidDev (MIT License)
-- https://raw.githubusercontent.com/SquidDev-CC/mbs/master/lib/stack_trace.lua

local type = type
local debug_traceback = type(debug) == "table" and type(debug.traceback) == "function" and debug.traceback

local function traceback(x)
	-- Attempt to detect error() and error("xyz", 0).
	-- This probably means they're erroring the program intentionally and so we
	-- shouldn't display anything.
	if x == nil or (type(x) == "string" and not x:find(":%d+:")) then
		return x
	end

	if debug_traceback then
		-- The parens are important, as they prevent a tail call occuring, meaning
		-- the stack level is preserved. This ensures the code behaves identically
		-- on LuaJ and PUC Lua.
		return (debug_traceback(tostring(x), 2))
	else
		local level = 3
		local out = { tostring(x), "stack traceback:" }
		while true do
			local _, msg = pcall(error, "", level)
			if msg == "" then break end

			out[#out + 1] = "  " .. msg
			level = level + 1
		end

		return table.concat(out, "\n")
	end
end

local function trim_traceback(target)
	local t = { }
	local filters = {
		"%[C%]: in function 'xpcall'",
		"(...tail calls...)",
		"xpcall: $",
		"trace.lua:%d+:",
	}

	local function matchesFilter(line)
		for _, filter in pairs(filters) do
			if line:match(filter) then
				return true
			end
		end
	end

	for line in target:gmatch("([^\n]*)\n?") do
		if not matchesFilter(line) then
			table.insert(t, line)
		end
	end

	return t
end

return function (fn, ...)
	-- xpcall in Lua 5.1 does not accept parameters
	-- which is not ideal
	local args = { ... }
	local res = table.pack(xpcall(function()
		return fn(table.unpack(args))
	end, traceback))

	local ok, err = res[1], res[2]

	if not ok and err ~= nil then
		local trace = trim_traceback(err)

		err = { }
		while true do
			local line = table.remove(trace, 1)
			if not line or line == 'stack traceback:' then
				break
			end
			table.insert(err, line)
		end
		err = table.concat(err, '\n')

		_G._syslog('\n' .. err .. '\n' .. 'stack traceback:')
		for _, v in ipairs(trace) do
			if v ~= 'stack traceback:' then
				_G._syslog(v:gsub("in function", "in"))
			end
		end

		return ok, err
	end

	return table.unpack(res, 1, res.n)
end
