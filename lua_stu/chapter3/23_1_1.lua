
function traceback ()
    local level = 1
    while true do
        local info = debug.getinfo(level, "Sl")
        if not info then break end
        if info.what == "C" then    -- is a C function?
            print(level, "C function", info.short_src, info.currentline)
        else   -- a Lua function
            print(string.format("[%s]:%d",
            info.short_src, info.currentline))
        end
        level = level + 1
    end
end

traceback()
