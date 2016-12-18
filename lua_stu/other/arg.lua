
-- 说明5.3不存在arg这个局部表了
function test_arg(...)
    print(#arg)
    if next(arg) then
        for k,v in pairs(arg) do
            print(k,v)
        end
    end
end

test_arg(1,2,3,4)

print(arg[0])
print(arg[-1])
