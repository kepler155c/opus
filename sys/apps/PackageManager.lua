_G.requireInjector(_ENV)

local Ansi     = require('ansi')
local Packages = require('packages')
local UI       = require('ui')

local colors   = _G.colors
local shell    = _ENV.shell
local term     = _G.term

UI:configure('PackageManager', ...)

local page = UI.Page {
	grid = UI.ScrollingGrid {
		y = 2, ey = 7, x = 2, ex = -6,
		values = { },
		columns = {
			{ heading = 'Package', key = 'name' },
		},
		sortColumn = 'name',
		autospace = true,
		help = 'Select a package',
	},
	add = UI.Button {
		x = -4, y = 4,
		text = '+',
		event = 'action',
		help = 'Install or update',
	},
	remove = UI.Button {
		x = -4, y = 6,
		text = '-',
		event = 'action',
		operation = 'uninstall',
		operationText = 'Remove',
		help = 'Remove',
	},
	description = UI.TextArea {
		x = 2, y = 9, ey = -2,
		--backgroundColor = colors.white,
	},
	statusBar = UI.StatusBar { },
	action = UI.SlideOut {
		backgroundColor = colors.cyan,
		titleBar = UI.TitleBar {
			event = 'hide-action',
		},
		button = UI.Button {
			ex = -4, y = 4, width = 7,
			text = 'Begin', event = 'begin',
		},
		output = UI.Embedded {
			y = 6, ey = -2, x = 2, ex = -2,
		},
		statusBar = UI.StatusBar {
			backgroundColor = colors.cyan,
		},
	},
}

function page.grid:getRowTextColor(row, selected)
	if row.installed then
		return colors.yellow
	end
	return UI.Grid.getRowTextColor(self, row, selected)
end

function page.action:show()
	UI.SlideOut.show(self)
	self.output:draw()
	self.output.win.redraw()
end

function page:run(operation, name)
	local oterm = term.redirect(self.action.output.win)
	self.action.output:clear()
	local cmd = string.format('package %s %s', operation, name)
	--for _ = 1, 3 do
	--	print(cmd .. '\n')
	--	os.sleep(1)
	--end
	term.setCursorPos(1, 1)
	term.clear()
	term.setTextColor(colors.yellow)
	print(cmd .. '\n')
	term.setTextColor(colors.white)
	shell.run(cmd)
	term.redirect(oterm)
	self.action.output:draw()
end

function page:updateSelection(selected)
	self.add.operation = selected.installed and 'update' or 'install'
	self.add.operationText = selected.installed and 'Update' or 'Install'
end

function page:eventHandler(event)
	if event.type == 'focus_change' then
		self.statusBar:setStatus(event.focused.help)

	elseif event.type == 'grid_focus_row' then
		local manifest = event.selected.manifest

		self.description.value = string.format('%s%s\n\n%s%s',
			Ansi.yellow, manifest.title,
			Ansi.white, manifest.description)
		self.description:draw()
		self:updateSelection(event.selected)

	elseif event.type == 'action' then
		local selected = self.grid:getSelected()
		if selected then
			self.operation = event.button.operation
			self.action.button.text = event.button.operationText
			self.action.titleBar.title = selected.manifest.title
			self.action.button.text = 'Begin'
			self.action.button.event = 'begin'
			self.action:show()
		end

	elseif event.type == 'hide-action' then
		self.action:hide()

	elseif event.type == 'begin' then
		local selected = self.grid:getSelected()
		self:run(self.operation, selected.name)
		selected.installed = Packages:isInstalled(selected.name)

		self:updateSelection(selected)
		self.action.button.text = 'Done'
		self.action.button.event = 'hide-action'
		self.action.button:draw()

	elseif event.type == 'quit' then
		UI:exitPullEvents()
	end
	UI.Page.eventHandler(self, event)
end

for k in pairs(Packages:list()) do
	local manifest = Packages:getManifest(k)
	if not manifest then
		manifest = {
			invalid = true,
			description = 'Unable to download manifest',
			title = '',
		}
	end
	table.insert(page.grid.values, {
		installed = not not Packages:isInstalled(k),
		name = k,
		manifest = manifest,
	})
end
page.grid:update()

UI:setPage(page)
UI:pullEvents()
