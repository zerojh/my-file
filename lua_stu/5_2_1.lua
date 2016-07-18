printResult = ""

function printm(...)
    for i,v in pairs({...}) do
        printResult = printResult .. tostring(v) .. "\t"
    end
    printResult = printResult .. "\n"
    return printResult
end

print("hello", "world")
print(printm("hello", "world"))
