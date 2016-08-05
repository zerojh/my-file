
local function _instant(class, ...)
    local inst = setmetatable({tt = "bcd"}, {__index = class})

    if inst.__init__ then 
        inst:__init__(...)
    end

    return inst
end

function class(base)
    return setmetatable({}, {
        __call  = _instant,
        __index = base
    })
end

Node = class()

function Node.__init__(self, title, description)
    self.children = {}
    self.title = title or {}
    self.description = description
end

Map = class()

function Map.__init__(self, config, ...)
    Node.__init__(self, ...)
    self.config = config
end

m = Map("abc", "title", "description")

print(m.config, m.title, m.description, m.tt)
mn = getmetatable(m)
print(mn.config, mn.title, mn.description, mn.tt)

