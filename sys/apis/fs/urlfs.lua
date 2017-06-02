local synchronized = require('sync')

local urlfs = { }

function urlfs.mount(dir, url)
  if not url then
    error('URL is required')
  end
  return {
    url = url,
  }
end

function urlfs.delete(node, dir)
  fs.unmount(dir)
end

function urlfs.exists()
  return true
end

function urlfs.getSize(node)
  return node.size or 0
end

function urlfs.isReadOnly()
  return true
end

function urlfs.isDir()
  return false
end

function urlfs.getDrive()
  return 'url'
end

function urlfs.open(node, fn, fl)

  if fl ~= 'r' and fl ~= 'rb' then
    error('Unsupported mode')
  end

  local c = node.cache
  if not c then
    synchronized(node.url, function()
      c = Util.download(node.url)
    end)
    if c then
      node.cache = c
      node.size = #c
    end
  end

  if not c then
    return
  end

  local ctr = 0
  local lines

  if fl == 'r' then
    return {
      readLine = function()
        if not lines then
          lines = Util.split(c)
        end
        ctr = ctr + 1
        return lines[ctr]
      end,
      readAll = function()
        return c
      end,
      close = function()
        lines = nil
      end,
    }
  end
  return {
    read = function()
      ctr = ctr + 1
      return c:sub(ctr, ctr)
    end,
    close = function()
      ctr = 0
    end,
  }
end

return urlfs
