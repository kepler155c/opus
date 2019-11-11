local Util = require('opus.util')

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

		local tcol, bcol = colors.white,colors.black
		local cx, sx = 1, 0
		while sx < #sLine do
			sx = sx + 1
			if sLine:sub(sx,sx) == "\30" then
				bcol = getColourOf(sLine:sub(sx+1,sx+1))
				sx = sx + 1
			elseif sLine:sub(sx,sx) == "\31" then
				tcol = getColourOf(sLine:sub(sx+1,sx+1))
				sx = sx + 1
			else
				image.bg[num][writeIndex] = bcol
				image.fg[num][writeIndex] = tcol
				image.text[num][writeIndex] = sLine:sub(sx,sx)
				writeIndex = writeIndex + 1
				cx = cx + 1
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
