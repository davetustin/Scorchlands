--!native
--!optimize

--[[
    Core/ObjectPool.lua
    Description: Implements an object pooling pattern for efficient object reuse.
    Reduces garbage collection overhead and improves performance by recycling
    frequently created and destroyed objects (e.g., projectiles, effects).
    This is a generic placeholder.
]]
local ObjectPool = {}
local Logger = require(script.Parent.Logger)

function ObjectPool.new(objectFactory, initialSize, resetFunction)
    local self = setmetatable({}, ObjectPool)
    self._pool = {}
    self._objectFactory = objectFactory
    self._resetFunction = resetFunction or function(obj) end -- Default no-op reset
    self._totalCreated = 0

    -- Pre-fill the pool
    for i = 1, initialSize or 0 do
        self:Return(self._objectFactory())
    end

    Logger.Debug("ObjectPool", "Created new object pool with initial size: %d", initialSize or 0)
    return self
end

--[[
    ObjectPool:Get()
    Retrieves an object from the pool. If the pool is empty, creates a new one.
    @return any: An object instance.
]]
function ObjectPool:Get()
    local obj
    if #self._pool > 0 then
        obj = table.remove(self._pool)
        Logger.Debug("ObjectPool", "Reused object from pool. Pool size: %d", #self._pool)
    else
        obj = self._objectFactory()
        self._totalCreated = self._totalCreated + 1
        Logger.Debug("ObjectPool", "Created new object. Total created: %d", self._totalCreated)
    end
    return obj
end

--[[
    ObjectPool:Return(obj)
    Returns an object to the pool, resetting it if a reset function is provided.
    @param obj any: The object to return to the pool.
]]
function ObjectPool:Return(obj)
    if not obj then
        Logger.Warn("ObjectPool", "Attempted to return nil object to pool.")
        return
    end
    self._resetFunction(obj) -- Reset the object's state
    table.insert(self._pool, obj)
    Logger.Debug("ObjectPool", "Returned object to pool. Pool size: %d", #self._pool)
end

--[[
    ObjectPool:GetPoolSize()
    Returns the current number of objects in the pool.
    @return number: The current pool size.
]]
function ObjectPool:GetPoolSize()
    return #self._pool
end

--[[
    ObjectPool:GetTotalCreated()
    Returns the total number of objects ever created by this pool.
    @return number: The total number of created objects.
]]
function ObjectPool:GetTotalCreated()
    return self._totalCreated
end

return ObjectPool
