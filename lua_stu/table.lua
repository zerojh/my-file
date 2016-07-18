w = {x = 0, y = 1, label = "jeck"}
print("--w pairs before---")
for v, i in pairs(w) do
    print(v, i)
end

print("--w ipairs before---")

for v, i in ipairs(w) do
    print(v, i)
end

w.x = 3;w["label"] = "hello"
a = {4, 5, 6}
w[1] = a

print("--w pairs after---")

for v, i in pairs(w) do
    print(v, i)
end

print("--w ipairs after---")

for v, i in ipairs(w) do
    print(v, i)
end

print("-- w[1] pairs --")

for v,i in pairs(w[1]) do
    print(v, i)
end

print("-- w[1] ipairs --")
for v,i in ipairs(w[1]) do
    print(v, i)
end
