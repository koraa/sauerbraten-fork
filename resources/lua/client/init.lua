local _ = require "luvit.init"
local Emitter = require "luvit.core".Emitter

local ffi = require "ffi"

local native = require "client.native"

local UiRoot = Emitter:extend()

function UiRoot:draw(w, h)
    local str = "hello world"
    local x, y = ffi.new("int[1]", 0), ffi.new("int[1]", 0)
    native.text_boundsp(str, x, y, -1)
    native.draw_text(str, w/2-x[0]/2, h/2-y[0]/2, 255, 255, 255, 255, -1, -1);
end

local ui = UiRoot:new()

_G.setCallback("gui.draw", function(w, h)
    ui:draw(w, h)
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