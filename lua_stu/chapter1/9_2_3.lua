function permgen(a, n)
    if n == 0 then
        coroutine.yield(a)
    else
        for i=1,n do
            a[n],a[i] = a[i],a[n]
            permgen(a, n-1)
            a[n],a[i] = a[i],a[n]
        end
    end
end

function perm (a)
    local n = rawlen(a)
    local co = coroutine.create(function () permgen(a, n) end)
    return function()
        --io.write(coroutine.status(co), "\n")
        local code, res = coroutine.resume(co)
        return res
    end
end

function printResult(a)
    for i,v in ipairs(a) do
        io.write(v," ")
    end
    io.write("\n")
end

for p in perm{"a", "b", "c"} do
    printResult(p)
end
