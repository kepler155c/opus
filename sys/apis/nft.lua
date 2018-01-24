local Util = require('util')

local NFT = { }

-- largely copied from http://www.computercraft.info/forums2/index.php?/topic/5029-145-npaintpro/

local tColourLookup = { }
for n = 1, 16 do
	tColourLookup[string.byte("0123456789abcdef", n, n)] = 2 ^ (n - 1)
end

local function getColourOf(hex)
	return tColourLookup[hex:byte()]
end

function NFT.parse(imageText)
	local image = {
		fg   = { },
		bg   = { },
		text = { },
	}

	local num = 1
	local lines = Util.split(imageText)
	while #lines[#lines] == 0 do
		table.remove(lines, #lines)
	end

	for _,sLine in ipairs(lines) do
		table.insert(image.fg, { })
		table.insert(image.bg, { })
		table.insert(image.text, { })

		--As we're no longer 1-1, we keep track of what index to write to
		local writeIndex = 1
		--Tells us if we've hit a 30 or 31 (BG and FG respectively)- next char specifies the curr colour
		local bgNext, fgNext = false, false
		--The current background and foreground colours
		local currBG, currFG = nil,nil
		for i = 1, #sLine do
			local nextChar = string.sub(sLine, i, i)
			if nextChar:byte() == 30 then
				bgNext = true
			elseif nextChar:byte() == 31 then
				fgNext = true
			elseif bgNext then
				currBG = getColourOf(nextChar)
				bgNext = false
			elseif fgNext then
				currFG = getColourOf(nextChar)
				fgNext = false
			else
				if nextChar ~= " " and currFG == nil then
					currFG = _G.colors.white
				end
				image.bg[num][writeIndex] = currBG
				image.fg[num][writeIndex] = currFG
				image.text[num][writeIndex] = nextChar
				writeIndex = writeIndex + 1
			end
		end
		image.height = num
		if not image.width or writeIndex - 1 > image.width then
			image.width = writeIndex - 1
		end
		num = num+1
	end
	return image
end

function NFT.load(path)

	local imageText = Util.readFile(path)
	if not imageText then
		error('Unable to read image file')
	end
	return NFT.parse(imageText)
end

return NFT
