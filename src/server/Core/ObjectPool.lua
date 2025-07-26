--[[
    Core/ObjectPool.lua
    Description: Object pooling system for performance optimization.
    Reuses objects instead of creating/destroying them, reducing garbage collection
    and improving performance for frequently created/destroyed objects.
]]
local ObjectPool = {}
local Logger = require(game.ReplicatedStorage.Shared.Logger)

-- Performance constants
local DEFAULT_POOL_SIZE = 50
local MAX_POOL_SIZE = 200
local CLEANUP_INTERVAL = 30 -- seconds
local MAX_IDLE_TIME = 60 -- seconds

local _pools = {} -- Stores pools by object type
local _poolStats = {} -- Tracks pool usage statistics
local _lastCleanup = tick()

function ObjectPool.new()
    local self = setmetatable({}, ObjectPool)
    Logger.Debug("ObjectPool", "ObjectPool instance created.")
    return self
end

--[[
    ObjectPool:CreatePool(objectType, createFunction, resetFunction, initialSize)
    Creates a new object pool for a specific type of object.
    @param objectType string: The type of object this pool manages.
    @param createFunction function: Function that creates a new object instance.
    @param resetFunction function: Function that resets an object to its initial state.
    @param initialSize number: Initial number of objects to create in the pool.
]]
function ObjectPool:CreatePool(objectType, createFunction, resetFunction, initialSize)
    if _pools[objectType] then
        Logger.Warn("ObjectPool", "Pool for '%s' already exists.", objectType)
        return
    end

    if type(createFunction) ~= "function" or type(resetFunction) ~= "function" then
        Logger.Error("ObjectPool", "Invalid create or reset function for pool '%s'.", objectType)
        return
    end

    initialSize = initialSize or DEFAULT_POOL_SIZE
    initialSize = math.min(initialSize, MAX_POOL_SIZE)

    local pool = {
        available = {}, -- Stack of available objects
        inUse = {}, -- Objects currently in use
        createFunction = createFunction,
        resetFunction = resetFunction,
        created = 0,
        reused = 0,
        lastUsed = tick()
    }

    -- Pre-populate the pool
    for i = 1, initialSize do
        local obj = createFunction()
        if obj then
            table.insert(pool.available, obj)
            pool.created = pool.created + 1
        end
    end

    _pools[objectType] = pool
    _poolStats[objectType] = {
        totalCreated = pool.created,
        totalReused = 0,
        peakUsage = 0
    }

    Logger.Info("ObjectPool", "Created pool for '%s' with %d initial objects.", objectType, initialSize)
end

--[[
    ObjectPool:GetObject(objectType)
    Gets an object from the pool, creating a new one if necessary.
    @param objectType string: The type of object to get.
    @return any: The object instance, or nil if pool doesn't exist.
]]
function ObjectPool:GetObject(objectType)
    local pool = _pools[objectType]
    if not pool then
        Logger.Warn("ObjectPool", "Pool for '%s' does not exist.", objectType)
        return nil
    end

    pool.lastUsed = tick()
    local obj

    if #pool.available > 0 then
        -- Reuse an existing object
        obj = table.remove(pool.available)
        pool.resetFunction(obj)
        pool.reused = pool.reused + 1
        _poolStats[objectType].totalReused = _poolStats[objectType].totalReused + 1
    else
        -- Create a new object if pool is empty
        obj = pool.createFunction()
        if obj then
            pool.created = pool.created + 1
            _poolStats[objectType].totalCreated = _poolStats[objectType].totalCreated + 1
        else
            Logger.Error("ObjectPool", "Failed to create new object for pool '%s'.", objectType)
            return nil
        end
    end

    -- Track object usage
    pool.inUse[obj] = tick()
    
    -- Update peak usage
    local currentUsage = pool.created - #pool.available
    if currentUsage > _poolStats[objectType].peakUsage then
        _poolStats[objectType].peakUsage = currentUsage
    end

    return obj
end

--[[
    ObjectPool:ReturnObject(objectType, obj)
    Returns an object to the pool for reuse.
    @param objectType string: The type of object being returned.
    @param obj any: The object to return to the pool.
]]
function ObjectPool:ReturnObject(objectType, obj)
    local pool = _pools[objectType]
    if not pool then
        Logger.Warn("ObjectPool", "Pool for '%s' does not exist.", objectType)
        return
    end

    if not pool.inUse[obj] then
        Logger.Warn("ObjectPool", "Object not tracked as in use for pool '%s'.", objectType)
        return
    end

    -- Remove from in-use tracking
    pool.inUse[obj] = nil

    -- Reset the object
    pool.resetFunction(obj)

    -- Return to available pool (with size limit)
    if #pool.available < MAX_POOL_SIZE then
        table.insert(pool.available, obj)
    else
        -- Pool is full, destroy the object
        if obj.Destroy then
            obj:Destroy()
        elseif obj.destroy then
            obj:destroy()
        end
        pool.created = pool.created - 1
        Logger.Debug("ObjectPool", "Pool '%s' full, destroyed returned object.", objectType)
    end
