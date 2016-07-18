function ova(...)
    a = {...}
    for i,v in pairs(a) do
        print(i, v)
    end
end

print(ova(123,"asdf", 'a'))
