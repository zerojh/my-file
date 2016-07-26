
a = 3

function getvarvalue (name)
    local value, found
    --try local variables
    local i = 1
    while true do
        local n, v = debug.getlocal(2, i)
        if not n then break end
        if n == name then
            value = v
            found = true
        end
        i = i + 1
    end
    if found then return value end

    -- try upvalues
    local func = debug.getinfo(2).func
    i = 1
    while true do
        local n, v = debug.getupvalue(func, i)
        if not n then break end
        if n == name then return v end
        i = i + 1
    end

    -- not found; get global
    return getfenv(func)[name]
end

getvarvalue(3)
