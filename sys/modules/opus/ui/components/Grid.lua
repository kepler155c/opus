local class = require('opus.class')
local UI    = require('opus.ui')
local Util  = require('opus.util')

local os     = _G.os
local _rep   = string.rep

local function safeValue(v)
	local t = type(v)
	if t == 'string' or t == 'number' then
		return v
	end
	return tostring(v)
end

local Writer = class()
function Writer:init(element, y)
	self.element = element
	self.y = y
	self.x = 1
end

function Writer:write(s, width, align, bg, fg)
	s = Util.widthify(s, width, align)
	self.element:write(self.x, self.y, s, bg, fg)
	self.x = self.x + width
end

function Writer:finish(bg)
	if self.x <= self.element.width then
		self.element:write(self.x, self.y, _rep(' ', self.element.width - self.x + 1), bg)
	end
	self.x = 1
	self.y = self.y + 1
end

--[[-- Grid --]]--
UI.Grid = class(UI.Window)
UI.Grid.defaults = {
	UIElement = 'Grid',
	index = 1,
	inverseSort = false,
	disableHeader = false,
	headerHeight = 1,
	marginRight = 0,
	textColor = 'white',
	textSelectedColor = 'white',
	backgroundColor = 'black',
	backgroundSelectedColor = 'gray',
	headerBackgroundColor = 'primary',
	headerTextColor = 'white',
	headerSortColor = 'yellow',
	unfocusedTextSelectedColor = 'white',
	unfocusedBackgroundSelectedColor = 'gray',
	focusIndicator = UI.extChars and '\26' or '>',
	sortIndicator = ' ',
	inverseSortIndicator = UI.extChars and '\24' or '^',
	values = { },
	columns = { },
	accelerators = {
		enter           = 'key_enter',
		[ 'control-c' ] = 'copy',
		down            = 'scroll_down',
		up              = 'scroll_up',
		home            = 'scroll_top',
		[ 'end' ]       = 'scroll_bottom',
		pageUp          = 'scroll_pageUp',
		[ 'control-b' ] = 'scroll_pageUp',
		pageDown        = 'scroll_pageDown',
		[ 'control-f' ] = 'scroll_pageDown',
	},
}
function UI.Grid:layout()
	UI.Window.layout(self)

	for _,c in pairs(self.columns) do
		c.cw = c.width
		if not c.heading then
			c.heading = ''
		end
	end

	self:update()

	if not self.pageSize then
		if self.disableHeader then
			self.pageSize = self.height
		else
			self.pageSize = self.height - self.headerHeight
		end
	end
end

function UI.Grid:resize()
	UI.Window.resize(self)

	if self.disableHeader then
		self.pageSize = self.height
	else
		self.pageSize = self.height - self.headerHeight
	end
	self:adjustWidth()
end

