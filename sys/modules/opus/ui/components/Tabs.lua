local class = require('opus.class')
local UI    = require('opus.ui')
local Util  = require('opus.util')

UI.Tabs = class(UI.Window)
UI.Tabs.docs = { }
UI.Tabs.defaults = {
	UIElement = 'Tabs',
	selectedBackgroundColor = 'primary',
	unselectedBackgroundColor = 'tertiary',
	unselectedTextColor = 'lightGray',
	selectedTextColor = 'black',
}
function UI.Tabs:postInit()
	self:add(self)
end

function UI.Tabs:add(children)
	local buttons = { }
	for _,child in pairs(children) do
		if type(child) == 'table' and child.UIElement and child.UIElement == 'Tab' then
			child.y = 2
			table.insert(buttons, {
				index = child.index,
				text = child.title,
				event = 'tab_select',
				tabUid = child.uid,
			})
		end
	end

	if not self.tabBar then
		self.tabBar = UI.TabBar({
			buttons = buttons,
			backgroundColor = self.barBackgroundColor,
		})
	else
		self.tabBar:addButtons(buttons)
	end

	if self.parent then
		local enabled = self.enabled

		-- don't enable children upon add
		self.enabled = nil
		UI.Window.add(self, children)
		self.enabled = enabled
	end
end

UI.Tabs.docs.selectTab = [[selectTab(TAB)
Make to the passed tab active.]]
function UI.Tabs:selectTab(tab)
	local menuItem = Util.find(self.tabBar.children, 'tabUid', tab.uid)
	if menuItem then
		if self.enabled then
			self.tabBar:emit({ type = 'tab_select', button = { uid = menuItem.uid } })
		else
			local previous = Util.find(self.tabBar.children, 'selected', true)
			if previous then
				previous.selected = false
			end
			menuItem.selected = true
		end
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
	self.tabBar:enable()

	local menuItem = Util.find(self.tabBar.children, 'selected', true)
	self:enableTab(menuItem.tabUid)
end

function UI.Tabs:enableTab(tabUid, hint)
	for child in self:eachChild() do
		child.transitionHint = hint
		if child.uid == tabUid then
			if not child.enabled then
				child:enable()
			end
		elseif child.UIElement == 'Tab' then
			if child.enabled then
				child:disable()
			end
		end
	end
end

function UI.Tabs:eventHandler(event)
	if event.type == 'tab_change' then
		local tab = self:find(event.tab.tabUid)
		local hint = event.current > event.last and 'slideLeft' or 'slideRight'

		self:enableTab(event.tab.tabUid, hint)
		tab:draw()
		return true
	end
end

function UI.Tabs.example()
	return UI.Tabs {
		tab1 = UI.Tab {
			index = 1,
			title = 'tab1',
			entry = UI.TextEntry { y = 3, shadowText = 'text' },
		},
		tab2 = UI.Tab {
			index = 2,
			title = 'tab2',
			subtabs = UI.Tabs {
				x = 3, y = 2, ex = -3, ey = -2,
				tab1 = UI.Tab {
					index = 1,
					title = 'tab4',
					entry = UI.TextEntry { y = 3, shadowText = 'text' },
				},
				tab3 = UI.Tab {
					index = 2,
					title = 'tab5',
				},
			},
		},
		tab3 = UI.Tab {
			index = 3,
			title = 'tab3',
		},
		enable = function(self)
			UI.Tabs.enable(self)
			self:setActive(self.tab3, false)
		end,
	}
end
