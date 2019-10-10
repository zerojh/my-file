
function code (s)
    return (string.gsub(s, "\\(.)", function (x)
        return string.format("\\%03d", string.byte(x))
    end))
end

function decode (s)
    return (string.gsub(s, "\\(%d%d%d)", function (d)
        return "\\" .. string.char(d)
    end))
end

s = [[follows a typical string: "This is "great"!abc".]]
print(s)
print("\33")
s = code(s)
print(s)
s1 = string.gsub(s, '(".*")', string.upper)
s2 = string.gsub(s, '(".-")', string.upper)
s1 = decode(s1)
s2 = decode(s2)
print(s1)
print(s2)
