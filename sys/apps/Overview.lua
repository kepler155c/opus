_G.requireInjector(_ENV)

local class    = require('class')
local Config   = require('config')
local Event    = require('event')
local FileUI   = require('ui.fileui')
local NFT      = require('nft')
local Packages = require('packages')
local SHA1     = require('sha1')
local Tween    = require('ui.tween')
local UI       = require('ui')
local Util     = require('util')

local colors     = _G.colors
local fs         = _G.fs
local pocket     = _G.pocket
local shell      = _ENV.shell
local term       = _G.term
local turtle     = _G.turtle

if not _ENV.multishell then
	error('multishell is required')
end

local REGISTRY_DIR = 'usr/.registry'

UI:configure('Overview', ...)

local config = {
	Recent = { },
	currentCategory = 'Apps',
}
Config.load('Overview', config)

local applications = { }
local extSupport = Util.getVersion() >= 1.76

local function loadApplications()
	local requirements = {
		turtle = not not turtle,
		advancedTurtle = turtle and term.isColor(),
		advanced = term.isColor(),
		pocket = not not pocket,
		advancedPocket = pocket and term.isColor(),
		advancedComputer = not turtle and not pocket and term.isColor(),
	}

	applications = Util.readTable('sys/etc/app.db')

	for dir in pairs(Packages:installed()) do
		local path = fs.combine('packages/' .. dir, 'etc/apps')
		if fs.exists(path) then
			local dbs = fs.list(path)
			for _, db in pairs(dbs) do
				local apps = Util.readTable(fs.combine(path, db)) or { }
				Util.merge(applications, apps)
			end
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

		return true -- Util.startsWith(a.run, 'http') or shell.resolveProgram(a.run)
	end)
end

loadApplications()

local defaultIcon = NFT.parse("\03180\031711\03180\
\031800\03171\03180\
\03171\031800\03171")

local sx, sy = term.current().getSize()
local maxRecent = math.ceil(sx * sy / 62)

local function elipse(s, len)
	if #s > len then
		s = s:sub(1, len - 2) .. '..'
	end
	return s
end

local buttons = { }
local categories = { }
for _,f in pairs(applications) do
	if not categories[f.category] then
		categories[f.category] = true
		table.insert(buttons, { text = f.category })
	end
end
table.sort(buttons, function(a, b) return a.text < b.text end)
table.insert(buttons, 1, { text = 'Recent' })
table.insert(buttons, { text = '+', event = 'new' })

local function parseIcon(iconText)
	local icon

	local s, m = pcall(function()
		icon = NFT.parse(iconText)
		if icon then
			if icon.height > 3 or icon.width > 8 then
				error('Must be an NFT image - 3 rows, 8 cols max')
			end
		end
		return icon
	end)

	if s then
		return icon
	end

	return s, m
end

UI.VerticalTabBar = class(UI.TabBar)
function UI.VerticalTabBar:setParent()
	self.x = 1
	self.width = 8
	self.height = nil
	self.ey = -1
	UI.TabBar.setParent(self)
	for k,c in pairs(self.children) do
		c.x = 1
		c.y = k + 1
		c.ox, c.oy = c.x, c.y
		c.ow = 8
		c.width = 8
	end
end

local cx = 9
local cy = 1
if sx < 30 then
	UI.VerticalTabBar = UI.TabBar
	cx = 1
	cy = 2
end

local page = UI.Page {
	tabBar = UI.VerticalTabBar {
		buttons = buttons,
	},
	container = UI.Viewport {
		x = cx,
		y = cy,
	},
	notification = UI.Notification(),
	accelerators = {
		r = 'refresh',
		e = 'edit',
		f = 'files',
		s = 'shell',
		l = 'lua',
		[ 'control-n' ] = 'new',
		delete = 'delete',
	},
}

