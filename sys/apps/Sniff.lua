local UI    = require('opus.ui')
local Event = require('opus.event')
local Util  = require('opus.util')

local colors     = _G.colors
local device     = _G.device
local textutils  = _G.textutils
local multishell = _ENV.multishell

local gridColumns = {}
table.insert(gridColumns, { heading = '#',  key = 'id', width = 5, align = 'right' })
table.insert(gridColumns, { heading = 'Port', key = 'portid', width = 5, align = 'right' })
table.insert(gridColumns, { heading = 'Reply', key = 'replyid', width = 5, align = 'right' })
if UI.term.width > 50 then
	table.insert(gridColumns, { heading = 'Dist', key = 'distance', width = 6, align = 'right' })
end
table.insert(gridColumns, { heading = 'Msg', key = 'packetStr' })

local page = UI.Page {
	paused = false,
	index = 1,
	notification = UI.Notification { },
	accelerators = { ['control-q'] = 'quit' },

	menuBar = UI.MenuBar {
		buttons = {
			{ text = 'Pause', event = 'pause_click', name = 'pauseButton' },
			{ text = 'Clear', event = 'clear_click' },
			{ text = 'Config', event = 'config_click' },
		},
	},

	packetGrid = UI.ScrollingGrid {
		y = 2,
		maxPacket = 300,
		inverseSort = true,
		sortColumn = 'id',
		columns = gridColumns,
		accelerators = { ['space'] = 'pause_click' },
	},

	configSlide = UI.SlideOut {
		y = -11,
		titleBar = UI.TitleBar { title = 'Sniffer Config', event = 'config_close', backgroundColor = colors.black },
		accelerators = { ['backspace'] = 'config_close' },
		configTabs = UI.Tabs {
			y = 2,
			filterTab = UI.Tab {
				title = 'Filter',
				noFill = true,
				filterGridText = UI.Text {
					x = 2, y = 2,
					value = 'ID filter',
				},
				filterGrid = UI.ScrollingGrid {
					x = 2, y = 3,
					width = 10, height = 4,
					disableHeader = true,
					columns = {
						{ key = 'id', width = 5 },
					},
				},
				filterEntry = UI.TextEntry {
					x = 2, y = 8,
					width = 7,
					shadowText = 'ID',
					limit = 5,
					accelerators = { enter = 'filter_add' },
				},
				filterAdd = UI.Button {
					x = 10, y = 8,
					text = '+',
					event = 'filter_add',
				},
				filterAllCheck = UI.Checkbox {
					x = 14, y = 8,
					value = false,
				},
				filterAddText = UI.Text {
					x = 18, y = 8,
					value = "Use ID filter",
				},
				rangeText = UI.Text {
					x = 15, y = 2,
					value = "Distance filter",
				},
				rangeEntry = UI.TextEntry {
					x = 15, y = 3,
					width = 10,
					limit = 8,
					shadowText = 'Range',
					transform = 'number',
				},
			},
			modemTab = UI.Tab {
				title = 'Modem',
				channelGrid = UI.ScrollingGrid {
					x = 2, y = 2,
					width = 12, height = 5,
					autospace = true,
					columns = {{ heading = 'Open Ports', key = 'port' }},
				},
				modemGrid = UI.ScrollingGrid {
					x = 15, y = 2,
					ex = -2, height = 5,
					autospace = true,
					columns = {
						{ heading = 'Side', key = 'side' },
						{ heading = 'Type', key = 'type' },
					},
				},
				channelEntry = UI.TextEntry {
					x = 2, y = 8,
					width = 7,
					shadowText = 'ID',
					limit = 5,
					accelerators = { enter = 'channel_add' },
				},
				channelAdd = UI.Button {
					x = 10, y = 8,
					text = '+',
					event = 'channel_add',
				},
			},
		},
	},

	packetSlide = UI.SlideOut {
		titleBar = UI.TitleBar {
			title = 'Packet Information',
			event = 'packet_close',
		},
		accelerators = {
			['backspace'] = 'packet_close',
			['left'] = 'prev_packet',
			['right'] = 'next_packet',
		},
		packetMeta = UI.Grid {
			x = 2, y = 2,
			ex = 23, height = 4,
			inactive = true,
			columns = {
				{ key = 'text' },
				{ key = 'value', align = 'right', textColor = colors.yellow },
			},
			values = {
				port = { text = 'Port' },
				reply = { text = 'Reply' },
				dist = { text = 'Distance' },
			}
		},
		packetButton = UI.Button {
			x = 25, y = 5,
			text = 'Open in Lua',
			event = 'packet_lua',
		},
		packetData = UI.TextArea {
			y = 7, ey = -1,
			backgroundColor = colors.black,
		},
	},
}

local filterConfig = page.configSlide.configTabs.filterTab
local modemConfig = page.configSlide.configTabs.modemTab

function filterConfig:eventHandler(event)
	if event.type == 'filter_add' then
		local id = tonumber(self.filterEntry.value)
		if id then self.filterGrid.values[id] = { id = id }
			self.filterGrid:update()
			self.filterEntry:reset()
			self:draw()
		end

	elseif event.type == 'grid_select' then
		self.filterGrid.values[event.selected.id] = nil
		self.filterGrid:update()
		self.filterGrid:draw()

	else return UI.Tab.eventHandler(self, event)
	end
	return true
end

function modemConfig:loadChannel()
	for chan = 0, 65535 do
		self.currentModem.openChannels[chan] = self.currentModem.device.isOpen(chan) and { port = chan } or nil
	end
	self.channelGrid:setValues(self.currentModem.openChannels)
	self.currentModem.loaded = true
end

function modemConfig:enable()
	if not self.currentModem.loaded then
		self:loadChannel()
	end

	UI.Tab.enable(self)
