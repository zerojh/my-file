
print(string.gsub("hello world123", "%A", "."))
print(string.gsub("hello world123", "%a", "."))
print(string.gsub("hello world123", "%d", "."))
print(string.gsub("hello world123", "%D", "."))

print(string.gsub("hello wORld,123", "%l", "."))
print(string.gsub("hello wORld,123", "%u", "."))

print(string.gsub("hello wORld,123", "%s", "."))

print(string.gsub("hello wORld,123", "%w", "."))

print(string.gsub("hello wORld,1023", "%p", "."))

print(string.gsub("hello wORld,1023\0", "%z", "."))

