
s1 = [[hello "wsadas".]]
s2 = [[byebye "asdasd"]]
print(s1)
print(s2)
s3 = string.gsub(s1, "(%W)", "%%%1")
print(s3)
s4 = string.gsub(s3, "%%", "%%%%")
print(s4)
