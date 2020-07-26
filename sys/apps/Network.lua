local Config = require('opus.config')
local Event  = require('opus.event')
local Socket = require('opus.socket')
local UI     = require('opus.ui')
local Util   = require('opus.util')

local device     = _G.device
local network    = _G.network
local shell      = _ENV.shell

UI:configure('Network', ...)

local gridColumns = {
	{ heading = 'Label',  key = 'label'    },
	{ heading = 'Dist',   key = 'distance', align = 'right' },
	{ heading = 'Status', key = 'status'   },
}

local config = Config.load('network', { })

if UI.term.width >= 30 then
	table.insert(gridColumns, { heading = 'Fuel',   key = 'fuel', width = 5, align = 'right' })
end
if UI.term.width >= 40 then
	table.insert(gridColumns, { heading = 'Uptime', key = 'uptime', align = 'right' })
end

local page = UI.Page {
	menuBar = UI.MenuBar {
		buttons = {
			{ text = 'Connect', dropdown = {
				{ text = 'Telnet      t', event = 'telnet' },
				{ text = 'VNC         v', event = 'vnc'    },
				{ spacer = true },
				{ text = 'Reboot      r', event = 'reboot' },
			} },
			{ text = 'Trust', dropdown = {
				{ text = 'Establish', event = 'trust'   },
			} },
			{
				text = '\187',
				x = -3,
				dropdown = {
					{ text = 'Port Status', event = 'ports', modem = true },
					{ spacer = true },
					{ text = 'Help', event = 'help', noCheck = true },
				},
			},
		},
	},
	grid = UI.ScrollingGrid {
		y = 2,
		values = network,
		columns = gridColumns,
		sortColumn = 'label',
		autospace = true,
		getRowTextColor = function(self, row, selected)
			if not row.active then
				return 'lightGray'
			end
			return UI.Grid.getRowTextColor(self, row, selected)
		end,
		getDisplayValues = function(_, row)
			row = Util.shallowCopy(row)
			if row.uptime then
				if row.uptime < 60 then
					row.uptime = string.format("%ds", math.floor(row.uptime))
				elseif row.uptime < 3600 then
					row.uptime = string.format("%sm", math.floor(row.uptime / 60))
				else
					row.uptime = string.format("%sh", math.floor(row.uptime / 3600))
				end
			end
			if row.fuel then
				row.fuel = row.fuel > 0 and Util.toBytes(row.fuel) or ''
			end
			if row.distance then
				row.distance = Util.toBytes(Util.round(row.distance, 1))
			end
			return row
		end,
	},
	ports = UI.SlideOut {
		titleBar = UI.TitleBar {
			title = 'Ports',
			event = 'ports_hide',
		},
		grid = UI.ScrollingGrid {
			y = 2,
			columns = {
				{ heading = 'Port',       key = 'port'       },
				{ heading = 'State',      key = 'state'      },
				{ heading = 'Connection', key = 'connection' },
			},
			sortColumn = 'port',
			autospace = true,
		},
		eventHandler = function(self, event)
			if event.type == 'grid_select' then
				shell.openForegroundTab('Sniff ' .. event.selected.port)
			end
			return UI.SlideOut.eventHandler(self, event)
		end,
	},
	notification = UI.Notification { },
	accelerators = {
		t = 'telnet',
		v = 'vnc',
		r = 'reboot',
		[ 'control-q' ] = 'quit',
		c = 'clear',
	},
}

local function sendCommand(host, command)
	if not device.wireless_modem then
		page.notification:error('Wireless modem not present')
		return
	end

	page.notification:info('Connecting')
	page:sync()

	local socket = Socket.connect(host, 161)
	if socket then
		socket:write({ type = command })
		socket:close()
		page.notification:success('Command sent')
	else
		page.notification:error('Failed to connect')
	end
end

function page.ports.grid:update()
	local transport = network:getTransport()

	local function findConnection(port)
		if transport then
			for _,socket in pairs(transport.sockets) do
				if socket.sport == port then
					return socket
				end
			end
		end
	end

	local connections = { }

	pcall(function() -- guard against modem removal
		if device.wireless_modem then
			for i = 0, 65535 do
				if device.wireless_modem.isOpen(i) then
					local conn = {
						port = i
					}
					local socket = findConnection(i)
					if socket then
						conn.state = 'CONNECTED'
						local host = socket.dhost
						if network[host] then
							host = network[host].label
						end
						conn.connection = host .. ':' .. socket.dport
					else
						conn.state = 'LISTEN'
					end
					table.insert(connections, conn)
				end
			end
		end
	end)

	self.values = connections
	UI.Grid.update(self)
end

function page:eventHandler(event)
	local t = self.grid:getSelected()
	if t then
		if event.type == 'telnet' then
			shell.openForegroundTab('telnet ' .. t.id)

		elseif event.type == 'vnc' then
			shell.openForegroundTab('vnc.lua ' .. t.id)
			--[[
			os.queueEvent('overview_shortcut', {
				title = t.label,
				category = "VNC",
				icon = "\010\030 \009\009\031e\\\031   \031e/\031dn\010\030 \009\009 \031e\\/\031  \031bc",
				run = "vnc.lua " .. t.id,
			})
			--]]

		elseif event.type == 'clear' then
			Util.clear(network)
			page.grid:update()
			page.grid:draw()

		elseif event.type == 'trust' then
			shell.openForegroundTab('trust ' .. t.id)

		elseif event.type == 'reboot' then
			sendCommand(t.id, 'reboot')

		elseif event.type == 'shutdown' then
			sendCommand(t.id, 'shutdown')
		end
	end

	if event.type == 'help' then
		shell.switchTab(shell.openTab('Help Networking'))

	elseif event.type == 'ports' then
		self.ports.grid:update()
		self.ports:show()

		self.portsHandler = Event.onInterval(3, function()
			self.ports.grid:update()
			self.ports.grid:draw()
			self:sync()
		end)

	elseif event.type == 'ports_hide' then
		Event.off(self.portsHandler)
		self.ports:hide()

	elseif event.type == 'show_trusted' then
		config.showTrusted = true
		Config.update('network', config)

	elseif event.type == 'quit' then
		UI:quit()
	end
	UI.Page.eventHandler(self, event)
end

function page.menuBar:getActive(menuItem)
	local t = page.grid:getSelected()
	if menuItem.modem then
		return not not device.wireless_modem
	end
	return menuItem.noCheck or not not t
end

Event.onInterval(1, function()
	page.grid:update()
	page.grid:draw()
	page:sync()
end)

Event.on('device_attach', function(_, deviceName)
	if deviceName == 'wireless_modem' then
		page.notification:success('Modem connected')
		page:sync()
	end
end)

Event.on('device_detach', function(_, deviceName)
	if deviceName == 'wireless_modem' then
		page.notification:error('Wireless modem not attached')
		page:sync()
	end
end)

if not device.wireless_modem then
	page.notification:error('Wireless modem not attached')
end

UI:setPage(page)
UI:start()
