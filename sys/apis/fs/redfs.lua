--[[
	Mount a readonly file system from another computer across rednet. The
	target computer must be running OpusOS or redserver.

	Syntax:
	rn://<id>/directory/subdir

	Examples:
	rn://12/usr/etc
	rn://8/usr
]]--

local rttp = require('rttp')

local fs     = _G.fs

local redfs = { }

local function getListing(uri)
	local success, response = rttp.get(uri .. '?recursive=true')

	if not success then
		error(response)
	end

	if response.statusCode ~= 200 then
		error('Received response ' .. response.statusCode)
	end

	local list = { }
	for _,v in pairs(response.data) do
		if not v.isDir then
			list[v.path] = {
				url = uri .. '/' .. v.path,
				size = v.size,
			}
		end
	end

	return list
end

function redfs.mount(dir, uri)
	if not uri then
		error('redfs syntax: uri')
	end

	local list = getListing(uri)
	for path, entry in pairs(list) do
		if not fs.exists(fs.combine(dir, path)) then
			local node = fs.mount(fs.combine(dir, path), 'urlfs', entry.url)
			node.size = entry.size
		end
	end
end

return redfs
