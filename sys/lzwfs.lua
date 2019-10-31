-- see: https://github.com/Rochet2/lualzw
-- MIT License - Copyright (c) 2016 Rochet2

-- Transparent file system compression for non-binary files using lzw

-- Files that are compressed will have the first bytes in file set to 'LZWC'.
-- If a file does not benefit from compression, the contents will not be altered.

-- Allow exclusions for files that shouldn't be compressed
-- Also allow for future types of exclusions using bit operations
-- 1 is reserved for compression exclusion
--    fs.addException('startup.lua', 1)

-- To renable compression for a file 
--    fs.removeException('startup.lua', 1)

-- Restores file system
--    fs.restore()

local char    = string.char
local type    = type
local sub     = string.sub
local tconcat = table.concat
local tinsert = table.insert

local SIGC = 'LZWC'
local IGNORE_COMPRESSION = 1 -- support other bits as well

local basedictcompress = {}
local basedictdecompress = {}
for i = 0, 255 do
    local ic, iic = char(i), char(i, 0)
    basedictcompress[ic] = iic
    basedictdecompress[iic] = ic
end

local native = { open = fs.open }
fs.exceptions = fs.exceptions or { }

local function dictAddA(str, dict, a, b)
    if a >= 256 then
        a, b = 0, b+1
        if b >= 256 then
            dict = {}
            b = 1
        end
    end
    dict[str] = char(a,b)
    a = a+1
    return dict, a, b
end

local function compress(input)
    if type(input) ~= "string" then
        error ("string expected, got "..type(input))
    end
    local len = #input
    if len <= 1 then
        return input
    end

    local dict = {}
    local a, b = 0, 1

    local result = { SIGC }
    local resultlen = 1
    local n = 2
    local word = ""
    for i = 1, len do
        local c = sub(input, i, i)
        local wc = word..c
        if not (basedictcompress[wc] or dict[wc]) then
            local write = basedictcompress[word] or dict[word]
            if not write then
                error "algorithm error, could not fetch word"
            end
            result[n] = write
            resultlen = resultlen + #write
            n = n+1
            if  len <= resultlen then
                return input
            end
            dict, a, b = dictAddA(wc, dict, a, b)
            word = c
        else
            word = wc
        end
    end
    result[n] = basedictcompress[word] or dict[word]
    resultlen = resultlen+#result[n]
    if  len <= resultlen then
        return input
    end
    return tconcat(result)
end

local function dictAddB(str, dict, a, b)
    if a >= 256 then
        a, b = 0, b+1
        if b >= 256 then
            dict = {}
            b = 1
        end
    end
    dict[char(a,b)] = str
    a = a+1
    return dict, a, b
end

local function decompress(input)
    if type(input) ~= "string" then
        error( "string expected, got "..type(input))
    end

    if #input <= 1 then
        return input
    end

    local control = sub(input, 1, 4)
    if control ~= SIGC then
        return input
    end
    input = sub(input, 5)
    local len = #input

    if len < 2 then
        error("invalid input - not a compressed string")
    end

    local dict = {}
    local a, b = 0, 1

    local result = {}
    local n = 1
    local last = sub(input, 1, 2)
    result[n] = basedictdecompress[last] or dict[last]
    n = n+1
    for i = 3, len, 2 do
        local code = sub(input, i, i+1)
        local lastStr = basedictdecompress[last] or dict[last]
        if not lastStr then
            error( "could not find last from dict. Invalid input?")
        end
        local toAdd = basedictdecompress[code] or dict[code]
        if toAdd then
            result[n] = toAdd
            n = n+1
            dict, a, b = dictAddB(lastStr..sub(toAdd, 1, 1), dict, a, b)
        else
            local tmp = lastStr..sub(lastStr, 1, 1)
            result[n] = tmp
            n = n+1
            dict, a, b = dictAddB(tmp, dict, a, b)
        end
        last = code
    end
    return tconcat(result)
end

function split(str, pattern)
	pattern = pattern or "(.-)\n"
	local t = {}
	local function helper(line) tinsert(t, line) return "" end
	helper((str:gsub(pattern, helper)))
	return t
end

function fs.open(fname, flags)
    if flags == 'r' then
        local f, err = native.open(fname, 'rb')
        if not f then
            return f, err
        end

		local ctr = 0
		local lines
		return {
			readLine = function()
				if not lines then
                    lines = split(decompress(f.readAll()))
				end
				ctr = ctr + 1
				return lines[ctr]
			end,
			readAll = function()
				return decompress(f.readAll())
			end,
            close = function()
                f.close()
			end,
        }
    elseif flags == 'w' or flags == 'a' then
        if bit.band(fs.exceptions[fs.combine(fname, '')] or 0, IGNORE_COMPRESSION) == IGNORE_COMPRESSION then
            return native.open(fname, flags)
        end

        local c = { }

        if flags == 'a' then
            local f = fs.open(fname, 'r')
            if f then
                tinsert(c, f.readAll())
                f.close()
            end
        end

        local f, err = native.open(fname, 'wb')
        if not f then
            return f, err
        end

        return {
            write = function(str)
                tinsert(c, str)
			end,
			writeLine = function(str)
                tinsert(c, str)
                tinsert(c, '\n')
			end,
            flush = function()
                -- this isn't gonna work...
                // f.write(compress(tconcat(c)))
                f.flush();
			end,
            close = function()
                f.write(compress(tconcat(c)))
                f.close()
			end,
		}
    end

    return native.open(fname, flags)
end

function fs.addException(fname, mode)
    fname = fs.combine(fname, '')
    fs.exceptions[fname] = bit.bor(fs.exceptions[fname] or 0, mode)
end

function fs.removeException(fname, mode)
    fname = fs.combine(fname, '')
    fs.exceptions[fname] = bit.bxor(fs.exceptions[fname] or 0, mode)
end

function fs.restore()
    fs.open = native.open
end
