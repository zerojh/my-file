
function readOnly(t)
    local proxy = {}
    local mt = {
        __index = t,
        __newindex = function   (t,k,v)
            error("has no permittion to update")
        end
    }

    setmetatable(proxy, mt)
    return proxy
end

s = readOnly{"Monday", "Sunday", "Tuesday","Wendsday", "Firsday"}
print(s[1])
s[1] = "abc"
