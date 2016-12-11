local Util = require('util')

local History = { }

function History.load(filename, limit)

  local entries = Util.readLines(filename) or { }
  local pos = #entries + 1

  return {
    entries = entries,

    add = function(line)
      local last = entries[pos] or entries[pos - 1]
      if not last or line ~= last then
        table.insert(entries, line)
        if limit then
          while #entries > limit do
            table.remove(entries, 1)
          end
        end
        Util.writeLines(filename, entries)
        pos = #entries + 1
      end
    end,

    setPosition = function(p)
      pos = p
    end,

    back = function()
      if pos > 1 then
        pos = pos - 1
        return entries[pos]
      end
    end,

    forward = function()
      if pos <= #entries then
        pos = pos + 1
        return entries[pos]
      end
    end,
  }
end

return History
