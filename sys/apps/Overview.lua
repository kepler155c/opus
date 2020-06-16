local Array    = require('opus.array')
local class    = require('opus.class')
local Config   = require('opus.config')
local Event    = require('opus.event')
local NFT      = require('opus.nft')
local Packages = require('opus.packages')
local SHA      = require('opus.crypto.sha2')
local Tween    = require('opus.ui.tween')
local UI       = require('opus.ui')
local Util     = require('opus.util')

local device     = _G.device
local fs         = _G.fs
local os         = _G.os
local pocket     = _G.pocket
local shell      = _ENV.shell
local term       = _G.term
local turtle     = _G.turtle

--[[
	turtle: 39x13
	computer: 51x19
	pocket: 26x20
]]

if not _ENV.multishell then
	error('multishell is required')
end

local REGISTRY_DIR = 'usr/.registry'

-- iconExt:gsub('.', function(b) return '\\' .. b:byte() end)
local DEFAULT_ICON = NFT.parse('\30\55\31\48\136\140\140\140\132\
\30\48\31\55\149\31\48\128\128\128\30\55\149\
\30\55\31\48\138\143\143\143\133')
local TRANS_ICON = NFT.parse('\0302\0312\32\32\32\32\32\
\0302\0312\32\32\32\32\32\
\0302\0312\32\32\32\32\32')

-- overview
local uid = _ENV.multishell.getCurrent()
device.keyboard.addHotkey('control-o', function()
	_ENV.multishell.setFocus(uid)
end)

UI:configure('Overview', ...)

local config = {
	Recent = { },
	currentCategory = 'Apps',
}
Config.load('Overview', config)

local extSupport = Util.getVersion() >= 1.76

local applications = { }
local buttons = { }

local sx, sy = term.current().getSize()
local maxRecent = math.ceil(sx * sy / 62)

local function ellipsis(s, len)
	if #s > len then
		s = s:sub(1, len - 2) .. '..'
	end
	return s
end

local function parseIcon(iconText)
	local icon

	local s, m = pcall(function()
		icon = NFT.parse(iconText)
		if icon then
			if icon.height > 3 or icon.width > 8 then
				error('Must be an NFT image - 3 rows, 8 cols max')
			end
			NFT.transparency(icon)
		end
		return icon
	end)

	if s then
		return icon
	end

	return s, m
end

local page = UI.Page {
	container = UI.Viewport {
		x = 9, y = 1,
	},
	tabBar = UI.TabBar {
		ey = -2,
		width = 8,
		selectedBackgroundColor = 'primary',
		backgroundColor = 'tertiary',
		unselectedTextColor = 'lightGray',
		layout = function(self)
			self.height = nil
			UI.TabBar.layout(self)
		end,
	},
	tray = UI.Window {
		y = -1, width = 8,
		backgroundColor = 'tertiary',
		newApp = UI.FlatButton {
			x = 2,
			text = '+', event = 'new',
		},
		mode = UI.FlatButton {
			x = 4,
			text = '=', event = 'display_mode',
		},
		help = UI.FlatButton {
			x = 6,
			text = '?', event = 'help',
		},
	},
	editor = UI.SlideOut {
		y = -12, height = 12,
		titleBar = UI.TitleBar {
			title = 'Edit Application',
			event = 'slide_hide',
		},
		form = UI.Form {
			y = 2, ey = -2,
			[1] = UI.TextEntry {
				formLabel = 'Title', formKey = 'title', limit = 11, width = 13, help = 'Application title',
				required = true,
			},
			[2] = UI.TextEntry {
				formLabel = 'Run', formKey = 'run', limit = 100, help = 'Full path to application',
				required = true,
			},
			[3] = UI.TextEntry {
				formLabel = 'Category', formKey = 'category', limit = 6, width = 8, help = 'Category of application',
				required = true,
			},
			editIcon = UI.Button {
				x = 11, y = 6,
				text = 'Edit', event = 'editIcon', help = 'Edit icon file',
			},
			loadIcon = UI.Button {
				x = 11, y = 8,
				text = 'Load', event = 'loadIcon', help = 'Load icon file',
			},
			helpIcon = UI.Button {
				x = 11, y = 8,
				text = 'Load', event = 'loadIcon', help = 'Load icon file',
			},
			image = UI.NftImage {
				backgroundColor = 'black',
				y = 6, x = 2, height = 3, width = 8,
			},
		},
		file_open = UI.FileSelect {
			modal = true,
			enable = function() end,
			transitionHint = 'expandUp',
			show = function(self)
				UI.FileSelect.enable(self)
				self:focusFirst()
				self:draw()
			end,
			disable = function(self)
				UI.FileSelect.disable(self)
				self.parent:focusFirst()
				-- need to recapture as we are opening a modal within another modal
				self.parent:capture(self.parent)
			end,
			eventHandler = function(self, event)
				if event.type == 'select_cancel' then
					self:disable()
				elseif event.type == 'select_file' then
					self:disable()
				end
				return UI.FileSelect.eventHandler(self, event)
			end,
		},
		notification = UI.Notification(),
		statusBar = UI.StatusBar(),
	},
	notification = UI.Notification(),
	accelerators = {
		r = 'refresh',
		e = 'edit',
		f = 'files',
		s = 'shell',
		l = 'lua',
		n = 'network',
		[ 'control-n' ] = 'new',
		delete = 'delete',
	},
}

