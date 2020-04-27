local Ansi   = require('opus.ansi')
local Config = require('opus.config')
local UI     = require('opus.ui')

if _G.http.websocket then
	local config = Config.load('cloud')

	local tab = UI.Tab {
		title = 'Cloud',
		description = 'Cloud Catcher options',
		[1] = UI.Window {
			x = 2, y = 2, ex = -2, ey = 4,
		},
		key = UI.TextEntry {
			x = 3, ex = -3, y = 3,
			limit = 32,
			value = config.key,
			shadowText = 'Cloud key',
			accelerators = {
				enter = 'update_key',
			},
		},
		button = UI.Button {
			x = -8, ex = -2, y = -2,
			text = 'Apply',
			event = 'update_key',
		},
		labelText = UI.TextArea {
			x = 2, ex = -2, y = 5, ey = -4,
			textColor = 'yellow',
			backgroundColor = 'black',
			marginLeft = 1, marginRight = 1, marginTop = 1,
			value = string.format(
[[Use a non-changing cloud key. Note that only a single computer can use this session at one time.
To obtain a key, visit:
%shttps://cloud-catcher.squiddev.cc%s then bookmark:
%shttps://cloud-catcher.squiddev.cc/?id=KEY
		]],
			Ansi.white, Ansi.reset, Ansi.white),
		},
	}

	function tab:eventHandler(event)
		if event.type == 'update_key' then
			if self.key.value then
				config.key = self.key.value
			else
				config.key = nil
			end
			Config.update('cloud', config)
			self:emit({ type = 'success_message', message = 'Updated' })
		end
	end

	return tab
end

