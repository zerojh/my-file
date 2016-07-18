function autofind()
    local line =io.read()
    -- print(line)
    local pos = 1
    return function()
        while(line) do
            local s, e = string.find(line, "%w+", pos)
            print(s, e)
            if s then
                pos = e + 1
                return string.sub(line, s, e)
            else
                line = io.read()
                pos = 1
            end
        end
        return nil
    end
end

for word in autofind() do
    print(word)
end