end

--[[
    ObjectPool:GetPoolStats(objectType)
    Gets statistics for a specific pool.
    @param objectType string: The type of object to get stats for.
    @return table: Pool statistics, or nil if pool doesn't exist.
]]
function ObjectPool:GetPoolStats(objectType)
    local pool = _pools[objectType]
    if not pool then
        return nil
    end

    local stats = _poolStats[objectType]
    local currentUsage = pool.created - #pool.available
    local efficiency = pool.created > 0 and (stats.totalReused / pool.created) * 100 or 0

    return {
        totalCreated = stats.totalCreated,
        totalReused = stats.totalReused,
        currentUsage = currentUsage,
        available = #pool.available,
        efficiency = efficiency,
        peakUsage = stats.peakUsage
    }
end

--[[
    ObjectPool:GetAllStats()
    Gets statistics for all pools.
    @return table: Statistics for all pools.
]]
function ObjectPool:GetAllStats()
    local allStats = {}
    for objectType, _ in pairs(_pools) do
        allStats[objectType] = self:GetPoolStats(objectType)
    end
    return allStats
end

--[[
    ObjectPool:Cleanup()
    Performs periodic cleanup of idle pools and objects.
]]
function ObjectPool:Cleanup()
    local currentTime = tick()
    
    -- Only cleanup periodically
    if currentTime - _lastCleanup < CLEANUP_INTERVAL then
        return
    end

    _lastCleanup = currentTime
    local cleanedPools = 0
    local cleanedObjects = 0

    for objectType, pool in pairs(_pools) do
        -- Check if pool has been idle for too long
        if currentTime - pool.lastUsed > MAX_IDLE_TIME then
            -- Clean up idle objects in the available pool
            local initialAvailable = #pool.available
            for i = #pool.available, 1, -1 do
                local obj = pool.available[i]
                if obj.Destroy then
                    obj:Destroy()
                elseif obj.destroy then
                    obj:destroy()
                end
                table.remove(pool.available, i)
                pool.created = pool.created - 1
                cleanedObjects = cleanedObjects + 1
            end
            
            if initialAvailable > 0 then
                cleanedPools = cleanedPools + 1
                Logger.Debug("ObjectPool", "Cleaned up %d idle objects from pool '%s'.", initialAvailable, objectType)
            end
        end
    end

    if cleanedPools > 0 then
        Logger.Info("ObjectPool", "Cleanup completed: %d pools, %d objects cleaned.", cleanedPools, cleanedObjects)
    end
end

--[[
    ObjectPool:DestroyPool(objectType)
    Destroys a specific pool and all its objects.
    @param objectType string: The type of object pool to destroy.
]]
function ObjectPool:DestroyPool(objectType)
    local pool = _pools[objectType]
    if not pool then
        Logger.Warn("ObjectPool", "Pool for '%s' does not exist.", objectType)
        return
    end

    local destroyedCount = 0

    -- Destroy all available objects
    for _, obj in ipairs(pool.available) do
        if obj.Destroy then
            obj:Destroy()
        elseif obj.destroy then
            obj:destroy()
        end
        destroyedCount = destroyedCount + 1
    end

    -- Destroy all in-use objects
    for obj, _ in pairs(pool.inUse) do
        if obj.Destroy then
            obj:Destroy()
        elseif obj.destroy then
            obj:destroy()
        end
        destroyedCount = destroyedCount + 1
    end

    _pools[objectType] = nil
    _poolStats[objectType] = nil

    Logger.Info("ObjectPool", "Destroyed pool '%s' with %d objects.", objectType, destroyedCount)
end

--[[
    ObjectPool:DestroyAllPools()
    Destroys all pools and their objects.
]]
function ObjectPool:DestroyAllPools()
    local totalDestroyed = 0
    
    for objectType, _ in pairs(_pools) do
        local pool = _pools[objectType]
        local poolCount = #pool.available + #pool.inUse
        totalDestroyed = totalDestroyed + poolCount
        
        self:DestroyPool(objectType)
    end

    Logger.Info("ObjectPool", "Destroyed all pools with %d total objects.", totalDestroyed)
end

return ObjectPool
