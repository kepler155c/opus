local Logger = require('logger')

local Profile = { 
  start = function() end,
  stop = function() end,
  display = function() end,
  methods = { },
}
 
local function Profile_display()
  Logger.log('profile', 'Profiling results')
  for k,v in pairs(Profile.methods) do
    Logger.log('profile', '%s: %f %d %f',
      k, Util.round(v.elapsed, 2), v.count, Util.round(v.elapsed/v.count, 2))
  end
  Profile.methods = { }
end
 
local function Profile_start(name)
  local p = Profile.methods[name]
  if not p then
    p = { }
    p.elapsed = 0
    p.count = 0
    Profile.methods[name] = p
  end
  p.clock = os.clock()
  return p
end
 
local function Profile_stop(name)
  local p = Profile.methods[name]
  p.elapsed = p.elapsed + (os.clock() - p.clock)
  p.count = p.count + 1
end
 
function Profile.enable()
  Logger.log('profile', 'Profiling enabled')
  Profile.start = Profile_start
  Profile.stop = Profile_stop
  Profile.display = Profile_display
end
 
function Profile.disable()
  Profile.start = function() end
  Profile.stop = function() end
  Profile.display = function() end
end

return Profile
