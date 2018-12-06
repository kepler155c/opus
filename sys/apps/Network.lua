_G.requireInjector(_ENV)

local Config = require('config')
local Event  = require('event')
local Socket = require('socket')
local UI     = require('ui')
local Util   = require('util')

local colors     = _G.colors
local device     = _G.device
local multishell = _ENV.multishell
local network    = _G.network
local os         = _G.os
local shell      = _ENV.shell

UI:configure('Network', ...)

local gridColumns = {
	{ heading = 'Label',  key = 'label'    },
	{ heading = 'Dist',   key = 'distance' },
	{ heading = 'Status', key = 'status'   },
}

local trusted = Util.readTable('usr/.known_hosts')
local config = Config.load('network', { })

if UI.term.width >= 30 then
	table.insert(gridColumns, { heading = 'Fuel',   key = 'fuel', width = 5 })
	table.insert(gridColumns, { heading = 'Uptime', key = 'uptime' })
end

local page = UI.Page {
	menuBar = UI.MenuBar {
		buttons = {
			{ text = 'Connect', dropdown = {
				{ text = 'Telnet      t', event = 'telnet' },
				{ text = 'VNC         v', event = 'vnc'    },
				UI.MenuBar.spacer,
				{ text = 'Reboot      r', event = 'reboot' },
			} },
			--{ text = 'Chat', event = 'chat' },
			{ text = 'Trust', dropdown = {
				{ text = 'Establish', event = 'trust'   },
				{ text = 'Remove',    event = 'untrust' },
			} },
			{ text = 'Help', event = 'help', noCheck = true },
			{
				text = '\206',
				x = -3,
				dropdown = {
					{ text = 'Show all', event = 'show_all', noCheck = true },
					UI.MenuBar.spacer,
					{ text = 'Show trusted', event = 'show_trusted', noCheck = true },
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
	},
	notification = UI.Notification { },
	accelerators = {
		t = 'telnet',
		v = 'vnc',
		r = 'reboot',
		q = 'quit',
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

function page:eventHandler(event)
	local t = self.grid:getSelected()
	if t then
		if event.type == 'telnet' then
			multishell.openTab({
				path = 'sys/apps/telnet.lua',
				focused = true,
				args = { t.id },
				title = t.label,
			})
		elseif event.type == 'vnc' then
			multishell.openTab({
				path = 'sys/apps/vnc.lua',
				focused = true,
				args = { t.id },
				title = t.label,
			})
		elseif event.type == 'clear' then
			Util.clear(network)
			page.grid:update()
			page.grid:draw()

		elseif event.type == 'trust' then
			shell.openForegroundTab('trust ' .. t.id)

		elseif event.type == 'untrust' then
			local trustList = Util.readTable('usr/.known_hosts') or { }
			trustList[t.id] = nil
			Util.writeTable('usr/.known_hosts', trustList)

		elseif event.type == 'chat' then
			multishell.openTab({
				path    = 'sys/apps/shell',
				args    = { 'chat join opusChat-' .. t.id .. ' guest-' .. os.getComputerID() },
				title   = 'Chatroom',
				focused = true,
			})
		elseif event.type == 'reboot' then
			sendCommand(t.id, 'reboot')

		elseif event.type == 'shutdown' then
			sendCommand(t.id, 'shutdown')
		end
	end
	if event.type == 'help' then
		UI:setPage(UI.Dialog {
			title = 'Network Help',
			height = 10,
			backgroundColor = colors.white,
			text = UI.TextArea {
				x = 2, y = 2,
				backgroundColor = colors.white,
				value = [[
In order to connect to another computer:

	1. The target computer must have a password set (run 'password' from the shell prompt).
	2. From this computer, click trust and enter the password for that computer.

This only needs to be done once.
				]],
			},
			accelerators = {
				q = 'cancel',
			}
		})

	elseif event.type == 'show_all' then
		config.showTrusted = false
		self.grid:setValues(network)
		Config.update('network', config)

	elseif event.type == 'show_trusted' then
		config.showTrusted = true
		Config.update('network', config)

	elseif event.type == 'quit' then
		Event.exitPullEvents()
	end
	UI.Page.eventHandler(self, event)
end

function page.menuBar:getActive(menuItem)
	local t = page.grid:getSelected()
	if menuItem.event == 'untrust' then
		local trustList = Util.readTable('usr/.known_hosts') or { }
		return t and trustList[t.id]
	end
	return menuItem.noCheck or not not t
end

function page.grid:getRowTextColor(row, selected)
	if not row.active then
		return colors.orange
	end
	return UI.Grid.getRowTextColor(self, row, selected)
end

function page.grid:getDisplayValues(row)
	row = Util.shallowCopy(row)
	if row.uptime then
		if row.uptime < 60 then
			row.uptime = string.format("%ds", math.floor(row.uptime))
		else
			row.uptime = string.format("%sm", math.floor(row.uptime/6)/10)
		end
	end
	if row.fuel then
		row.fuel = Util.toBytes(row.fuel)
	end
	if row.distance then
		row.distance = Util.round(row.distance, 1)
	end
	return row
end

Event.onInterval(1, function()
	local t = { }
	if config.showTrusted then
		for k,v in pairs(network) do
			if trusted[k] then
				t[k] = v
			end
		end
		page.grid:setValues(t)
	else
		page.grid:update()
	end
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
UI:pullEvents()
