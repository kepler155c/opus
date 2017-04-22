-- Base64 Encoder / Decoder
-- By KillaVanilla
-- see: http://www.computercraft.info/forums2/index.php?/topic/12450-killavanillas-various-apis/

Base64 = { }

local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function sixBitToBase64(input)
  return string.sub(alphabet, input+1, input+1)
end

local function base64ToSixBit(input)
  for i=1, 64 do
    if input == string.sub(alphabet, i, i) then
      return i-1
    end
  end
end

local function octetToBase64(o1, o2, o3)
  local i1 = sixBitToBase64(bit.brshift(bit.band(o1, 0xFC), 2))
  local i2 = "A"
  local i3 = "="
  local i4 = "="
  if o2 then
    i2 = sixBitToBase64(bit.bor( bit.blshift(bit.band(o1, 3), 4), bit.brshift(bit.band(o2, 0xF0), 4) ))
    if not o3 then
      i3 = sixBitToBase64(bit.blshift(bit.band(o2, 0x0F), 2))
    else
      i3 = sixBitToBase64(bit.bor( bit.blshift(bit.band(o2, 0x0F), 2), bit.brshift(bit.band(o3, 0xC0), 6) ))
    end
  else
    i2 = sixBitToBase64(bit.blshift(bit.band(o1, 3), 4))
  end
  if o3 then
    i4 = sixBitToBase64(bit.band(o3, 0x3F))
  end
  
  return i1..i2..i3..i4
end

-- octet 1 needs characters 1/2
-- octet 2 needs characters 2/3
-- octet 3 needs characters 3/4

local function base64ToThreeOctet(s1)
  local c1 = base64ToSixBit(string.sub(s1, 1, 1))
  local c2 = base64ToSixBit(string.sub(s1, 2, 2))
  local c3 = 0
  local c4 = 0
  local o1 = 0
  local o2 = 0
  local o3 = 0
  if string.sub(s1, 3, 3) == "=" then
    c3 = nil
    c4 = nil
  elseif string.sub(s1, 4, 4) == "=" then
    c3 = base64ToSixBit(string.sub(s1, 3, 3))
    c4 = nil
  else
    c3 = base64ToSixBit(string.sub(s1, 3, 3))
    c4 = base64ToSixBit(string.sub(s1, 4, 4))
  end
  o1 = bit.bor( bit.blshift(c1, 2), bit.brshift(bit.band( c2, 0x30 ), 4) )
  if c3 then
    o2 = bit.bor( bit.blshift(bit.band(c2, 0x0F), 4), bit.brshift(bit.band( c3, 0x3C ), 2) )
  else
    o2 = nil
  end
  if c4 then
    o3 = bit.bor( bit.blshift(bit.band(c3, 3), 6), c4 )
  else
    o3 = nil
  end
  return o1, o2, o3
end

local function splitIntoBlocks(bytes)
  local blockNum = 1
  local blocks = {}
  for i=1, #bytes, 3 do
    blocks[blockNum] = {bytes[i], bytes[i+1], bytes[i+2]}
    --[[
    if #blocks[blockNum] < 3 then
      for j=#blocks[blockNum]+1, 3 do
        table.insert(blocks[blockNum], 0)
      end
    end
    ]]
    blockNum = blockNum+1
  end
  return blocks
end

function Base64.encode(bytes)
  local blocks = splitIntoBlocks(bytes)
  local output = ""
  for i=1, #blocks do
    output = output..octetToBase64( unpack(blocks[i]) )
  end
  return output
end

function Base64.decode(str)
  local bytes = {}
  local blocks = {}
  local blockNum = 1
  for i=1, #str, 4 do
    blocks[blockNum] = string.sub(str, i, i+3)
    blockNum = blockNum+1
  end
  for i=1, #blocks do
    local o1, o2, o3 = base64ToThreeOctet(blocks[i])
    table.insert(bytes, o1)
    table.insert(bytes, o2)
    table.insert(bytes, o3)
if (i % 1000) == 0 then
  os.sleep(0)
end
  end
  -- Remove padding:
  --[[
  for i=#bytes, 1, -1 do
    if bytes[i] ~= 0 then
      break
    else
      bytes[i] = nil
    end
  end
  ]]
  return bytes
end

return Base64
