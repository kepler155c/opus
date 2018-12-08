_G.requireInjector(_ENV)

local Config   = require('config')
local Security = require('security')
local SHA1     = require('sha1')
local UI       = require('ui')
local Util     = require('util')

local fs         = _G.fs
local os         = _G.os
local settings   = _G.settings
local shell      = _ENV.shell
local turtle     = _G.turtle

UI:configure('System', ...)

local env = {
	path = shell.path(),
	aliases = shell.aliases(),
	lua_path = _ENV.LUA_PATH,
}
Config.load('shell', env)

local systemPage = UI.Page {
	tabs = UI.Tabs {
		pathTab = UI.Window {
			tabTitle = 'Path',
			entry = UI.TextEntry {
				x = 2, y = 2, ex = -2,
				limit = 256,
				value = shell.path(),
				shadowText = 'enter system path',
				accelerators = {
					enter = 'update_path',
				},
			},
			grid = UI.Grid {
				y = 4,
				disableHeader = true,
				columns = { { key = 'value' } },
				autospace = true,
			},
		},

		aliasTab = UI.Window {
			tabTitle = 'Alias',
			alias = UI.TextEntry {
				x = 2, y = 2, ex = -2,
				limit = 32,
				shadowText = 'Alias',
			},
			path = UI.TextEntry {
				y = 3, x = 2, ex = -2,
				limit = 256,
				shadowText = 'Program path',
				accelerators = {
					enter = 'new_alias',
				},
			},
			grid = UI.Grid {
				y = 5,
				sortColumn = 'alias',
				columns = {
					{ heading = 'Alias',   key = 'alias' },
					{ heading = 'Program', key = 'path'  },
				},
				accelerators = {
					delete = 'delete_alias',
				},
			},
		},

		passwordTab = UI.Window {
			tabTitle = 'Password',
			oldPass = UI.TextEntry {
				x = 2, y = 2, ex = -2,
				limit = 32,
				mask = true,
				shadowText = 'old password',
				inactive = not Security.getPassword(),
			},
			newPass = UI.TextEntry {
				y = 3, x = 2, ex = -2,
				limit = 32,
				mask = true,
				shadowText = 'new password',
				accelerators = {
					enter = 'new_password',
				},
			},
			button = UI.Button {
				x = 2, y = 5,
				text = 'Update',
				event = 'update_password',
			},
			info = UI.TextArea {
				x = 2, ex = -2,
				y = 7,
				inactive = true,
				value = 'Add a password to enable other computers to connect to this one.',
			}
		},

		infoTab = UI.Window {
			tabTitle = 'Info',
			labelText = UI.Text {
				x = 3, y = 2,
				value = 'Label'
			},
			label = UI.TextEntry {
				x = 9, y = 2, ex = -4,
				limit = 32,
				value = os.getComputerLabel(),
				accelerators = {
					enter = 'update_label',
				},
			},
			grid = UI.ScrollingGrid {
				y = 3,
				values = {
					{ name = '',  value = ''                  },
					{ name = 'CC version',  value = Util.getVersion()                  },
					{ name = 'Lua version', value = _VERSION                           },
					{ name = 'MC version',  value = Util.getMinecraftVersion()         },
					{ name = 'Disk free',   value = Util.toBytes(fs.getFreeSpace('/')) },
					{ name = 'Computer ID', value = tostring(os.getComputerID())       },
					{ name = 'Day',         value = tostring(os.day())                 },
				},
				inactive = true,
				columns = {
					{ key = 'name',  width = 12 },
					{ key = 'value' },
				},
			},
		},
	},
	notification = UI.Notification(),
	accelerators = {
		q = 'quit',
	},
}

