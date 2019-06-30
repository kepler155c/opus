local Serializer = { }

local insert = table.insert
local format = string.format

function Serializer.serialize(tbl)
  local output = { }

  local function recurse(t)
    local sType = type(t)
    if sType == 'table' then
      if next(t) == nil then
        insert(output, '{}')
      else
        insert(output, '{')
        local tSeen = {}
        for k, v in ipairs(t) do
          tSeen[k] = true
          recurse(v)
          insert(output, ',')
        end
        for k, v in pairs(t) do
          if not tSeen[k] then
            if type(k) == 'string' and string.match(k, '^[%a_][%a%d_]*$') then
              insert(output, k .. '=')
              recurse(v)
              insert(output, ',')
            else
              insert(output, '[')
              recurse(k)
              insert(output, ']=')
              recurse(v)
              insert(output, ',')
            end
          end
        end
        insert(output, '}')
      end
    elseif sType == 'string' then
      insert(output, format('%q', t))
    else
      insert(output, tostring(t))
    end
  end

  recurse(tbl)
  return table.concat(output)
end

return Serializer
