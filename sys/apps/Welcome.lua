local Ansi     = require('opus.ansi')
local Security = require('opus.security')
local SHA      = require('opus.crypto.sha2')
local UI       = require('opus.ui')

local colors   = _G.colors
local os       = _G.os
local shell    = _ENV.shell

local splashIntro = [[First Time Setup

%sThanks for installing Opus OS. The next screens will prompt you for basic settings for this computer.]]
local labelIntro = [[Set a friendly name for this computer.

%sNo spaces recommended.]]
local passwordIntro = [[A password is required for wireless access.

%sLeave blank to skip.]]
local packagesIntro = [[Setup Complete

%sOpen the package manager to add software to this computer.]]
local contributorsIntro = [[Contributors%s

Anavrins:    Encryption/security/custom apps
Community:   Several selected applications
hugeblank:   Startup screen improvements
LDDestroier: Art design + custom apps
Lemmmy:      Application improvements

%sContribute at:%s
https://github.com/kepler155c/opus]]

local page = UI.Page {
	wizard = UI.Wizard {
		ey = -2,
		splash = UI.WizardPage {
			index = 1,
			intro = UI.TextArea {
				textColor = colors.yellow,
				inactive = true,
				x = 3, ex = -3, y = 2, ey = -2,
				value = string.format(splashIntro, Ansi.white),
			},
		},
		label = UI.WizardPage {
			index = 2,
			labelText = UI.Text {
				x = 3, y = 2,
				value = 'Label'
			},
			label = UI.TextEntry {
				x = 9, y = 2, ex = -3,
				limit = 32,
				value = os.getComputerLabel(),
			},
			intro = UI.TextArea {
				textColor = colors.yellow,
				inactive = true,
				x = 3, ex = -3, y = 4, ey = -3,
				value = string.format(labelIntro, Ansi.white),
			},
			validate = function (self)
				if self.label.value then
					os.setComputerLabel(self.label.value)
				end
				return true
			end,
		},
		password = UI.WizardPage {
			index = 3,
			passwordLabel = UI.Text {
				x = 3, y = 2,
				value = 'Password'
			},
			newPass = UI.TextEntry {
				x = 12, ex = -3, y = 2,
				limit = 32,
				mask = true,
				shadowText = 'password',
			},
			intro = UI.TextArea {
				textColor = colors.yellow,
				inactive = true,
				x = 3, ex = -3, y = 5, ey = -3,
				value = string.format(passwordIntro, Ansi.white),
			},
			validate = function (self)
				if type(self.newPass.value) == "string" and #self.newPass.value > 0 then
					Security.updatePassword(SHA.compute(self.newPass.value))
				end
				return true
			end,
		},
		packages = UI.WizardPage {
			index = 4,
			button = UI.Button {
				x = 3, y = -3,
				text = 'Open Package Manager',
				event = 'packages',
			},
			intro = UI.TextArea {
				textColor = colors.yellow,
				inactive = true,
				x = 3, ex = -3, y = 2, ey = -4,
				value = string.format(packagesIntro, Ansi.white),
			},
		},
		contributors = UI.WizardPage {
			index = 5,
			intro = UI.TextArea {
				textColor = colors.yellow,
				inactive = true,
				x = 3, ex = -3, y = 2, ey = -2,
				value = string.format(contributorsIntro, Ansi.white, Ansi.yellow, Ansi.white),
			},
		},
	},
	notification = UI.Notification { },
}

function page:eventHandler(event)
	if event.type == 'skip' then
		self.wizard:emit({ type = 'nextView' })

	elseif event.type == 'view_enabled' then
		event.view:focusFirst()

	elseif event.type == 'packages' then
		shell.openForegroundTab('PackageManager')

	elseif event.type == 'wizard_complete' or event.type == 'cancel' then
		UI:quit()

	else
		return UI.Page.eventHandler(self, event)
	end
	return true
end

UI:setPage(page)
UI:start()
