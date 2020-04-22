local class = require('opus.class')
local Sound = require('opus.sound')
local UI    = require('opus.ui')

UI.Form = class(UI.Window)
UI.Form.defaults = {
	UIElement = 'Form',
	values = { },
	margin = 2,
	event = 'form_complete',
	cancelEvent = 'form_cancel',
}
function UI.Form:postInit()
	self:createForm()
end

function UI.Form:reset()
	for _,child in pairs(self.children) do
		if child.reset then
			child:reset()
		end
	end
end

function UI.Form:setValues(values)
	self:reset()
	self.values = values
	for _,child in pairs(self.children) do
		if child.formKey then
			if child.setValue then
				child:setValue(self.values[child.formKey])
			else
				child.value = self.values[child.formKey]
			end
		end
	end
end

function UI.Form:createForm()
	self.children = self.children or { }

	if not self.labelWidth then
		self.labelWidth = 1
		for _, child in pairs(self) do
			if type(child) == 'table' and child.UIElement then
				if child.formLabel then
					self.labelWidth = math.max(self.labelWidth, #child.formLabel + 2)
				end
			end
		end
	end

	local y = self.margin
	for _, child in pairs(self) do
		if type(child) == 'table' and child.UIElement then
			if child.formKey then
				child.value = self.values[child.formKey]
			end
			if child.formLabel then
				child.x = self.labelWidth + self.margin - 1
				child.y = child.formIndex and (child.formIndex + self.margin - 1) or y
				if not child.width and not child.ex then
					child.ex = -self.margin
				end

				table.insert(self.children, UI.Text {
					x = self.margin,
					y = child.y,
					textColor = 'black',
					width = #child.formLabel,
					value = child.formLabel,
				})
			end
			if child.formLabel then
				y = y + 1
			end
		end
	end

	if not self.manualControls then
		table.insert(self.children, UI.Button {
			y = -self.margin, x = -12 - self.margin,
			text = 'Ok',
			event = 'form_ok',
		})
		table.insert(self.children, UI.Button {
			y = -self.margin, x = -7 - self.margin,
			text = 'Cancel',
			event = self.cancelEvent,
		})
	end
end

function UI.Form:validateField(field)
	if field.required then
		if not field.value or #tostring(field.value) == 0 then
			return false, 'Field is required'
		end
	end
	return true
end

function UI.Form:save()
	for _,child in pairs(self.children) do
		if child.formKey then
			local s, m = self:validateField(child)
			if not s then
				self:setFocus(child)
				Sound.play('entity.villager.no', .5)
				self:emit({ type = 'form_invalid', message = m, field = child })
				return false
			end
		end
	end
	for _,child in pairs(self.children) do
		if child.formKey then
			self.values[child.formKey] = child.value
		end
	end

	return true
end

function UI.Form:eventHandler(event)
	if event.type == 'form_ok' then
		if not self:save() then
			return false
		end
		self:emit({ type = self.event, UIElement = self, values = self.values })
	else
		return UI.Window.eventHandler(self, event)
	end
	return true
end

function UI.Form.example()
	return UI.Form {
		x = 2, ex = -2, y = 2,
		ptype = UI.Chooser {
			formLabel = 'Type', formKey = 'type', formIndex = 1,
			width = 10,
			choices = {
				{ name = 'Modem', value = 'wireless_modem' },
				{ name = 'Drive', value = 'disk_drive'     },
			},
		},
		drive_id = UI.TextEntry {
			formLabel = 'Drive', formKey = 'drive_id', formIndex = 2,
			required = true,
			width = 5,
			transform = 'number',
		},
	}
end
