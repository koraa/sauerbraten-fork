local _ = require "luvit.init"
local Emitter = require "luvit.core".Emitter

local traceback = require "debug".traceback
local ffi = require "ffi"
local table = require "table"
local sort, remove = table.sort, table.remove
local math = require "math"
local max, min = math.max, math.min

local native = require "client.native"

local DEBUG = true

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

function UiElement:getWidth()
    local width = self.w
    if width < 0 and self.parent then
        width = self.parent:getWidth()
    end
    return min(self:getMaxWidth(), width)
end

function UiElement:getMaxWidth()
    return min(self.maxWidth, self.parent and self.parent:getMaxWidth() or 1/0)
end

function UiElement:_sauerMaxWidth()
    local maxWidth = self:getMaxWidth()
    return maxWidth == 1/0 and -1 or maxWidth
end

-- X and Y are the actual screen coordinates of the element to draw
-- Note that Z only affects sorting of the element and it's siblings
function UiElement:draw(x, y)
    local origionalX = x
    local maxH = 0
    for k, element in pairs(self.children) do
        local _x, _y = x + element.x, y + element.y -- Actual starting position of the element
        maxH = max(maxH, element.h)
        element:draw(x, y)
        if self.alignment == 1 then
            local w = element:getWidth()
            _x = x + w
            if _x >= self.maxWidth or _x + w >= self.maxWidth then
                -- Jump line
                x = origionalX
                y = _y + maxH
                maxH = 0
            else
                x = _x
            end
        end
    end
end

local BoxElement = UiElement:extend()

BoxElement.texture = "packages/texture/notexture.png"

BoxElement.r = 1
BoxElement.g = 1
BoxElement.b = 1

-- BoxElement.a = 1 TODO: implement
function BoxElement:initialize(a, b, c)
    UiElement.initialize(self)

    if type(a) == "string" then
        self.texture = a
    elseif type(a) ~= "nil" then
        self.a = self.a or a
        self.b = self.b or b
        self.c = self.c or c
    end
end

function BoxElement:draw(x_, y_)
    local x, y = x_ + self.x, y_ + self.y
    native.glPushMatrix();
    native.glScalef(1, 1, 1);

    if DEBUG then
        native.glPolygonMode( native.GL_FRONT_AND_BACK, native.GL_LINE );
    end

    if self.texture then
        native.glColor4f(1, 1, 1, 1)
        native.settexture(self.texture, 0)
    else
        native.glColor4f(self.r, self.g, self.b, 1)
    end

    local w = self:getWidth()
    
    native.glBegin(native.GL_TRIANGLE_STRIP);
        for k, v in pairs({ {0,0}, {1, 0}, {0, 1}, {1, 1}}) do
            if self.texture then
                native.glTexCoord2f(v[1], v[2])
            end
            native.glVertex2f(x + v[1] * w,    y  + v[2] * self.h);
        end
    native.glEnd();

    if DEBUG then
        native.glPolygonMode( native.GL_FRONT_AND_BACK, native.GL_FILL);
    end
    native.glPopMatrix()
    
    UiElement.draw(self, x, y)
end

local TextElement = UiElement:extend()

TextElement.text = "Hello world!"

TextElement.r = 1
TextElement.g = 1
TextElement.b = 1
TextElement.a = 1

TextElement.scale = 1

TextElement.font = nil

--What does this actually do?
TextElement.cursor = -1 

function TextElement:setText(text)
    self.text = tostring(text or "")
    self:calculateDimensions()
end

-- NOTE: calling this before fonts are loaded causes the game to segfault!
function TextElement:calculateDimensions()
    if self.font then
        native.pushfont()
        native.setfont(self.font)
    end

    local x, y = ffi.new("int[1]", 0), ffi.new("int[1]", 0)
    native.text_boundsp(self.text, x, y, self:_sauerMaxWidth())
    self.w, self.h = x[0] * self.scale, y[0] * self.scale
    
    if self.font then
        native.popfont()
    end
end

function TextElement:initialize(text, font)
    UiElement.initialize(self)

    self.font = font

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

    if self.font then
        native.pushfont()
        native.setfont(self.font)
    end
    
    native.glPushMatrix()
        native.glScalef(self.scale, self.scale, 1);
        native.draw_text(self.text, x/self.scale, y/self.scale, self.r*255, self.g*255, self.b*255, self.a*255, self.cursor, self:_sauerMaxWidth())
    native.glPopMatrix()

    if self.font then
        native.popfont()
    end
end

local LoadingBarElement = UiElement:extend()

LoadingBarElement.w = -1
LoadingBarElement.h = 50

LoadingBarElement.border = 10