end

function modemConfig:eventHandler(event)
	if event.type == 'channel_add' then
		local id = tonumber(modemConfig.channelEntry.value)
		if id then
			self.currentModem.openChannels[id] = { port = id }
			self.currentModem.device.open(id)
			self.channelGrid:setValues(self.currentModem.openChannels)
			self.channelGrid:update()
			self.channelEntry:reset()
			self:draw()
		end

	elseif event.type == 'grid_select' then
		if event.element == self.channelGrid then
			self.currentModem.openChannels[event.selected.port] = nil
			self.currentModem.device.close(event.selected.port)
			self.channelGrid:setValues(self.currentModem.openChannels)
			page.configSlide.configTabs.modemTab.channelGrid:update()
			page.configSlide.configTabs.modemTab.channelGrid:draw()

		elseif event.element == self.modemGrid then
			self.currentModem = event.selected
			page.notification:info("Loading channel list")
			page:sync()
			modemConfig:loadChannel()
			page.notification:success("Now using modem on " .. self.currentModem.side)
			self.channelGrid:draw()
		end

	else return UI.Tab.eventHandler(self, event)
	end
	return true
end

function page.packetSlide:setPacket(packet)
	self.currentPacket = packet
	local p, res = pcall(textutils.serialize, page.packetSlide.currentPacket.message)
	self.packetData.textColor = p and colors.white or colors.red
	self.packetData:setText(res)
	self.packetMeta.values.port.value = page.packetSlide.currentPacket.portid
	self.packetMeta.values.reply.value = page.packetSlide.currentPacket.replyid
	self.packetMeta.values.dist.value = Util.round(page.packetSlide.currentPacket.distance, 2)
end

function page.packetSlide:show(packet)
	self:setPacket(packet)

	UI.SlideOut.show(self)
end

function page.packetSlide:eventHandler(event)
	if event.type == 'packet_close' then
		self:hide()
		page:setFocus(page.packetGrid)

	elseif event.type == 'packet_lua' then
		multishell.openTab(_ENV, { path = 'sys/apps/Lua.lua', args = { self.currentPacket.message }, focused = true })

	elseif event.type == 'prev_packet' then
		local c = self.currentPacket
		local n = page.packetGrid.values[c.id - 1]
		if n then
			self:setPacket(n)
			self:draw()
		end

	elseif event.type == 'next_packet' then
		local c = self.currentPacket
		local n = page.packetGrid.values[c.id + 1]
		if n then
			self:setPacket(n)
			self:draw()
		end

	else return UI.SlideOut.eventHandler(self, event)
	end
	return true
end

function page.packetGrid:getDisplayValues(row)
	row = Util.shallowCopy(row)
	row.distance = Util.toBytes(Util.round(row.distance), 2)
	return row
end

function page.packetGrid:addPacket(packet)
	if not page.paused and (packet.distance <= (filterConfig.rangeEntry.value or math.huge)) and (not filterConfig.filterAllCheck.value or filterConfig.filterGrid.values[packet.portid]) then
		page.index = page.index + 1
		local _, res = pcall(textutils.serialize, packet.message)
		packet.packetStr = res:gsub("\n%s*", "")
		table.insert(self.values, packet)
	end
	if #self.values > self.maxPacket then
		local t = { }
		for i = 10, #self.values do
			t[i - 9] = self.values[i]
		end
		self:setValues(t)
	end

	self:update()
	self:draw()
	page:sync()
end

function page:enable()
	modemConfig.modems = {}
	Util.each(_G.device, function(dev)
		if dev.type == "modem" then
			modemConfig.modems[dev.side] = {
				type = dev.isWireless() and 'Wireless' or 'Wired',
				side = dev.side,
				openChannels = { },
				device = dev,
				loaded = false
			}
		end
	end)
	modemConfig.currentModem = device.wireless_modem and
		modemConfig.modems[device.wireless_modem.side] or
		device.wired_modem and
		modemConfig.modems[device.wired_modem.side] or
		nil

	modemConfig.modemGrid.values = modemConfig.modems
	modemConfig.modemGrid:update()
	modemConfig.modemGrid:setSelected(modemConfig.currentModem)

	UI.Page.enable(self)
end


function page:eventHandler(event)
	if event.type == 'pause_click' then
		self.paused = not self.paused
		self.menuBar.pauseButton.text = self.paused and 'Resume' or 'Pause'
		self.notification:success(self.paused and 'Paused' or 'Resumed', 2)
		self.menuBar:draw()

	elseif event.type == 'clear_click' then
		self.packetGrid:setValues({ })
		self.notification:success('Cleared', 2)
		self.packetGrid:draw()

	elseif event.type == 'config_click' then
		self.configSlide:show()
		self:setFocus(filterConfig.filterEntry)

	elseif event.type == 'config_close' then
		self.configSlide:hide()
		self:setFocus(self.packetGrid)

	elseif event.type == 'grid_select' then
		self.packetSlide:show(event.selected)

	elseif event.type == 'quit' then
		UI:quit()

	else return UI.Page.eventHandler(self, event)
	end
	return true
end

Event.on('modem_message', function(_, side, chan, reply, msg, dist)
	if modemConfig.currentModem.side == side then
		page.packetGrid:addPacket({
			id = page.index,
			portid = chan,
			replyid = reply,
			message = msg,
			distance = dist or -1,
		})
	end
end)

local args = Util.parse(...)
if args[1] then
	local id = tonumber(args[1])
	if id then
		filterConfig.filterGrid.values[id] = { id = id }
		filterConfig.filterAllCheck:setValue(true)
		filterConfig.filterGrid:update()
	end
end

UI:setPage(page)
UI:start()
