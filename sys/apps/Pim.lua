requireInjector(getfenv(1))

local Config = require('config')
local Event  = require('event')
local UI     = require('ui') 
local Util   = require('util')

multishell.setTitle(multishell.getCurrent(), 'PIM')

local inventory = { }
local mode = 'sync'

if not device.pim then
  error('PIM not attached')
end

local page = UI.Page({
  menu = UI.Menu({
    centered = true,
    y = 2,
    menuItems = {
      { prompt = 'Learn', event = 'learn', help = '' },
    },
  }),
  statusBar = UI.StatusBar({
    columns = {
      { 'Status', 'status', UI.term.width - 7 },
      { 'Mode', 'mode', 7 }
    }
  }),
  accelerators = {
    q = 'quit',
  },
})

local function learn()
  if device.pim.getInventorySize() > 0 then
	local stacks = device.pim.getAllStacks(false)
    Config.update('pim', stacks)
    mode = 'sync'
    page.statusBar:setValue('status', 'Learned inventory')
  end
  page.statusBar:setValue('mode', mode)
  page.statusBar:draw()
end

function page:eventHandler(event)

  if event.type == 'learn' then
  	mode = 'learn'
  	learn()
  elseif event.type == 'quit' then
  	Event.exitPullEvents()
  end

  return UI.Page.eventHandler(self, event)
end

local function inInventory(s)
  for _,i in pairs(inventory) do
  	if i.id == s.id then
  	  return true
  	end
  end
end

local function pimWatcher()
  local playerOn = false

  while true do
  	if device.pim.getInventorySize() > 0 and not playerOn then
  	  playerOn = true
	  
	  if mode == 'learn' then
	  	learn()

	  else
	  	local stacks = device.pim.getAllStacks(false)
	  	for k,stack in pairs(stacks) do
	  	  if not inInventory(stack) then
	  	  	device.pim.pushItem('down', k, stack.qty)
          end
	  	end
	  	page.statusBar:setValue('status', 'Synchronized')
  	    page.statusBar:draw()
	  end
	
	elseif device.pim.getInventorySize() == 0 and playerOn then
	  page.statusBar:setValue('status', 'No player')
  	  page.statusBar:draw()
	  playerOn = false
	end
	os.sleep(1)
  end
end

Config.load('pim', inventory)

if Util.empty(inventory) then
  mode = 'learn'
end
page.statusBar:setValue('mode', mode)

UI:setPage(page)

Event.pullEvents(pimWatcher)
UI.term:reset()
