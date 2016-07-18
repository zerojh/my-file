function ova ()
    local i = 0
    return function ()
        i = i + 1
        return i
    end
end

c1 = ova()
c2 = ova()
print(c1())
print(c1())
print(c2())
print(c1())