function UI.Grid:adjustWidth()
	local t = { }        -- cols without width
	local w = self.width - #self.columns - 1 - self.marginRight -- width remaining

	for _,c in pairs(self.columns) do
		if c.width then
			c.cw = c.width
			w = w - c.cw
		else
			table.insert(t, c)
		end
	end

	if #t == 0 then
		return
	end

	if #t == 1 then
		t[1].cw = #(t[1].heading or '')
		t[1].cw = math.max(t[1].cw, w)
		return
	end

	if not self.autospace then
		for k,c in ipairs(t) do
			c.cw = math.floor(w / (#t - k + 1))
			w = w - c.cw
		end

	else
		for _,c in ipairs(t) do
			c.cw = #(c.heading or '')
			w = w - c.cw
		end
		-- adjust the size to the length of the value
		for key,row in pairs(self.values) do
			if w <= 0 then
				break
			end
			row = self:getDisplayValues(row, key)
			for _,col in pairs(t) do
				local value = row[col.key]
				if value then
					value = tostring(value)
					if #value > col.cw then
						w = w + col.cw
						col.cw = math.min(#value, w)
						w = w - col.cw
						if w <= 0 then
							break
						end
					end
				end
			end
		end

		-- last column does not get padding (right alignment)
		if not self.columns[#self.columns].width then
			Util.removeByValue(t, self.columns[#self.columns])
		end

		-- got some extra room - add some padding
		if w > 0 then
			for k,c in ipairs(t) do
				local padding = math.floor(w / (#t - k + 1))
				c.cw = c.cw + padding
				w = w - padding
			end
		end
	end
end

function UI.Grid:setPageSize(pageSize)
	self.pageSize = pageSize
end

function UI.Grid:getValues()
	return self.values
end

function UI.Grid:setValues(t)
	self.values = t
	self:update()
end

function UI.Grid:setInverseSort(inverseSort)
	self.inverseSort = inverseSort
	self:update()
	self:setIndex(self.index)
end

function UI.Grid:setSortColumn(column)
	self.sortColumn = column
end

function UI.Grid:getDisplayValues(row, key)
	return row
end

function UI.Grid:getSelected()
	if self.sorted then
		return self.values[self.sorted[self.index]], self.sorted[self.index]
	end
end

function UI.Grid:setSelected(name, value)
	if self.sorted then
		for k,v in pairs(self.sorted) do
			if self.values[v][name] == value then
				self:setIndex(k)
				return
			end
		end
	end
	self:setIndex(1)
end

function UI.Grid:focus()
	self:drawRows()
end

function UI.Grid:draw()
	if not self.disableHeader then
		self:drawHeadings()
	end

	if self.index <= 0 then
		self:setIndex(1)
	elseif self.index > #self.sorted then
		self:setIndex(#self.sorted)
	end
	self:drawRows()
end

-- Something about the displayed table has changed
-- resort the table
function UI.Grid:update()
	local function sort(a, b)
		if not a[self.sortColumn] then
			return false
		elseif not b[self.sortColumn] then
			return true
		end
		return self:sortCompare(a, b)
	end

	local function inverseSort(a, b)
		return not sort(a, b)
	end

	local order
	if self.sortColumn then
		order = sort
		if self.inverseSort then
			order = inverseSort
		end
	end

	self.sorted = Util.keys(self.values)
	if order then
		table.sort(self.sorted, function(a,b)
			return order(self.values[a], self.values[b])
		end)
	end

	self:adjustWidth()
end

function UI.Grid:drawHeadings()
	if self.headerHeight > 1 then
		self:clear(self.headerBackgroundColor)
	end
	local sb = Writer(self, math.ceil(self.headerHeight / 2))
	for _,col in ipairs(self.columns) do
		local ind = ' '
		local color = self.headerTextColor
		if col.key == self.sortColumn then
			if self.inverseSort then
				ind = self.inverseSortIndicator
			else
				ind = self.sortIndicator
			end
			color = self.headerSortColor
		end
		sb:write(ind .. col.heading,
			col.cw + 1,
			col.align,
			self.headerBackgroundColor,
			color)
	end
	sb:finish(self.headerBackgroundColor)
end

function UI.Grid:sortCompare(a, b)
	a = safeValue(a[self.sortColumn])
	b = safeValue(b[self.sortColumn])
	if type(a) == type(b) then
		return a < b
	end
	return tostring(a) < tostring(b)
end

function UI.Grid:drawRows()
	local startRow = math.max(1, self:getStartRow())

	local sb = Writer(self, self.disableHeader and 1 or self.headerHeight + 1)

	local lastRow = math.min(startRow + self.pageSize - 1, #self.sorted)
	for index = startRow, lastRow do

		local key = self.sorted[index]
		local rawRow = self.values[key]
		local row = self:getDisplayValues(rawRow, key)

		local selected = index == self.index and not self.inactive
		local bg = self:getRowBackgroundColor(rawRow, selected)
		local fg = self:getRowTextColor(rawRow, selected)
		local focused = self.focused and selected

		self:drawRow(sb, row, focused, bg, fg)

		sb:finish(bg)
	end

	if sb.y <= self.height then
		self:clearArea(1, sb.y, self.width, self.height - sb.y + 1)
	end
end

function UI.Grid:drawRow(sb, row, focused, bg, fg)
	local ind = focused and self.focusIndicator or ' '

	for _,col in pairs(self.columns) do
		sb:write(ind .. safeValue(row[col.key] or ''),
			col.cw + 1,
			col.align,
			col.backgroundColor or bg,
			col.textColor or fg)
		ind = ' '
	end
end

function UI.Grid:getRowTextColor(row, selected)
	if selected then
		if self.focused then
			return self.textSelectedColor
		end
		return self.unfocusedTextSelectedColor
	end
	return self.textColor
end

function UI.Grid:getRowBackgroundColor(row, selected)
	if selected then
		if self.focused then
			return self.backgroundSelectedColor
		end
		return self.unfocusedBackgroundSelectedColor
	end
	return self.backgroundColor
end

function UI.Grid:getIndex()
	return self.index
end

function UI.Grid:setIndex(index)
	index = math.max(1, index)
	self.index = math.min(index, #self.sorted)

	local selected = self:getSelected()
	if selected ~= self.selected then
		self:drawRows()
		self.selected = selected
		if selected then
			self:emit({ type = 'grid_focus_row', selected = selected, element = self })
		end
	end
end

function UI.Grid:getStartRow()
	return math.floor((self.index - 1) / self.pageSize) * self.pageSize + 1
end

function UI.Grid:getPage()
	return math.floor(self.index / self.pageSize) + 1
end

function UI.Grid:getPageCount()
	local tableSize = Util.size(self.values)
	local pc = math.floor(tableSize / self.pageSize)
	if tableSize % self.pageSize > 0 then
		pc = pc + 1
	end
	return pc
end

function UI.Grid:nextPage()
	self:setPage(self:getPage() + 1)
end

function UI.Grid:previousPage()
	self:setPage(self:getPage() - 1)
end

function UI.Grid:setPage(pageNo)
	-- 1 based paging
	self:setIndex((pageNo-1) * self.pageSize + 1)
end

function UI.Grid:eventHandler(event)
	if event.type == 'mouse_click' or
		 event.type == 'mouse_rightclick' or
		 event.type == 'mouse_doubleclick' then
		if not self.disableHeader then
			if event.y <= self.headerHeight then
				local col = 2
				for _,c in ipairs(self.columns) do
					if event.x < col + c.cw then
						self:emit({
							type = 'grid_sort',
							sortColumn = c.key,
							inverseSort = self.sortColumn == c.key and not self.inverseSort,
							element = self,
						})
						break
					end
					col = col + c.cw + 1
				end
				return true
			end
		end
		local row = self:getStartRow() + event.y - 1
		if not self.disableHeader then
			row = row - self.headerHeight
		end
		if row > 0 and row <= Util.size(self.values) then
			self:setIndex(row)
			if event.type == 'mouse_doubleclick' then
				self:emit({ type = 'key_enter' })
			elseif event.type == 'mouse_rightclick' then
				self:emit({ type = 'grid_select_right', selected = self.selected, element = self })
			end
			return true
		end
		return false

	elseif event.type == 'grid_sort' then
		self.sortColumn = event.sortColumn
		self:setInverseSort(event.inverseSort)
		self:draw()
	elseif event.type == 'scroll_down' then
		self:setIndex(self.index + 1)
	elseif event.type == 'scroll_up' then
		self:setIndex(self.index - 1)
	elseif event.type == 'scroll_top' then
		self:setIndex(1)
	elseif event.type == 'scroll_bottom' then
		self:setIndex(Util.size(self.values))
	elseif event.type == 'scroll_pageUp' then
		self:setIndex(self.index - self.pageSize)
	elseif event.type == 'scroll_pageDown' then
		self:setIndex(self.index + self.pageSize)
	elseif event.type == 'scroll_to' then
		self:setIndex(event.offset)
	elseif event.type == 'key_enter' then
		if self.selected then
			self:emit({ type = 'grid_select', selected = self.selected, element = self })
		end
	elseif event.type == 'copy' then
		if self.selected then
			os.queueEvent('clipboard_copy', self.selected)
		end
	else
		return false
	end
	return true
end

function UI.Grid.example()
	local values = {
		{ key = 'key1', value = 'value1' },
		{ key = 'key2', value = 'value2' },
		{ key = 'key3', value = 'value3-longer value text' },
		{ key = 'key4', value = 'value4' },
		{ key = 'key5', value = 'value5' },
	}
	return UI.Window {
		regular = UI.Grid {
			ex = '48%', ey = 4,
			values = values,
			sortColumn = 'key',
			inverseSort = true,
			columns = {
				{ heading = 'key', key = 'key' },
				{ heading = 'value', key = 'value' },
			},
			accelerators = {
				grid_select = 'custom_select',
			}
		},
		noheader = UI.Grid {
			ex = '48%', y = 6, ey = -2,
			disableHeader = true,
			values = values,
			columns = {
				{ heading = 'key', key = 'key', width = 6,  },
				{ heading = 'value', key = 'value', textColor = 'yellow' },
			},
		},
		autospace = UI.Grid {
			x = '52%', ey = 4,
			autospace = true,
			values = values,
			columns = {
				{ heading = 'key', key = 'key' },
				{ heading = 'value', key = 'value' },
			},
		},
	}
end
