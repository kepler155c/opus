local UI = require('ui')

local device     = _G.device
local peripheral = _G.peripheral
local settings   = _G.settings

local tab = UI.Tab {
	tabTitle = 'Kiosk',
	description = 'Kiosk options',
	form = UI.Form {
		x = 2,
		manualControls = true,
		monitor = UI.Chooser {
			formLabel = 'Monitor', formKey = 'monitor',
		},
		textScale = UI.Chooser {
      formLabel = 'Font Size', formKey = 'textScale',
      nochoice = 'Small',
      choices = {
        { name = 'Small', value = '.5' },
        { name = 'Large', value = '1'  },
      },
      help = 'Adjust text scaling',
		},
	},
}

function tab:enable()
	local choices = {	}

	for _,v in pairs(device) do
		if v.type == 'monitor' then
			table.insert(choices, { name = v.side, value = v.side })
		end
	end

	self.form.monitor.choices = choices
	self.form.monitor.value = settings.get('kiosk.monitor')

	self.form.textScale.value = settings.get('kiosk.textscale')

	UI.Tab.enable(self)
end

function tab:eventHandler(event)
	if event.type == 'choice_change' then
		if self.form.monitor.value then
			settings.set('kiosk.monitor', self.form.monitor.value)
		end
		if self.form.textScale.value then
			settings.set('kiosk.textscale', self.form.textScale.value)
		end
		settings.save('.settings')
	end
end

if peripheral.find('monitor') then
	return tab
end
