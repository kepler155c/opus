local function printUsage()
    print("Usages:")
    print("devbin get <code> <filename>")
    print("devbin run <code> <arguments>")
end

local tArgs = { ... }
if #tArgs < 2 then
    printUsage()
    return
end

if not http then
    printError("Devbin requires the http API")
    printError("Set http.enabled to true in CC: Tweaked's config")
    return
end

--- Attempts to guess the pastebin ID from the given code or URL
local function extractId(paste)
    local patterns = {
        "^([%a%d]+)$",
        "^https?://devbin.dev/([%a%d]+)$",
        "^devbin.dev/([%a%d]+)$",
        "^https?://devbin.dev/raw/([%a%d]+)$",
        "^devbin.dev/raw/([%a%d]+)$",
    }

    for i = 1, #patterns do
        local code = paste:match(patterns[i])
        if code then return code end
    end

    return nil
end

local function get(url)
    local paste = extractId(url)
    if not paste then
        io.stderr:write("Invalid devbin code.\n")
        io.write("The code is the ID at the end of the pastebin.com URL.\n")
        return
    end

    write("Connecting to devbin.dev... ")
    -- Add a cache buster so that spam protection is re-checked
    local cacheBuster = ("%x"):format(math.random(0, 2 ^ 30))
    local response, err = http.get(
        "https://devbin.dev/raw/" .. textutils.urlEncode(paste) .. "?cb=" .. cacheBuster
    )

    if response then
        local headers = response.getResponseHeaders()
        print("Success.")

        local sResponse = response.readAll()
        response.close()
        return sResponse
    else
        io.stderr:write("Failed.\n")
        print(err)
    end
end

local sCommand = tArgs[1]
if sCommand == "get" then
    -- Download a file from pastebin.com
    if #tArgs < 3 then
        printUsage()
        return
    end

    -- Determine file to download
    local sCode = tArgs[2]
    local sFile = tArgs[3]
    local sPath = shell.resolve(sFile)
    if fs.exists(sPath) then
        print("File already exists")
        return
    end

    -- GET the contents from pastebin
    local res = get(sCode)
    if res then
        local file = fs.open(sPath, "w")
        file.write(res)
        file.close()

        print("Downloaded as " .. sFile)
    end
elseif sCommand == "run" then
    local sCode = tArgs[2]

    local res = get(sCode)
    if res then
        local func, err = load(res, sCode, "t", _ENV)
        if not func then
            printError(err)
            return
        end
        local success, msg = pcall(func, select(3, ...))
        if not success then
            printError(msg)
        end
    end
else
    printUsage()
    return
end