local function loadApplications()
	local requirements = {
		turtle = not not turtle,
		advancedTurtle = turtle and term.isColor(),
		advanced = term.isColor(),
		pocket = not not pocket,
		advancedPocket = pocket and term.isColor(),
		advancedComputer = not turtle and not pocket and term.isColor(),
		neuralInterface = not not device.neuralInterface,
	}

	applications = Util.readTable('sys/etc/apps.db')

	for dir in pairs(Packages:installed()) do
		local path = fs.combine('packages/' .. dir, 'etc/apps.db')
		if fs.exists(path) then
			local apps = Util.readTable(path) or { }
			Util.merge(applications, apps)
		end
	end

	if fs.exists(REGISTRY_DIR) then
		local files = fs.list(REGISTRY_DIR)
		for _,file in pairs(files) do
			local app = Util.readTable(fs.combine(REGISTRY_DIR, file))
			if app and app.key then
				app.filename = fs.combine(REGISTRY_DIR, file)
				applications[app.key] = app
			end
		end
	end

	Util.each(applications, function(v, k) v.key = k end)
	applications = Util.filter(applications, function(a)
		if a.disabled then
			return false
		end

		if a.requires then
			return requirements[a.requires]
		end

		return true
	end)

	local categories = { }
	buttons = { }
	for _,f in pairs(applications) do
		if not categories[f.category] then
			categories[f.category] = true
			table.insert(buttons, {
				text = f.category,
				width = 8,
				selected = config.currentCategory == f.category
			})
		end
	end
	table.sort(buttons, function(a, b) return a.text < b.text end)
	table.insert(buttons, 1, { text = 'Recent' })

	for k,v in pairs(buttons) do
		v.x = 1
		v.y = k + 1
	end

	page.tabBar.children = { }
	page.tabBar:addButtons(buttons)

	--page.tabBar:selectTab(config.currentCategory or 'Apps')
	page.container:setCategory(config.currentCategory or 'Apps')
end

UI.Icon = class(UI.Window)
UI.Icon.defaults = {
	UIElement = 'Icon',
	width = 14,
	height = 4,
}
function UI.Icon:eventHandler(event)
	if event.type == 'mouse_click' then
		self:setFocus(self.button)
		return true
	elseif event.type == 'mouse_doubleclick' then
		self:emit({ type = self.button.event, button = self.button })
	elseif event.type == 'mouse_rightclick' then
		self:setFocus(self.button)
		self:emit({ type = 'edit', button = self.button })
	end
	return UI.Window.eventHandler(self, event)
end

