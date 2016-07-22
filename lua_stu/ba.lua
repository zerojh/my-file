
function abc(...)
    return {...}
end


a = abc(111,222,333)

for _,v in pairs(a) do
    print(v)
end
