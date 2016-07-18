function printfor()
    local i = 1
    local n = 10
    return function ()
        if(i < n) then
            i = i + 1
            return i
        end
        return nil
    end
end

for i in printfor() do
    print(i)
end

