
s = "deadline is 30/05/1999, firm"
date = "%d%d/%d%d/%d%d%d%d"
i, j = string.find(s, date)
print(i, j)
c = string.sub(s, i, j)
print(c)

print(string.sub(s, string.find(s, date)))
