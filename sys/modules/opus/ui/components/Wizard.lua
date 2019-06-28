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
	--for _, child in pairs(self.pages) do
	--	child.ey = -2
	--end
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
	self.transitionHint = nil
	local initial = self:getPage(1)
	for _,child in pairs(self.children) do
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

		if event.current then
			if event.next then
				self.transitionHint = 'slideLeft'
			elseif event.prev then
				self.transitionHint = 'slideRight'
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
		current:enable()
		current:emit({ type = 'view_enabled', view = current })
		self:draw()
	end
end
