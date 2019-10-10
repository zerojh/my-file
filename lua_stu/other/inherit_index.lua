
small = {["hello"] = "small"}

function medium(sma)
    return setmetatable({["world"] = "medium"}, {__index = sma})
end

function big(med)
    return setmetatable({["haha"] = "big"}, {__index = med})
end

zhong = medium(small)
da = big(zhong)

da.open = "123"
print(da.open)
print(da.hello)

function bianli (obj)
    for i,v in pairs(obj) do
        print(i,v)
        if type(v) == table then
            bianli(v)
        end
    end
end
bianli(da)
print(type(da.__index))
