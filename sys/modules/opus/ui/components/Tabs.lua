local class = require('opus.class')
local UI    = require('opus.ui')
local Util  = require('opus.util')

UI.Tabs = class(UI.Window)
UI.Tabs.docs = { }
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
				index = child.index,
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
		UI.Window.add(self, children)
	end
end

UI.Tabs.docs.selectTab = [[selectTab(TAB)
Make to the passed tab active.]]
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
	self.tabBar:enable()

	local menuItem = Util.find(self.tabBar.children, 'selected', true)

	for child in self:eachChild() do
		child.transitionHint = nil
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
		local hint = event.current > event.last and 'slideLeft' or 'slideRight'

		for child in self:eachChild() do
			if child.uid == event.tab.tabUid then
				child.transitionHint = hint
				child:enable()
			elseif child.tabTitle then
				child:disable()
			end
		end
		self:emit({ type = 'tab_activate', activated = tab })
		tab:draw()
		return true
	end
end

function UI.Tabs.example()
	return UI.Tabs {
		tab1 = UI.Tab {
			index = 1,
			tabTitle = 'tab1',
			entry = UI.TextEntry { y = 3, shadowText = 'text' },
		},
		tab2 = UI.Tab {
			index = 2,
			tabTitle = 'tab2',
			subtabs = UI.Tabs {
				x = 3, y = 2, ex = -3, ey = -2,
				tab1 = UI.Tab {
					index = 1,
					tabTitle = 'tab4',
					entry = UI.TextEntry { y = 3, shadowText = 'text' },
				},
				tab3 = UI.Tab {
					index = 2,
					tabTitle = 'tab5',
				},
			},
		},
		tab3 = UI.Tab {
			index = 3,
			tabTitle = 'tab3',
		},
	}
end
