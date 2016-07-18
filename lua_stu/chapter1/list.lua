---- list creat
list = nil
for line in io.lines("number.txt") do
    list = {next = list, value = line}
end

l = list
while l do
    print(l.value)
    l = l.next
end

