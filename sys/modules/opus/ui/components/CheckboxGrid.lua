local class = require('opus.class')
local UI    = require('opus.ui')

local function safeValue(v)
	local t = type(v)
	if t == 'string' or t == 'number' then
		return v
	end
	return tostring(v)
end

UI.CheckboxGrid = class(UI.Grid)
UI.CheckboxGrid.defaults = {
	UIElement = 'CheckboxGrid',
	checkedKey = 'checked',
	accelerators = {
		[ ' ' ] = 'grid_toggle',
		key_enter = 'grid_toggle',
	},
}
function UI.CheckboxGrid:drawRow(sb, row, focused, bg, fg)
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

function UI.CheckboxGrid:eventHandler(event)
	if event.type == 'grid_toggle' and self.selected then
		self.selected.checked = not self.selected.checked
		self:draw()
		self:emit({ type = 'grid_check', checked = self.selected, element = self })
	else
		return UI.Grid.eventHandler(self, event)
	end
end

function UI.CheckboxGrid.example()
	return UI.CheckboxGrid {
		values = {
			{ checked = false, name = 'unchecked' },
			{ checked = true, name = 'checked' },
		},
		columns = {
			{ heading = 'Checked', key = 'checked' },
			{ heading = 'Data', key = 'name',  }
		},
	}
end
