local Logger = {
	fn = function() end,
	filteredEvents = { },
}

function Logger.setLogger(fn)
	Logger.fn = fn
end

function Logger.disable()
	Logger.setLogger(function() end)
end

function Logger.setDaemonLogging()
	Logger.setLogger(function (text)
		os.queueEvent('log', { text = text })
	end)
end

function Logger.setMonitorLogging()
	local debugMon = device.monitor

	if not debugMon then
		debugMon.setTextScale(.5)
		debugMon.clear()
		debugMon.setCursorPos(1, 1)
		Logger.setLogger(function(text)
			debugMon.write(text)
			debugMon.scroll(-1)
			debugMon.setCursorPos(1, 1)
		end)
	end
end

function Logger.setScreenLogging()
	Logger.setLogger(function(text)
		local x, y = term.getCursorPos()
		if x ~= 1 then
			local sx, sy = term.getSize()
			term.setCursorPos(1, sy)
			--term.scroll(1)
		end
		print(text)
	end)
end

function Logger.setWirelessLogging()
	if device.wireless_modem then
		Logger.filter('modem_message')
		Logger.filter('modem_receive')
		Logger.filter('rednet_message')
		Logger.setLogger(function(text)
			device.wireless_modem.transmit(59998, os.getComputerID(), {
				type = 'log', contents = text
			})
		end)
		Logger.debug('Logging enabled')
		return true
	end
end

function Logger.setFileLogging(fileName)
	fs.delete(fileName)
	Logger.setLogger(function (text)
		local logFile

		local mode = 'w'
		if fs.exists(fileName) then
			mode = 'a'
		end
		local file = io.open(fileName, mode)
		if file then
			file:write(text)
			file:write('\n')
			file:close()
		end
	end)
end

function Logger.log(category, value, ...)
	if Logger.filteredEvents[category] then
		return
	end

	if type(value) == 'table' then
		local str
		for k,v in pairs(value) do
			if not str then
				str = '{ '
			else
				str = str .. ', '
			end
			str = str .. k .. '=' .. tostring(v)
		end
		if str then
			value = str .. ' }'
		else
			value = '{ }'
		end
	elseif type(value) == 'string' then
		local args = { ... }
		if #args > 0 then
			value = string.format(value, unpack(args))
		end
	else
		value = tostring(value)
	end
	Logger.fn(category .. ': ' .. value)
end

function Logger.debug(value, ...)
	Logger.log('debug', value, ...)
end

function Logger.logNestedTable(t, indent)
	for _,v in ipairs(t) do
		if type(v) == 'table' then
			log('table')
			logNestedTable(v) --, indent+1)
		else
			log(v)
		end
	end
end

function Logger.filter( ...)
	local events = { ... }
	for _,event in pairs(events) do
		Logger.filteredEvents[event] = true
	end
end

return Logger