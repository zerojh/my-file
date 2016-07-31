--事件原型对象, 所有事件由此原型生成
Event = {}

function Event:New()
    local event = {}
    setmetatable(event, self)
    --覆盖__index逻辑
    self.__index = self
    --覆盖__call逻辑
    self.__call = self.Call
    return event
end

--事件注册, 通过此方法将响应方法注册到事件上.
--@source:响应方法的所属对象
--@func:响应方法
function Event:Add(source, func)
    table.insert(self, {source, func})
end

--内部方法, 重写了默认__call逻辑, 当event被触发调用时, 循环执行event中注册的响应方法
--@table:对象产生调用时将本身传入
--@:调用参数
function Event.Call(table, button)
    --print("Event.Call " .. button.Name)
    for _, item in ipairs(table) do
        --item[1]就是source, item[2]就是func响应方法
        --lua 5.1中无需使用unpack(arg), 直接使用即可
        item[2](item[1], button)
    end
end

--创建一个button对象, 拥有ClickEvent这样的事件
Button = {
    Name = "A Button",
    --创建事件
    ClickEvent = Event:New(),
}

--创建一个window对象, 注册按钮的点击事件
Window = {
    Name = "Simonw's Window",
}

function Window:Init()
    --注册事件, self即Window, 对象来源.
    --print("Window:init " .. self.Name)
    Button.ClickEvent:Add(self, self.Button_OnClick)
end

--响应事件方法, sender即是传来的Button对象
function Window:Button_OnClick(sender)
    --print("Window:Button " .. self.Name)
    print(sender.Name .. " Click On " .. self.Name)
end

--执行点击按钮的动作
function Button:Click()
    print('Click begin')
    --print("Button:Click " .. self.Name)
    --触发事件, self即sender参数
    self.ClickEvent(self)
    print('Click end')
end

Window:Init()
Button:Click()
