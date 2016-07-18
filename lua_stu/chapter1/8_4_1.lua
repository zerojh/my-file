
if not nil then 
    print("nil")
else
    print("yes")
end

print(io.open("no-file","r"))

local status, err = pcall(function () a = 'a' + 1 end)
print(err)
status, err = pcall(function () error("my error") end)
print(err)

function foo(x)
    if type(x) ~= "string" then
        error("string expected", 2)
    end
end

foo(11)
 
