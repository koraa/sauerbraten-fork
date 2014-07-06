
local core = require "luvit.core"
local Emitter, instanceof = core.Emitter, core.instanceof

local Task = Emitter:extend()

function Task:initialize()
    self.references = 0
end

function Task:push(task)
    self.references = self.references + 1

    -- p("+", tostring(self), self.references, task)

    if instanceof(task, Task) then
        if task.references == nil then --Already finished
            return self:pop()
        end
        task:on("finish", function()
            self:pop()
        end)
        task:on("error", function(...)
            self:cancel(...)
        end)
    elseif type(task) == "function" then
        task()
    elseif task ~= nil then
        p(task)
        p(getmetatable(task))
        error("Unkown argument")
    end

end

function Task:pop()
    self.references = self.references - 1

    -- p("-", tostring(self), self.references)

    if self.references == 0 then
        self:emit("finish")
        self.references = nil
    end
end

function Task:cancel(...)
    self.references = -1
    self:emit("error", ...)
end

return {
    Task = Task,
    create = function() return Task:new() end
}