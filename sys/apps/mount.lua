local args = { ... }

local target = table.remove(args, 1)
target = shell.resolve(target)

fs.mount(target, table.unpack(args))
