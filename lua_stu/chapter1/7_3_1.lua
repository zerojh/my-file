a = {"abc", "bds", "edf"}

for i, v in pairs(a) do
    print(i, v)
end

print("-------")

for i, v in next, a do
    print(i, v)
end

print(next(a))
print(next(a))
