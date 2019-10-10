
function setDefault(t, m)
    local mt = {__index = function () return m end}
    setmetatable(t, mt)
end

tab = {x = 10, y = 20}
print(tab.x, tab.y, tab.z)
setDefault(tab, 0)
print(tab.x, tab.y, tab.z)
