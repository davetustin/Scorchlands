--!native
--!optimize

--[[
    Core/GlobalRegistry.lua
    Description: A central registry for global instances and data.
    This module provides a controlled way to access singletons or shared
    instances that are not necessarily services but need global access.
    Avoids excessive use of global variables.
]]
local GlobalRegistry = {}
local Logger = require(script.Parent.Logger)

local registry = {}

--[[
    GlobalRegistry.Set(key, value)
    Sets a value in the global registry.
    @param key string: The unique key for the value.
    @param value any: The value to store.
]]
function GlobalRegistry.Set(key, value)
    if registry[key] then
        Logger.Warn("GlobalRegistry", "Key '%s' already exists. Overwriting.", key)
    end
    registry[key] = value
    Logger.Debug("GlobalRegistry", "Set key: %s", key)
end

--[[
    GlobalRegistry.Get(key)
    Retrieves a value from the global registry.
    @param key string: The key of the value to retrieve.
    @return any: The stored value, or nil if not found.
]]
function GlobalRegistry.Get(key)
    local value = registry[key]
    if not value then
        Logger.Warn("GlobalRegistry", "Attempted to get non-existent key: %s", key)
    end
    return value
end

--[[
    GlobalRegistry.Remove(key)
    Removes a value from the global registry.
    @param key string: The key of the value to remove.
]]
function GlobalRegistry.Remove(key)
    if registry[key] then
        registry[key] = nil
        Logger.Debug("GlobalRegistry", "Removed key: %s", key)
    else
        Logger.Warn("GlobalRegistry", "Attempted to remove non-existent key: %s", key)
    end
end

--[[
    GlobalRegistry.Clear()
    Clears all entries from the global registry.
]]
function GlobalRegistry.Clear()
    registry = {}
    Logger.Info("GlobalRegistry", "Cleared all entries.")
end

return GlobalRegistry
