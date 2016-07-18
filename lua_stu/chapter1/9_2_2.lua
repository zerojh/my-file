function permgen(a, n)
    if n == 0 then
        printResult(a)
    else
        for i=1,n do
            a[n],a[i] = a[i],a[n]
            permgen(a, n-1)
            a[n],a[i] = a[i],a[n]
            io.write("------")
        end
    end
end

function printResult(a)
    for i,v in ipairs(a) do
        io.write(v," ")
    end
    io.write("\n")
end

permgen({1,2,3,4},4)
