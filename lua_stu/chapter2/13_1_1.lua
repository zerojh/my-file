Set = {}
Set.mt = {}

function Set.new (t)
    local set = {}
    setmetatable(set, Set.mt)
    for _, l in ipairs(t) do set[l] = true end
    return set
end

function Set.union (a,b)
    --if getmetatable(a) ~= Set.mt or getmetatable(b) ~= Set.mt then
    --    error("parameter error!", 2)
    --end
    local res = Set.new{}
    for k in pairs(a) do res[k] = true end
    for k in pairs(b) do res[k] = true end
    return res
end
Set.mt.__add = Set.union

function Set.intersection (a,b)
    local res = Set.new{}
    for k in pairs(a) do
        res[k] = b[k]
    end
    return res
end
Set.mt.__mul = Set.intersection

function Set.tostring (set)
    local s = "{"
    local sep = ""
    for e in pairs(set) do
        s = s .. sep .. e
        sep = ", "
    end
    return s .. "}"
end
Set.mt.__tostring = Set.tostring

function Set.print (s)
    print(Set.tostring(s))
end

Set.mt.__le = function (a, b)
    for k in pairs(a) do
        if not b[k] then return false end
    end
    return true
end

Set.mt.__eq = function (a, b)
    return a <= b and b <= a
end

Set.mt.__lt = function (a, b)
    return a <= b and not (b <= a)
end

Set.mt.__metatable = "No permittion"

s1 = Set.new{10,20,30,50}
s2 = Set.new{1,2,3,5,10,20,30,50}
Set.print(s1)
Set.print(s2)
print(getmetatable(s1))
print(getmetatable(s2))
setmetatable(s1,{})
s3 = s1 + s2
Set.print(s3)
s4 = s3 * s1
Set.print(s4)
print(s1 <= s2)
print(s1 >= s1)
print(s1 < s2)
print(s1 > s1)
print(s1 == s2)
print(s1)




