local args = { ... }
local options = ''
for _,v in pairs(args) do
  options = options .. ' ' .. v
end
shell.run('pastebin run sj4VMVJj' .. options)