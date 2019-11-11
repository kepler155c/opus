local class = require('opus.class')
local UI    = require('opus.ui')
local Util  = require('opus.util')

UI.Tabs = class(UI.Window)
UI.Tabs.defaults = {
	UIElement = 'Tabs',
}
function UI.Tabs:postInit()
	self:add(self)
end

function UI.Tabs:add(children)
	local buttons = { }
	for _,child in pairs(children) do
		if type(child) == 'table' and child.UIElement and child.tabTitle then
			child.y = 2
			table.insert(buttons, {
				text = child.tabTitle,
				event = 'tab_select',
				tabUid = child.uid,
			})
		end
	end

	if not self.tabBar then
		self.tabBar = UI.TabBar({
			buttons = buttons,
		})
	else
		self.tabBar:addButtons(buttons)
	end

	if self.parent then
		return UI.Window.add(self, children)
	end
end

function UI.Tabs:selectTab(tab)
	local menuItem = Util.find(self.tabBar.children, 'tabUid', tab.uid)
	if menuItem then
		self.tabBar:emit({ type = 'tab_select', button = { uid = menuItem.uid } })
	end
end

function UI.Tabs:setActive(tab, active)
	local menuItem = Util.find(self.tabBar.children, 'tabUid', tab.uid)
	if menuItem then
		menuItem.inactive = not active
	end
end

function UI.Tabs:enable()
	self.enabled = true
	self.transitionHint = nil
	self.tabBar:enable()

	local menuItem = Util.find(self.tabBar.children, 'selected', true)

	for _,child in pairs(self.children) do
		if child.uid == menuItem.tabUid then
			child:enable()
			self:emit({ type = 'tab_activate', activated = child })
		elseif child.tabTitle then
			child:disable()
		end
	end
end

function UI.Tabs:eventHandler(event)
	if event.type == 'tab_change' then
		local tab = self:find(event.tab.tabUid)
		if event.current > event.last then
			self.transitionHint = 'slideLeft'
		else
			self.transitionHint = 'slideRight'
		end

		for _,child in pairs(self.children) do
			if child.uid == event.tab.tabUid then
				child:enable()
			elseif child.tabTitle then
				child:disable()
			end
		end
		self:emit({ type = 'tab_activate', activated = tab })
		tab:draw()
	end
end
