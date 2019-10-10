
function unescape (s)
    s = string.gsub(s, "+", " ")
    s = string.gsub(s, "%%(%x%x)", function (h)
        return string.char(tonumber(h, 16))
    end)
    return s
end

print(unescape("a%2Bb+%3D+c"))
print(string.char(tonumber("2B", 16)))
print(string.char(tonumber("3D", 16)))

