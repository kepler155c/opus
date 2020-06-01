local fs = _G.fs

local linkfs = { }

-- TODO: implement broken links

local methods = { 'exists', 'getFreeSpace', 'getSize', 'attributes',
	'isDir', 'isReadOnly', 'list', 'makeDir', 'open', 'getDrive' }

for _,m in pairs(methods) do
	linkfs[m] = function(node, dir, ...)
		dir = linkfs.resolve(node, dir)
		return fs[m](dir, ...)
	end
end

function linkfs.resolve(node, dir)
	return dir:gsub(node.mountPoint, node.source, 1)
end

function linkfs.mount(path, source)
	if not source then
		error('Source is required')
	end
	source = fs.combine(source, '')
	if not fs.exists(source) then
		error('Source is missing')
	end
	if path == source then
		return
	end
	if fs.isDir(source) then
		return {
			source = source,
			nodes = { },
		}
	end
	return {
		source = source
	}
end

function linkfs.copy(node, s, t)
	s = s:gsub(node.mountPoint, node.source, 1)
	t = t:gsub(node.mountPoint, node.source, 1)
	return fs.copy(s, t)
end

function linkfs.delete(node, dir)
	if dir == node.mountPoint then
		fs.unmount(node.mountPoint)
	else
		dir = dir:gsub(node.mountPoint, node.source, 1)
		return fs.delete(dir)
	end
end

function linkfs.find(node, spec)
	spec = spec:gsub(node.mountPoint, node.source, 1)

	local list = fs.find(spec)
	for k,f in ipairs(list) do
		list[k] = f:gsub(node.source, node.mountPoint, 1)
	end

	return list
end

function linkfs.move(node, s, t)
	s = s:gsub(node.mountPoint, node.source, 1)
	t = t:gsub(node.mountPoint, node.source, 1)
	return fs.move(s, t)
end

return linkfs