if turtle then
	pcall(function()
		local Home = require('turtle.home')
-- TODO: dont rely on turtle.home
		local values = { }
		Config.load('gps', values.home and { values.home } or { })

		systemPage.tabs:add({
			gpsTab = UI.Window {
				tabTitle = 'GPS',
				labelText = UI.Text {
					x = 3, y = 2,
					value = 'On restart, return to this location'
				},
				grid = UI.Grid {
					x = 3, ex = -3, y = 4,
					height = 2,
					values = values,
					inactive = true,
					columns = {
						{ heading = 'x', key = 'x' },
						{ heading = 'y', key = 'y' },
						{ heading = 'z', key = 'z' },
					},
				},
				button1 = UI.Button {
					x = 3, y = 7,
					text = 'Set home',
					event = 'gps_set',
				},
				button2 = UI.Button {
					ex = -3, y = 7, width = 7,
					text = 'Clear',
					event = 'gps_clear',
				},
			},
		})
		function systemPage.tabs.gpsTab:eventHandler(event)
			if event.type == 'gps_set' then
				systemPage.notification:info('Determining location', 10)
				systemPage:sync()
				if Home.set() then
					Config.load('gps', values)
					self.grid:setValues(values.home and { values.home } or { })
					self.grid:draw()
					systemPage.notification:success('Location set')
				else
					systemPage.notification:error('Unable to determine location')
				end
				return true
			elseif event.type == 'gps_clear' then
				fs.delete('usr/config/gps')
				self.grid:setValues({ })
				self.grid:draw()
				return true
			end
		end
	end)
end

if settings then
	local values = { }
	for _,v in pairs(settings.getNames()) do
		local value = settings.get(v)
		if not value then
			value = false
		end
		table.insert(values, {
			name = v,
			value = value,
		})
	end

	systemPage.tabs:add({
		settingsTab = UI.Window {
			tabTitle = 'Settings',
			grid = UI.Grid {
				y = 1,
				values = values,
				autospace = true,
				sortColumn = 'name',
				columns = {
					{ heading = 'Setting',   key = 'name' },
					{ heading = 'Value', key = 'value'  },
				},
			},
		}
	})
	function systemPage.tabs.settingsTab:eventHandler(event)
		if event.type == 'grid_select' then
			if not event.selected.value or type(event.selected.value) == 'boolean' then
				event.selected.value = not event.selected.value
			end
			settings.set(event.selected.name, event.selected.value)
			settings.save('.settings')
			self.grid:draw()
			return true
		end
	end
end

function systemPage.tabs.pathTab.grid:draw()
	self.values = { }
	for _,v in ipairs(Util.split(env.path, '(.-):')) do
		table.insert(self.values, { value = v })
	end
	self:update()
	UI.Grid.draw(self)
end

function systemPage.tabs.pathTab:eventHandler(event)
	if event.type == 'update_path' then
		env.path = self.entry.value
		self.grid:setIndex(self.grid:getIndex())
		self.grid:draw()
		Config.update('shell', env)
		systemPage.notification:success('reboot to take effect')
		return true
	end
end

function systemPage.tabs.aliasTab.grid:draw()
	self.values = { }
	for k,v in pairs(env.aliases) do
		table.insert(self.values, { alias = k, path = v })
	end
	self:update()
	UI.Grid.draw(self)
end

function systemPage.tabs.aliasTab:eventHandler(event)
	if event.type == 'delete_alias' then
		env.aliases[self.grid:getSelected().alias] = nil
		self.grid:setIndex(self.grid:getIndex())
		self.grid:draw()
		Config.update('shell', env)
		systemPage.notification:success('reboot to take effect')
		return true

	elseif event.type == 'new_alias' then
		env.aliases[self.alias.value] = self.path.value
		self.alias:reset()
		self.path:reset()
		self:draw()
		self:setFocus(self.alias)
		Config.update('shell', env)
		systemPage.notification:success('reboot to take effect')
		return true
	end
end

function systemPage.tabs.passwordTab:eventHandler(event)
	if event.type == 'update_password' then
		if #self.newPass.value == 0 then
			systemPage.notification:error('Invalid password')
		elseif Security.getPassword() and not Security.verifyPassword(SHA1.sha1(self.oldPass.value)) then
			systemPage.notification:error('Passwords do not match')
		else
			Security.updatePassword(SHA1.sha1(self.newPass.value))
			self.oldPass.inactive = false
			systemPage.notification:success('Password updated')
		end

		return true
	end
end

function systemPage.tabs.infoTab:eventHandler(event)
	if event.type == 'update_label' then
		os.setComputerLabel(self.label.value)
		systemPage.notification:success('Label updated')
		return true
	end
end

function systemPage:eventHandler(event)
	if event.type == 'quit' then
		UI:exitPullEvents()
	elseif event.type == 'tab_activate' then
		event.activated:focusFirst()
	else
		return UI.Page.eventHandler(self, event)
	end
	return true
end

UI:setPage(systemPage)
UI:pullEvents()
