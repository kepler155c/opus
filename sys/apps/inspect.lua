local UI = require('opus.ui')

local colors     = _G.colors
local multishell = _ENV.multishell

local name = ({ ... })[1] or error('Syntax: inspect COMPONENT')
local events = { }
local page

local function isRelevant(el)
	return page.testContainer == el or el.parent and isRelevant(el.parent)
end

local emitter = UI.Window.emit
function UI.Window:emit(event)
	if not event._recorded and isRelevant(self) then
		local t = { }
		for k,v in pairs(event) do
			if k ~= 'type' and k ~= 'recorded' then
				table.insert(t, k .. ':' .. (type(v) == 'table' and (v.UIElement and v.uid or 'tbl') or tostring(v)))
			end
		end
		table.insert(events, 1, { type = event.type, value = table.concat(t, ' '), raw = event })
		while #events > 10 do
			table.remove(events)
		end
		page.tabs.events.grid:update()
		if page.tabs.events.enabled then
			page.tabs.events.grid:draw()
		end
	end
	event._recorded = true
	return emitter(self, event)
end

-- do not load component until emit hook is in place
local component = UI[name] and UI[name]() or error('Invalid component')
if not component.example then
	error('No example present')
end

page = UI.Page {
	testContainer = UI.Window {
		ey = 10,
		testing = component.example(),
	},
	tabs = UI.Tabs {
		y = 11,
		properties = UI.Tab {
			tabTitle = 'Properties',
			grid = UI.ScrollingGrid {
				headerBackgroundColor = colors.red,
				sortColumn = 'key',
				columns = {
					{ heading = 'key', key = 'key' },
					{ heading = 'value', key = 'value',  }
				},
				accelerators = {
					grid_select = 'edit_property',
				},
			},
		},
		methodsTab = UI.Tab {
			tabTitle = 'Methods',
			grid = UI.ScrollingGrid {
				headerBackgroundColor = colors.red,
				sortColumn = 'key',
				columns = {
					{ heading = 'key', key = 'key' },
				},
			},
		},
		events = UI.Tab {
			tabTitle = 'Events',
			grid = UI.ScrollingGrid {
				headerBackgroundColor = colors.red,
				values = events,
				autospace = true,
				columns = {
					{ heading = 'type', key = 'type' },
					{ heading = 'value', key = 'value',  }
				},
			}
		}
	},
	editor = UI.SlideOut {
		y = -4, height = 4,
		backgroundColor = colors.green,
		titleBar = UI.TitleBar {
			event = 'editor_cancel',
			title = 'Enter value',
		},
		entry = UI.TextEntry {
			y = 3, x = 2, ex = 10,
			accelerators = {
				enter = 'editor_apply',
			},
		},
	},
	eventHandler = function (self, event)
		if event.type == 'focus_change' and isRelevant(event.focused) then
			local t = { }
			for k,v in pairs(event.focused) do
				table.insert(t, {
					key = k,
					value = tostring(v),
				})
			end
			self.tabs.properties.grid:setValues(t)
			self.tabs.properties.grid:update()
			self.tabs.properties.grid:draw()

			t = { }
			for k,v in pairs(getmetatable(event.focused)) do
				if type(v) == 'function' then
					table.insert(t, {
						key = k,
					})
				end
			end
			self.tabs.methodsTab.grid:setValues(t)
			self.tabs.methodsTab.grid:update()
			self.tabs.methodsTab.grid:draw()

		elseif event.type == 'grid_select' and event.element == self.tabs.events.grid then
			event.selected.raw._recorded = nil
			multishell.openTab({
				path = 'sys/apps/Lua.lua',
				args = { event.selected.raw },
				focused = true,
			})

		elseif event.type == 'grid_select' and event.element == self.tabs.properties.grid then
			self.editor.entry.value = event.selected.value
			self.editor:show()

		elseif event.type == 'editor_cancel' then
			self.editor:hide()

		elseif event.type == 'editor_apply' then
			self.editor:hide()
		end

		return UI.Page.eventHandler(self, event)
	end
}

UI:setPage(page)
UI:pullEvents()