LoadingBarElement.progress = 1/2

function LoadingBarElement:initialize(text, progress)
    UiElement.initialize(self)

    self.loadingText = TextElement:new(text)
    self.progress = progress or self.progress

    self.loadingBar = BoxElement:new(--[["data/loading_bar.png"]])
    self.loadingBackground = BoxElement:new(--[["data/loading_frame.png"]])

    self:calculateDimensions()
end

function LoadingBarElement:setProgress(text, progress)
    self.loadingText:setText(text)
    self.progress = progress

    self:calculateDimensions()
end

function LoadingBarElement:calculateDimensions()
    self.loadingText.scale = self.h/100

    self.loadingText:calculateDimensions()
    self.loadingBackground.w, self.loadingBackground.h = self:getWidth(), self.h
    self.loadingText.x = max(0, self:getWidth()/2 - self.loadingText:getWidth()/2)
    self.loadingText.y = max(0, self.h/2 - self.loadingText.h/2)

    self.loadingBar.x = self.border
    self.loadingBar.y = self.border

    self.loadingBar.maxWidth = self:getWidth() - 2 * self.border
    self.loadingBar.w = self.loadingBar.maxWidth * self.progress
    self.loadingBar.h = self.h - 2 * self.border

end

function LoadingBarElement:draw(x, y)
    x, y = x + self.x, y + self.y
    self.loadingBackground:draw(x, y)
    self.loadingBar:draw(x, y)
    self.loadingText:draw(x, y)
end

local DialogElement = UiElement:extend()

DialogElement._addChild = UiElement.addChild

function DialogElement:addChild(...)
    return self.body:addChild(...)
end

function DialogElement:initialize(title)
    UiElement.initialize(self)

    self.titleBarElement = BoxElement:new()
    self.titleBarElement.h = 30
    self.titleBarElement.x, self.titleBarElement.y = 0, 0
    
    self.titleElement = TextElement:new(title or "Unnamed dialog")
    self.titleElement.scale = 0.5
    self.titleBarElement:addChild(self.titleElement)

    self.closeButtonElement = BoxElement:new()
    self.closeButtonElement.w = 40
    self.closeButtonElement.h = 25
    self.titleBarElement:addChild(self.closeButtonElement)

    self.body = BoxElement:new()

    self:_addChild(self.titleBarElement)
    self:_addChild(self.body)

    self:calculateDimensions()
end

function DialogElement:calculateDimensions()
    self.body.y = self.titleBarElement.h
    self.body.x = 2
    self.body.w = self:getWidth() - self.body.x * 2
    self.body.h = self.h - self.titleBarElement.h

    self.titleBarElement.w = self:getWidth()
    self.titleBarElement.maxWidth = self:getWidth()

    self.titleElement.maxWidth = self.titleBarElement:getWidth() - self.closeButtonElement:getWidth() - 3 * 5
    self.titleElement:calculateDimensions()
    self.titleElement.x = max(5, self.titleElement.maxWidth/2 - self.titleElement:getWidth()/2)
    self.titleElement.y = self.titleBarElement.h/2 - self.titleElement.h/2

    self.closeButtonElement.x = self.titleBarElement:getWidth() - 5 - self.closeButtonElement:getWidth()
end



local UiRoot = UiElement:extend()

local dialog
local loadingBar
local uiRoot
local box
local mode = -1

_G.setCallback("gui.draw", function(w, h)
    assert(xpcall(function()
        if not uiRoot then
            uiRoot = UiRoot:new()

            loadingBar = LoadingBarElement:new("", 0)
            uiRoot:addChild(loadingBar)

            box = BoxElement:new()
            box.w = 100
            box.h = 100

            uiRoot:addChild(box)

            uiRoot:addChild(TextElement:new())
            uiRoot:addChild(TextElement:new())
            uiRoot:addChild(TextElement:new("1234", "digit_grey"))
            uiRoot:addChild(TextElement:new("1234", "digit_red"))
            uiRoot:addChild(TextElement:new("1234", "digit_blue"))
            uiRoot.maxWidth = 700
            uiRoot.alignment = 1

            dialog = DialogElement:new()
            dialog.w = 500
            dialog.h = 500
            dialog:calculateDimensions()
            dialog:addChild(loadingBar)
        end

        local progress = max(0, (loadingBar.progress * 100 + mode)/100)
        loadingBar:setProgress(("Doing nothing %f %i"):format(progress, mode), progress)
        
        box.w = box.w + mode
        box.h = box.h + mode

        if box.h >= 100 or box.h <= 0 then
            mode = -mode
        end

        --uiRoot:draw(0, 0)
        dialog:draw(50, 50)
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