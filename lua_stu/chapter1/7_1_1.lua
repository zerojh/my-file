function iter(t)
    local i = 0
    local n = table.getn(t)
    return function ()
        i = i + 1
        if i <= n then return t[i] end
    end
end

list = {10, 20, 30}

for value in iter(list) do
    print(value)
end

for value in iter(list) do
    print(value)
end
