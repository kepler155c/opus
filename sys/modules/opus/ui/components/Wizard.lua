local class = require('opus.class')
local UI    = require('opus.ui')
local Util  = require('opus.util')

UI.Wizard = class(UI.Window)
UI.Wizard.defaults = {
	UIElement = 'Wizard',
	pages = { },
}
function UI.Wizard:postInit()
	self.cancelButton = UI.Button {
		x = 2, y = -1,
		text = 'Cancel',
		event = 'cancel',
	}
	self.previousButton = UI.Button {
		x = -18, y = -1,
		text = '< Back',
		event = 'previousView',
	}
	self.nextButton = UI.Button {
		x = -9, y = -1,
		text = 'Next >',
		event = 'nextView',
	}

	Util.merge(self, self.pages)
end

function UI.Wizard:add(pages)
	Util.merge(self.pages, pages)
	Util.merge(self, pages)

	for _, child in pairs(self.pages) do
		child.ey = child.ey or -2
	end

	if self.parent then
		self:initChildren()
	end
end

function UI.Wizard:getPage(index)
	return Util.find(self.pages, 'index', index)
end

function UI.Wizard:enable(...)
	self.enabled = true
	self.index = 1
	local initial = self:getPage(1)
	for child in self:eachChild() do
		if child == initial or not child.index then
			child:enable(...)
		else
			child:disable()
		end
	end
	self:emit({ type = 'enable_view', next = initial })
end

function UI.Wizard:isViewValid()
	local currentView = self:getPage(self.index)
	return not currentView.validate and true or currentView:validate()
end

function UI.Wizard:eventHandler(event)
	if event.type == 'nextView' then
		local currentView = self:getPage(self.index)
		if self:isViewValid() then
			self.index = self.index + 1
			local nextView = self:getPage(self.index)
			currentView:emit({ type = 'enable_view', next = nextView, current = currentView })
		end

	elseif event.type == 'previousView' then
		local currentView = self:getPage(self.index)
		local nextView = self:getPage(self.index - 1)
		if nextView then
			self.index = self.index - 1
			currentView:emit({ type = 'enable_view', prev = nextView, current = currentView })
		end
		return true

	elseif event.type == 'wizard_complete' then
		if self:isViewValid() then
			self:emit({ type = 'accept' })
		end

	elseif event.type == 'enable_view' then
		local current = event.next or event.prev
		if not current then error('property "index" is required on wizard pages') end
		local hint

		if event.current then
			if event.next then
				hint = 'slideLeft'
			elseif event.prev then
				hint = 'slideRight'
			end
			event.current:disable()
		end

		if self:getPage(self.index - 1) then
			self.previousButton:enable()
		else
			self.previousButton:disable()
		end

		if self:getPage(self.index + 1) then
			self.nextButton.text = 'Next >'
			self.nextButton.event = 'nextView'
		else
			self.nextButton.text = 'Accept'
			self.nextButton.event = 'wizard_complete'
		end
		-- a new current view
		current.transitionHint = hint
		current:enable()
		current:emit({ type = 'view_enabled', view = current })
		self:draw()
	end
end

function UI.Wizard.example()
	return UI.Wizard {
		ey = -2,
		pages = {
			splash = UI.WizardPage {
				index = 1,
				intro = UI.TextArea {
					inactive = true,
					x = 3, ex = -3, y = 2, ey = -2,
					value = 'sample text',
				},
			},
			label = UI.WizardPage {
				index = 2,
				intro = UI.TextArea {
					inactive = true,
					x = 3, ex = -3, y = 2, ey = -2,
					value = 'sample more text',
				},
			},
			password = UI.WizardPage {
				index = 3,
				text = UI.TextEntry {
					x = 12, ex = -3, y = 2,
					shadowText = 'tet',
				},
			},
		},
	}
end
