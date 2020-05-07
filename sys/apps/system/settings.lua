local UI = require('opus.ui')

local settings = _G.settings

local transform = {
	string = tostring,
	number = tonumber,
}

return settings and UI.Tab {
	title = 'Settings',
	description = 'Computercraft settings',
	grid = UI.Grid {
		x = 2, y = 2, ex = -2, ey = -2,
		sortColumn = 'name',
		columns = {
			{ heading = 'Setting',   key = 'name' },
			{ heading = 'Value', key = 'value'  },
		},
	},
	editor = UI.SlideOut {
		y = -6, height = 6,
		titleBar = UI.TitleBar {
			event = 'slide_hide',
			title = 'Enter value',
		},
		form = UI.Form {
			y = 2,
			value = UI.TextEntry {
				formIndex = 1,
				formLabel = 'Value',
				formKey = 'value',
			},
			validateField = function(self, entry)
				if entry.value then
					return transform[self.type](entry.value)
				end
				return true
			end,
		},
		accelerators = {
			form_cancel = 'slide_hide',
		},
		show = function(self, entry)
			self.form.type = type(entry.value) or 'string'
			self.form:setValues(entry)
			self.titleBar.title = entry.name
			UI.SlideOut.show(self)
		end,
		eventHandler = function(self, event)
			if event.type == 'form_complete' then
				if not event.values.value then
					settings.unset(event.values.name)
					self.parent:reload()
				else
					event.values.value = transform[self.form.type](event.values.value)
					settings.set(event.values.name, event.values.value)
				end
				self.parent.grid:draw()
				self:hide()
				settings.save('.settings')
			end
			return UI.SlideOut.eventHandler(self, event)
		end,
	},
	reload = function(self)
		local values = { }
		for _,v in pairs(settings.getNames()) do
			table.insert(values, {
				name = v,
				value = settings.get(v) or false,
			})
		end
		self.grid:setValues(values)
		self.grid:setIndex(1)
	end,
	enable = function(self)
		self:reload()
		UI.Tab.enable(self)
	end,
	eventHandler = function(self, event)
		if event.type == 'grid_select' then
			if type(event.selected.value) == 'boolean' then
				event.selected.value = not event.selected.value
				settings.set(event.selected.name, event.selected.value)
				settings.save('.settings')
				self.grid:draw()
			else
				self.editor:show(event.selected)
			end
			return true
		end
	end,
}
