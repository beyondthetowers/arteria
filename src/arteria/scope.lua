-- Cancellable ownership for legacy farm work. Never cancels unrelated tasks.
local Scope = {}
Scope.__index = Scope
function Scope.new(raw_task)
    raw_task = raw_task or task
    local self = setmetatable({ active = true, threads = {}, resources = {}, raw_task = raw_task }, Scope)
    local function schedule(method, delay, callback, ...)
        assert(self.active, "Echo farm stopped")
        local args = table.pack(...)
        local thread
        local function run()
            if not self.active then return end
            local ok, err = pcall(callback, table.unpack(args, 1, args.n))
            self.threads[coroutine.running()] = nil
            if not ok and self.active and self.on_error then self.on_error(err) end
        end
        if method == "delay" then thread = raw_task.delay(delay, run)
        else thread = raw_task.defer(run) end
        self.threads[thread] = true
        return thread
    end
    self.task = {
        spawn = function(callback, ...) return schedule("defer", 0, callback, ...) end,
        defer = function(callback, ...) return schedule("defer", 0, callback, ...) end,
        delay = function(seconds, callback, ...) return schedule("delay", seconds, callback, ...) end,
        wait = function(seconds)
            assert(self.active, "Echo farm stopped")
            local elapsed = raw_task.wait(seconds)
            assert(self.active, "Echo farm stopped")
            return elapsed
        end,
        cancel = function(thread) self.threads[thread] = nil; return raw_task.cancel(thread) end,
    }
    return self
end
function Scope:track(resource)
    if not self.active then
        if typeof(resource) == "RBXScriptConnection" then resource:Disconnect()
        elseif type(resource) == "function" then resource() end
        return resource
    end
    table.insert(self.resources, resource)
    return resource
end
function Scope:stop()
    if not self.active then return end
    self.active = false
    local running = coroutine.running()
    for thread in pairs(self.threads) do if thread ~= running then pcall(self.raw_task.cancel, thread) end end
    table.clear(self.threads)
    for _, resource in ipairs(self.resources) do
        if type(resource) == "function" then pcall(resource)
        else pcall(function() resource:Disconnect() end) end
    end
    table.clear(self.resources)
end
return Scope
