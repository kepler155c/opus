local UI   = require('opus.ui')
local Util = require('opus.util')

local colors     = _G.colors
local multishell = _ENV.multishell

local name = ({ ... })[1] or error('Syntax: inspect COMPONENT')
local events = { }
local page, lastEvent, focused

local function isRelevant(el)
	return page.testContainer == el or el.parent and isRelevant(el.parent)
end

local emitter = UI.Window.emit
function UI.Window:emit(event)
	if event ~= lastEvent and isRelevant(self) then
		lastEvent = event
		local t = { }
		for k,v in pairs(event) do
			if k ~= 'type' and k ~= 'recorded' then
				table.insert(t, k .. ':' .. (type(v) == 'table' and (v.UIElement and v.uid or 'tbl') or tostring(v)))
			end
		end
		table.insert(events, 1, { type = event.type, value = table.concat(t, ' '), raw = event })
		while #events > 20 do
			table.remove(events)
		end
		page.tabs.events.grid:update()
		if page.tabs.events.enabled then
			page.tabs.events.grid:draw()
		end
	end
	return emitter(self, event)
end

-- do not load component until emit hook is in place
local component = UI[name] and UI[name]() or error('Invalid component')
if not component.example then
	error('No example present')
end

page = UI.Page {
	testContainer = UI.Window {
		ey = '50%',
		testing = component.example(),
	},
	tabs = UI.Tabs {
		backgroundColor = colors.red,
		y = '50%',
		properties = UI.Tab {
			title = 'Properties',
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
			index = 2,
			title = 'Methods',
			grid = UI.ScrollingGrid {
				ex = '50%',
				headerBackgroundColor = colors.red,
				sortColumn = 'key',
				columns = {
					{ heading = 'key', key = 'key' },
				},
			},
			docs = UI.TextArea {
				x = '50%',
				backgroundColor = colors.black,
			},
			eventHandler = function (self, event)
				if event.type == 'grid_focus_row' and focused then
					self.docs:setText(focused:getDoc(event.selected.key) or '')
				end
			end,
		},
		events = UI.Tab {
			index = 1,
			title = 'Events',
			UI.MenuBar {
				y = -1,
				backgroundColor = colors.red,
				buttons = {
					{ text = 'Clear' },
				}
			},
			grid = UI.ScrollingGrid {
				ey = -2,
				headerBackgroundColor = colors.red,
				values = events,
				autospace = true,
				columns = {
					{ heading = 'type', key = 'type' },
					{ heading = 'value', key = 'value',  }
				},
			},
			eventHandler = function (self, event)
				if event.type == 'button_press' then
					Util.clear(self.grid.values)
					self.grid:update()
					self.grid:draw()

				elseif event.type == 'grid_select' then
					multishell.openTab(_ENV, {
						path = 'sys/apps/Lua.lua',
						args = { event.selected.raw },
						focused = true,
					})
				end
			end
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
	accelerators = {
		['shift-right'] = 'size',
		['shift-left' ] = 'size',
		['shift-up'   ] = 'size',
		['shift-down' ] = 'size',
	},
	eventHandler = function (self, event)
		if event.type == 'focus_change' and isRelevant(event.focused) then
			focused = event.focused
			local t = { }
			for k,v in pairs(event.focused) do
				table.insert(t, {
					key = k,
					value = tostring(v),
				})
			end
			self.tabs.properties.grid:setValues(t)
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
			self.tabs.methodsTab.grid:draw()

		elseif event.type == 'edit_property' then
			self.editor.entry.value = event.selected.value
			self.editor:show()

		elseif event.type == 'editor_cancel' then
			self.editor:hide()

		elseif event.type == 'editor_apply' then
			self.editor:hide()

		elseif event.type == 'size' then
			local sizing = {
				['shift-right'] = {  1,  0 },
				['shift-left' ] = { -1,  0 },
				['shift-up'   ] = {  0, -1 },
				['shift-down' ] = {  0,  1 },
			}
			self.ox = math.max(self.ox + sizing[event.ie.code][1], 1)
			self.oy = math.max(self.oy + sizing[event.ie.code][2], 1)
			UI.term:clear()
			self:resize()
			self:draw()
		end

		return UI.Page.eventHandler(self, event)
	end
}

UI:setPage(page)
UI:start()
