local Config = require('opus.config')
local UI     = require('opus.ui')

local colors = _G.colors
local fs     = _G.fs

local config = Config.load('multishell')

local tab = UI.Tab {
	tabTitle = 'Launcher',
	description = 'Set the application launcher',
	launcherLabel = UI.Text {
		x = 3, y = 2,
		value = 'Launcher',
	},
	launcher = UI.Chooser {
		x = 13, y = 2, width = 12,
		choices = {
			{ name = 'Overview', value = 'sys/apps/Overview.lua' },
			{ name = 'Shell',    value = 'sys/apps/ShellLauncher.lua'    },
			{ name = 'Custom',   value = 'custom'                },
		},
	},
	custom = UI.TextEntry {
		x = 13, ex = -3, y = 3,
		limit = 128,
		shadowText = 'File name',
	},
	button = UI.Button {
		x = 3, y = 5,
		text = 'Update',
		event = 'update',
	},
	labelText = UI.TextArea {
		x = 3, ex = -3, y = 7,
		textColor = colors.yellow,
		value = 'Choose an application launcher',
	},
}

function tab:enable()
	local launcher = config.launcher and 'custom' or 'sys/apps/Overview.lua'

	for _, v in pairs(self.launcher.choices) do
		if v.value == config.launcher then
			launcher = v.value
			break
		end
	end

	UI.Tab.enable(self)

	self.launcher.value = launcher
	self.custom.enabled = launcher == 'custom'
end

function tab:eventHandler(event)
	if event.type == 'choice_change' then
		self.custom.enabled = event.value == 'custom'
		if self.custom.enabled then
			self.custom.value = config.launcher
		end
		self:draw()

	elseif event.type == 'update' then
		local launcher

		if self.launcher.value ~= 'custom' then
			launcher = self.launcher.value
		elseif fs.exists(self.custom.value) and not fs.isDir(self.custom.value) then
			launcher = self.custom.value
		end

		if launcher then
			config.launcher = launcher
			Config.update('multishell', config)
			self:emit({ type = 'success_message', message = 'Updated' })
		else
			self:emit({ type = 'error_message', message = 'Invalid file' })
		end
	end
end

return tab
