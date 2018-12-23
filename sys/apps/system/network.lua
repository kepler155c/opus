local Config = require('config')
local UI     = require('ui')

local device = _G.device

local tab = UI.Window {
	tabTitle = 'Network',
	description = 'Networking options',
	form = UI.Form {
		x = 2,
		manualControls = true,
		modem = UI.Chooser {
			formLabel = 'Modem', formKey = 'modem',
			nochoice = 'auto',
		},
		update = UI.Button {
			x = 9, y = 4,
			text = 'Update', event = 'form_complete',
		},
	},
}

function tab:enable()
	local width = 7
	local choices = {
		{ name = 'auto',    value = 'auto' },
		{ name = 'disable', value = 'none' },
	}

	for k,v in pairs(device) do
		if v.isWireless and v.isWireless() and k ~= 'wireless_modem' then
			table.insert(choices, { name = k, value = v.name })
			width = math.max(width, #k)
		end
	end

	self.form.modem.choices = choices
	self.form.modem.width = width + 4

	local config = Config.load('os')
	self.form.modem.value = config.wirelessModem or 'auto'

	UI.Window.enable(self)
end

function tab:eventHandler(event)
	if event.type == 'form_complete' then
		local config = Config.load('os')
		config.wirelessModem = self.form.modem.value
		Config.update('os', config)
		self:emit({ type = 'success_message', message = 'reboot to take effect' })
		return true
	end
end

return tab
