--[[
FIX for http.get
currently, when 2 requests are generated at same time (diff coroutines) they both
will receive the same file handle. This change will ensure each request gets the
proper response.
--]]

local http = _G.http

local reqs = { }

local function wrapRequest(_url, ...)
    local ok, err = http.request(...)
    if ok then
        while true do
            local event, param1, param2, param3 = os.pullEvent()

            if event == "http_success"
                and param1 == _url
                and not reqs[tostring(param2)] then

                reqs[tostring(param2)] = true
                return param2

            elseif event == "http_failure" and param1 == _url then
                return nil, param2, param3
            end
        end
    end
    return nil, err
end

http.safeGet = function(_url, _headers, _binary)
    return wrapRequest(_url, _url, nil, _headers, _binary)
end
