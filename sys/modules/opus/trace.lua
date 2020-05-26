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

	if x and x:match(':%d+: 0$') then
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

local function trim_traceback(stack)
	local trace = { }
	local filters = {
		"%[C%]: in function 'xpcall'",
		"(...tail calls...)",
		"xpcall: $",
		"trace.lua:%d+:",
		"stack traceback:",
	}

	for line in stack:gmatch("([^\n]*)\n?") do table.insert(trace, line) end

	local err = { }
	while true do
		local line = table.remove(trace, 1)
		if not line or line == 'stack traceback:' then
			break
		end
		table.insert(err, line)
	end
	err = table.concat(err, '\n')

	local function matchesFilter(line)
		for _, filter in pairs(filters) do
			if line:match(filter) then
				return true
			end
		end
	end

	local t = { }
	for _, line in pairs(trace) do
		if not matchesFilter(line) then
			line = line:gsub("in function", "in"):gsub('%w+/', '')
			table.insert(t, line)
		end
	end

	return err, t
end

return function (fn, ...)
	local args = { ... }
	local res = table.pack(xpcall(function()
		return fn(table.unpack(args))
	end, traceback))

	if not res[1] and res[2] ~= nil then
		local err, trace = trim_traceback(res[2])

		if err:match(':%d+: 0$') then
			return true
		end

		if #trace > 0 then
			_G._syslog('\n' .. err .. '\n' .. 'stack traceback:')
			for _, v in ipairs(trace) do
				_G._syslog(v)
			end
		end

		return res[1], err, trace
	end

	return table.unpack(res, 1, res.n)
end
