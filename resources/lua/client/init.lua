local _ = require "luvit.init"
local Emitter = require "luvit.core".Emitter

local traceback = require "debug".traceback
local ffi = require "ffi"
local table = require "table"
local sort, remove = table.sort, table.remove

local native = require "client.native"

local UiElement = Emitter:extend()

-- Location relative to the parent
UiElement.x = 0
UiElement.y = 0
UiElement.z = 0

UiElement.w = 0
UiElement.h = 0

-- Maximum dimensions (inf by default)
UiElement.maxWidth = 1/0
--UiElement.maxHeight = 1/0 TODO: implement

-- Alignment of the children (0 = none, 1 = float left, 2 = float right, 3 = float bottom, 4 = float top)
UiElement.alignment = 0

-- Relations to other elements
UiElement.parent = nil
UiElement.children = nil

function UiElement:initialize()
    self.children = {}
end

function UiElement:sortChildren()
    sort(self.children, function(a, b)
        return a.z > b.z
    end)
end

function UiElement:move(x, y, z)
    self.x, self.y, self.z = z, y, z
    if self.parent then
        self.parent:sortChildren()
    end
end

function UiElement:addChild(obj)
    obj.parent = self
    self.children[#self.children+1] = obj
end

function UiElement:removeChild(obj)
    for i, element in ipairs(self.children) do
        if element == obj then
            obj.parent = nil
            remove(self.children, i)
        end
    end
end

function UiElement:_sauerMaxWidth()
    return self.maxWidth == 1/0 and -1 or self.maxwidth
end

-- X and Y are the actual screen coordinates of the element to draw
-- Note that Z only affects sorting of the element and it's siblings
function UiElement:draw(x, y)
    local origionalX = x
    for k, element in pairs(self.children) do
        local _x, _y = x + element.x, y + element.y
        local w, h = element.w, element.h
        element:draw(_x, _y)
        if self.alignment == 1 then
            _x = x + w
            if _x >= self.maxWidth or _x + w >= self.maxWidth then
                -- Jump line
                x = origionalX
                y = _y + h
            else
                x = _x
            end
        end
    end
end

local BoxElement = UiElement:extend()

BoxElement.texture = nil

BoxElement.r = 1
BoxElement.g = 1
BoxElement.b = 1

-- BoxElement.a = 1 TODO: implement

function BoxElement:draw(x, y)
    print "draw"
    native.glPushMatrix();
    native.glScalef(1, 1, 1);

    if self.texture then
        native.glColor4f(1, 1, 1, 1)
        native.settexture(o.file, 0)
    else
        native.glColor4f(self.r, self.g, self.b, 1)
    end

    native.glBegin(native.GL_TRIANGLE_STRIP);
        for k, v in pairs({ {0,0}, {1, 0}, {0, 1}, {1, 1}}) do
            if self.texture then
                native.glTexCoord2f(v[1], v[2])
            end
            native.glVertex2f(x + v[1] * self.w,    y  + v[2] * self.h);
        end
    native.glEnd();
    native.glPopMatrix()
    
    UiElement.draw(self, x, y)
end

local TextElement = UiElement:extend()

TextElement.text = "Hello world!"

TextElement.r = 1
TextElement.g = 1
TextElement.b = 1
TextElement.a = 1

--What does this actually do?
TextElement.cursor = -1 

function TextElement:setText(text)
    self.text = tostring(text or "")
    self:calculateDimensions()
end

-- NOTE: calling this before fonts are loaded causes the game to segfault!
function TextElement:calculateDimensions()
    local x, y = ffi.new("int[1]", 0), ffi.new("int[1]", 0)
    native.text_boundsp(self.text, x, y, self:_sauerMaxWidth())
    self.w, self.h = x[0], y[0]
end

function TextElement:initialize(text)
    UiElement.initialize(self)

    if text then
        self:setText(text)
    else
        self:calculateDimensions()
    end
end

function TextElement:draw(x, y)
    -- Draw children first
    UiElement.draw(self, x, y)

    x, y = x + self.x, y + self.y
    native.draw_text(self.text, x, y, self.r*255, self.g*255, self.b*255, self.a*255, self.cursor, self:_sauerMaxWidth())
end

local UiRoot = UiElement:extend()

local uiRoot

_G.setCallback("gui.draw", function(w, h)
    assert(xpcall(function()
        if not uiRoot then
            uiRoot = UiRoot:new()
            
            local box = BoxElement:new()
            box.w = 100
            box.h = 100

            uiRoot:addChild(box)

            uiRoot:addChild(TextElement:new())
            uiRoot:addChild(TextElement:new())
            uiRoot:addChild(TextElement:new())
            uiRoot.maxWidth = 700
            uiRoot.alignment = 1
            
        end
        uiRoot:draw(0, 0)
    end, traceback))
end)

do 
    local warned = {}
    setCallback("event.none", function(name)
        if not warned[name] then
            warned[name] = name
            print (("No event callback set for %s\n"):format(name))
        end
    end)
end