if extSupport then
	page.container.backgroundColor = colors.black
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
	self.offy = 0

	local function filter(it, f)
		local ot = { }
		for _,v in pairs(it) do
			if f(v) then
				table.insert(ot, v)
			end
		end
		return ot
	end

	local filtered

	if categoryName == 'Recent' then
		filtered = { }

		for _,v in ipairs(config.Recent) do
			local app = Util.find(applications, 'key', v)
			if app then -- and fs.exists(app.run) then
				table.insert(filtered, app)
			end
		end

	else
		filtered = filter(applications, function(a)
			return a.category == categoryName -- and fs.exists(a.run)
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
			icon = defaultIcon
		end

		local title = elipse(program.title, 8)

		local width = math.max(icon.width + 2, #title + 2)
		table.insert(self.children, UI.Icon({
			width = width,
			image = UI.NftImage({
				x = math.floor((width - icon.width) / 2) + 1,
				image = icon,
				width = 5,
				height = 3,
			}),
			button = UI.Button({
				x = math.floor((width - #title - 2) / 2) + 1,
				y = 4,
				text = title,
				backgroundColor = self.backgroundColor,
				backgroundFocusColor = colors.gray,
				textColor = colors.white,
				textFocusColor = colors.white,
				width = #title + 2,
				event = 'button',
				app = program,
			}),
		}))
	end

	local gutter = 2
	if UI.term.width <= 26 then
		gutter = 1
	end
	local col, row = gutter, 2
	local count = #self.children

	local r = math.random(1, 5)
	-- reposition all children
	for k,child in ipairs(self.children) do
		if r == 1 then
			child.x = math.random(1, self.width)
			child.y = math.random(1, self.height)
		elseif r == 2 then
			child.x = self.width
			child.y = self.height
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
				child.y = self.height
			end
		end
		child.tween = Tween.new(6, child, { x = col, y = row }, 'linear')

		if not animate then
			child.x = col
			child.y = row
		end

		if k < count then
			col = col + child.width
			if col + self.children[k + 1].width + gutter - 2 > self.width then
				col = gutter
				row = row + 5
			end
		end
	end

	self:initChildren()
	if animate then                      -- need to fix transitions under layers
		local function transition(args)
			local i = 1
			return function(device)
				self:clear()
				for _,child in pairs(self.children) do
					child.tween:update(1)
					child.x = math.floor(child.x)
					child.y = math.floor(child.y)
					child:draw()
				end
				args.canvas:blit(device, args, args)
				i = i + 1
				return i < 7
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
		shell.switchTab(shell.openTab('sys/apps/shell'))

	elseif event.type == 'lua' then
		shell.switchTab(shell.openTab('sys/apps/Lua.lua'))

	elseif event.type == 'files' then
		shell.switchTab(shell.openTab('sys/apps/Files.lua'))

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
			focused.app.disabled = true
			local filename = focused.app.filename or fs.combine(REGISTRY_DIR, focused.app.key)
			Util.writeTable(filename, focused.app)
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
		UI:setPage('editor', { category = category })

	elseif event.type == 'edit' then
		local focused = page:getFocused()
		if focused.app then
			UI:setPage('editor', focused.app)
		end

	else
		UI.Page.eventHandler(self, event)
	end
	return true
end

local formWidth = math.max(UI.term.width - 8, 26)

local editor = UI.Dialog {
	height = 11,
	width = formWidth,
	title = 'Edit Application',
	form = UI.Form {
		y = 2,
		height = 9,
		title = UI.TextEntry {
			formLabel = 'Title', formKey = 'title', limit = 11, help = 'Application title',
			required = true,
		},
		run = UI.TextEntry {
			formLabel = 'Run', formKey = 'run', limit = 100, help = 'Full path to application',
			required = true,
		},
		category = UI.TextEntry {
			formLabel = 'Category', formKey = 'category', limit = 11, help = 'Category of application',
			required = true,
		},
		loadIcon = UI.Button {
			x = 11, y = 6,
			text = 'Icon', event = 'loadIcon', help = 'Select icon'
		},
		image = UI.NftImage {
			y = 6, x = 2, height = 3, width = 8,
		},
	},
	statusBar = UI.StatusBar(),
	iconFile = '',
}

function editor:enable(app)
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
	UI.Dialog.enable(self)
	self:focusFirst()
end

function editor.form.image:draw()
	self:clear()
	UI.NftImage.draw(self)
end

function editor:updateApplications(app)
	if not app.key then
		app.key = SHA1.sha1(app.title)
	end
	local filename = app.filename or fs.combine(REGISTRY_DIR, app.key)
	Util.writeTable(filename, app)
	loadApplications()
end

function editor:eventHandler(event)
	if event.type == 'form_cancel' or event.type == 'cancel' then
		UI:setPreviousPage()

	elseif event.type == 'focus_change' then
		self.statusBar:setStatus(event.focused.help or '')
		self.statusBar:draw()

	elseif event.type == 'loadIcon' then
		local fileui = FileUI({
			x = self.x,
			y = self.y,
			z = 2,
			width = self.width,
			height = self.height,
		})
		UI:setPage(fileui, fs.getDir(self.iconFile), function(fileName)
			if fileName then
				self.iconFile = fileName
				local s, m = pcall(function()
					local iconLines = Util.readFile(fileName)
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
					page.notification:error(msg)
				end
			end
		end)

	elseif event.type == 'form_invalid' then
		page.notification:error(event.message)

	elseif event.type == 'form_complete' then
		local values = self.form.values
		UI:setPreviousPage()
		self:updateApplications(values)
		page:refresh()
		page:draw()
	else
		return UI.Dialog.eventHandler(self, event)
	end
	return true
end

UI:setPages({
	editor = editor,
	main = page,
})

Event.on('os_register_app', function()
	loadApplications()
	page:refresh()
	page:draw()
	page:sync()
end)

page.tabBar:selectTab(config.currentCategory or 'Apps')
page.container:setCategory(config.currentCategory or 'Apps')
UI:setPage(page)

UI:pullEvents()
