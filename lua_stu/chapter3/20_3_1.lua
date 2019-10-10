
pair = "name = Anna = 123"
_, _, a, b, c = string.find(pair, "(%a+)%s*=%s*(%a+)%s*=%s*(%d+)")
print(a,b,c)

s = [[then he said: "it's all right"!]]
print(s)
a, b, c, quote = string.find(s, "([\"\"])(.-)%1")
print(c, quote)
print(string.find(s, "\".\""))

