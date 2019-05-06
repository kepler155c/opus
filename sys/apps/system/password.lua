local Security = require('security')
local SHA2     = require('crypto.sha2')
local UI       = require('ui')

local colors   = _G.colors

local passwordTab = UI.Tab {
	tabTitle = 'Password',
	description = 'Wireless network password',
	oldPass = UI.TextEntry {
		x = 3, ex = -3, y = 2,
		limit = 32,
		mask = true,
		shadowText = 'old password',
		inactive = not Security.getPassword(),
	},
	newPass = UI.TextEntry {
		x = 3, ex = -3, y = 3,
		limit = 32,
		mask = true,
		shadowText = 'new password',
		accelerators = {
			enter = 'new_password',
		},
	},
	button = UI.Button {
		x = 3, y = 5,
		text = 'Update',
		event = 'update_password',
	},
	info = UI.TextArea {
		x = 3, ex = -3, y = 7,
		textColor = colors.yellow,
		inactive = true,
		value = 'Add a password to enable other computers to connect to this one.',
	}
}
function passwordTab:eventHandler(event)
	if event.type == 'update_password' then
		if #self.newPass.value == 0 then
			self:emit({ type = 'error_message', message = 'Invalid password' })

		elseif Security.getPassword() and not Security.verifyPassword(SHA2.digest(self.oldPass.value):toHex()) then
			self:emit({ type = 'error_message', message = 'Passwords do not match' })

		else
			Security.updatePassword(SHA2.digest(self.newPass.value):toHex())
			self.oldPass.inactive = false
			self:emit({ type = 'success_message', message = 'Password updated' })
		end
		return true
	end
end

return passwordTab