function page.container:setCategory(categoryName, animate)
	-- reset the viewport window
	self.children = { }
	self:reset()

	local filtered = { }

	if categoryName == 'Recent' then
		for _,v in ipairs(config.Recent) do
			local app = Util.find(applications, 'key', v)
			if app then
				table.insert(filtered, app)
			end
		end
	else
		filtered = Array.filter(applications, function(a)
			return a.category == categoryName
		end)
		table.sort(filtered, function(a, b) return a.title < b.title end)
	end

	for _,program in ipairs(filtered) do
		local icon
		if extSupport and program.iconExt then
			icon = parseIcon(program.iconExt)
		end
		if not icon and program.icon then
			icon = parseIcon(program.icon)
		end
		if not icon then
			icon = DEFAULT_ICON
		end

		local title = ellipsis(program.title, 8)

		local width = math.max(icon.width + 2, #title + 2)
		if config.listMode then
			table.insert(self.children, UI.Icon {
				width = self.width - 2,
				height = 1,
				UI.Button {
					x = 1, ex = -1,
					text = program.title,
					centered = false,
					backgroundColor = self:getProperty('backgroundColor'),
					backgroundFocusColor = 'gray',
					textColor = 'white',
					textFocusColor = 'white',
					event = 'button',
					app = program,
				}
			})
		else
			table.insert(self.children, UI.Icon({
				width = width,
				image = UI.NftImage({
					x = math.floor((width - icon.width) / 2) + 1,
					image = icon,
				}),
				button = UI.Button({
					x = math.floor((width - #title - 2) / 2) + 1,
					y = 4,
					text = title,
					backgroundColor = self:getProperty('backgroundColor'),
					backgroundFocusColor = 'gray',
					textColor = 'white',
					textFocusColor = 'white',
					width = #title + 2,
					event = 'button',
					app = program,
				}),
			}))
		end
	end

	local gutter = 2
	if UI.term.width <= 26 then
		gutter = 1
	end
	local col, row = gutter, 2
	local count = #self.children

	local r = math.random(1, 7)
	local frames = 5
	-- reposition all children
	for k,child in ipairs(self.children) do
		if r == 1 then
			child.x = math.random(1, self.width)
			child.y = math.random(1, self.height - 3)
		elseif r == 2 then
			child.x = self.width
			child.y = self.height - 3
		elseif r == 3 then
			child.x = math.floor(self.width / 2)
			child.y = math.floor(self.height / 2)
		elseif r == 4 then
			child.x = self.width - col
			child.y = row
		elseif r == 5 then
			child.x = col
			child.y = row
			if k == #self.children then
				child.x = self.width
				child.y = self.height - 3
			end
		elseif r == 6 then
			child.x = col
			child.y = 1
		elseif r == 7 then
			child.x = 1
			child.y = self.height - 3
		end
		child.tween = Tween.new(frames, child, { x = col, y = row }, 'inQuad')

		if not animate then
			child.x = col
			child.y = row
		end

		self:setViewHeight(row + (config.listMode and 1 or 4))

		if k < count then
			col = col + child.width
			if col + self.children[k + 1].width + gutter - 2 > self.width then
				col = gutter
				row = row + (config.listMode and 1 or 5)
			end
		end
	end

	self:initChildren()
	if animate then
		local function transition()
			local i = 1
			return function()
				for _,child in pairs(self.children) do
					child.tween:update(1)
					child:move(math.floor(child.x), math.floor(child.y))
				end
				i = i + 1
				return i <= frames
			end
		end
		self:addTransition(transition)
	end
end

function page:refresh()
	local pos = self.container.offy
	self:focusFirst(self)
	self.container:setCategory(config.currentCategory)
	self.container:setScrollPosition(pos)
end

function page:resize()
	UI.Page.resize(self)
	self:refresh()
end

function page:eventHandler(event)
	if event.type == 'tab_select' then
		self.container:setCategory(event.button.text, true)
		self.container:draw()

		config.currentCategory = event.button.text
		Config.update('Overview', config)

	elseif event.type == 'button' then
		for k,v in ipairs(config.Recent) do
			if v == event.button.app.key then
				table.remove(config.Recent, k)
				break
			end
		end
		table.insert(config.Recent, 1, event.button.app.key)
		if #config.Recent > maxRecent then
			table.remove(config.Recent, maxRecent + 1)
		end
		Config.update('Overview', config)
		shell.switchTab(shell.openTab(event.button.app.run))

	elseif event.type == 'shell' then
		shell.switchTab(shell.openTab('shell'))

	elseif event.type == 'lua' then
		shell.switchTab(shell.openTab('Lua'))

	elseif event.type == 'files' then
		shell.switchTab(shell.openTab('Files'))

	elseif event.type == 'network' then
		shell.switchTab(shell.openTab('Network'))

	elseif event.type == 'help' then
		shell.switchTab(shell.openTab('Help Overview'))

	elseif event.type == 'focus_change' then
		if event.focused.parent.UIElement == 'Icon' then
			event.focused.parent:scrollIntoView()
		end

	elseif event.type == 'refresh' then -- remove this after fixing notification
		loadApplications()
		self:refresh()
		self:draw()
		self.notification:success('Refreshed')

	elseif event.type == 'delete' then
		local focused = page:getFocused()
		if focused.app then
			if focused.app.filename then
				fs.delete(focused.app.filename)
			else
				focused.app.disabled = true
				local filename = focused.app.filename or fs.combine(REGISTRY_DIR, focused.app.key)
				Util.writeTable(filename, focused.app)
			end
			loadApplications()
			page:refresh()
			page:draw()
			self.notification:success('Removed')
		end

	elseif event.type == 'new' then
		local category = 'Apps'
		if config.currentCategory ~= 'Recent' then
			category = config.currentCategory or 'Apps'
		end
		self.editor:show({ category = category })

	elseif event.type == 'display_mode' then
		config.listMode = not config.listMode
		Config.update('Overview', config)
		loadApplications()
		self:refresh()
		self:draw()

	elseif event.type == 'edit' then
		local focused = page:getFocused()
		if focused.app then
			self.editor:show(focused.app)
		end

	else
		return UI.Page.eventHandler(self, event)
	end
	return true
end

function page.editor:show(app)
	if app then
		self.form:setValues(app)

		local icon
		if extSupport and app.iconExt then
			icon = parseIcon(app.iconExt)
		end
		if not icon and app.icon then
			icon = parseIcon(app.icon)
		end
		self.form.image:setImage(icon)
	end
	UI.SlideOut.show(self)
	self:focusFirst()
end

function page.editor:updateApplications(app)
	if not app.key then
		app.key = SHA.compute(app.title)
	end
	local filename = app.filename or fs.combine(REGISTRY_DIR, app.key)
	Util.writeTable(filename, app)
	loadApplications()
end

function page.editor:loadImage(filename)
	local s, m = pcall(function()
		local iconLines = Util.readFile(filename)
		if not iconLines then
			error('Must be an NFT image - 3 rows, 8 cols max')
		end
		local icon, m = parseIcon(iconLines)
		if not icon then
			error(m)
		end
		if extSupport then
			self.form.values.iconExt = iconLines
		else
			self.form.values.icon = iconLines
		end
		self.form.image:setImage(icon)
		self.form.image:draw()
	end)
	if not s and m then
		local msg = m:gsub('.*: (.*)', '%1')
		self.notification:error(msg)
	end
end

function page.editor:eventHandler(event)
	if event.type == 'form_cancel' or event.type == 'cancel' then
		self:hide()

	elseif event.type == 'focus_change' then
		self.statusBar:setStatus(event.focused.help or '')

	elseif event.type == 'editIcon' then
		local filename = '/tmp/editing.nft'
		NFT.save(self.form.image.image or TRANS_ICON, filename)
		local success = shell.run('pain.lua ' .. filename)
		self.parent:dirty(true)
		if success then
			self:loadImage(filename)
		end

	elseif event.type == 'select_file' then
		self:loadImage(event.file)

	elseif event.type == 'loadIcon' then
		self.file_open:show()

	elseif event.type == 'form_invalid' then
		self.notification:error(event.message)

	elseif event.type == 'form_complete' then
		local values = self.form.values
		self:hide()
		self:updateApplications(values)
		config.currentCategory = values.category
		Config.update('Overview', config)
		os.queueEvent('overview_refresh')
	else
		return UI.SlideOut.eventHandler(self, event)
	end
	return true
end

local function reload()
	loadApplications()
	page:refresh()
	page:draw()
	page:sync()
end

Event.on('overview_shortcut', function(_, app)
	if not app.key then
		app.key = SHA.compute(app.title)
	end
	local filename = app.filename or fs.combine(REGISTRY_DIR, app.key)
	if not fs.exists(filename) then
		Util.writeTable(filename, app)
		reload()
	end
end)

Event.on('overview_refresh', function()
	reload()
end)

loadApplications()

UI:setPage(page)
UI:start()
