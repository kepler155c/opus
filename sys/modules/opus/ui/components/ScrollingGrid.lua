local class = require('opus.class')
local UI    = require('opus.ui')
local Util  = require('opus.util')

UI.ScrollingGrid = class(UI.Grid)
UI.ScrollingGrid.defaults = {
	UIElement = 'ScrollingGrid',
	scrollOffset = 0,
	marginRight = 1,
}
function UI.ScrollingGrid:postInit()
	self.scrollBar = UI.ScrollBar()
end

function UI.ScrollingGrid:drawRows()
	UI.Grid.drawRows(self)
	self.scrollBar:draw()
end

function UI.ScrollingGrid:getViewArea()
	local y = 1
	if not self.disableHeader then
		y = y + self.headerHeight
	end

	return {
		static      = true,                    -- the container doesn't scroll
		y           = y,                       -- scrollbar Y
		height      = self.pageSize,           -- viewable height
		totalHeight = Util.size(self.values),  -- total height
		offsetY     = self.scrollOffset,       -- scroll offset
		fill        = not self.disableHeader and self.headerBackgroundColor,
	}
end

function UI.ScrollingGrid:getStartRow()
	local ts = Util.size(self.values)
	if ts < self.pageSize then
		self.scrollOffset = 0
	end
	return self.scrollOffset + 1
end

function UI.ScrollingGrid:setIndex(index)
	if index < self.scrollOffset + 1 then
		self.scrollOffset = index - 1
	elseif index - self.scrollOffset > self.pageSize then
		self.scrollOffset = index - self.pageSize
	end

	if self.scrollOffset < 0 then
		self.scrollOffset = 0
	else
		local ts = Util.size(self.values)
		if self.pageSize + self.scrollOffset + 1 > ts then
			self.scrollOffset = math.max(0, ts - self.pageSize)
		end
	end
	UI.Grid.setIndex(self, index)
end

function UI.ScrollingGrid.example()
	local values = { }
	for i = 1, 20 do
		table.insert(values, { key = 'key' .. i, value = 'value' .. i })
	end
	return UI.ScrollingGrid {
		values = values,
		sortColumn = 'key',
		columns = {
			{ heading = 'key', key = 'key' },
			{ heading = 'value', key = 'value' },
		},
		accelerators = {
			grid_select = 'custom_select',
		}
	}
end