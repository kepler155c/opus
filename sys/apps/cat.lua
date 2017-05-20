local args = { ... }
if #args < 1 then
  error('cat <filename>')
end

local fileName = shell.resolve(args[1])
if not fs.exists(fileName) then
  error('not a file: ' .. args[1])
end

local file = fs.open(fileName, 'r')
if not file then
  error('unable to open ' .. args[1])
end

while true do
  local line = file.readLine()
  if not line then
    break
  end
  print(line)
end

file.close()