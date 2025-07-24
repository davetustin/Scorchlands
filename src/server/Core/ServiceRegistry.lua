--[[
    Core/ServiceRegistry.lua
    Description: Manages the registration, initialization, and retrieval of game services.
    Ensures services are properly initialized and started in a controlled order,
    preventing race conditions and dependency issues.
]]
local ServiceRegistry = {}
local Logger = require(script.Parent.Logger)
local BaseService = require(script.Parent.BaseService)

local services = {} -- Stores service instances by name
local serviceOrder = {} -- Stores service names in their intended initialization/start order

-- Helper function to check if an instance or class table inherits from BaseService
-- This traverses the metatable chain (which defines class inheritance)
local function inheritsFromBaseService(instanceOrClass)
    local currentTable = instanceOrClass -- Start with the instance or class table
    while currentTable do
        local mt = getmetatable(currentTable)
        if mt == BaseService then
            return true
        end
        -- If the metatable is a table, and it's not BaseService, then it might be a child class table.
        -- We need to move up to this metatable to continue traversing the inheritance chain.
        if typeof(mt) == "table" then
            currentTable = mt -- Move up to the metatable (which is the class table for instances, or parent class table for class tables)
        else
            -- If no more metatables or not a table, stop the traversal.
            break
        end
    end
    return false
end

--[[
    ServiceRegistry.RegisterService(serviceName, serviceClass)
    Registers a service with the registry.
    @param serviceName string: The unique name of the service.
    @param serviceClass table: The class (constructor) of the service, which should inherit from BaseService.
]]
function ServiceRegistry.RegisterService(serviceName, serviceClass)
    if services[serviceName] then
        Logger.Warn("ServiceRegistry", "Service '%s' already registered.", serviceName)
        return
    end

    if not serviceClass or not serviceClass.new or typeof(serviceClass.new) ~= "function" then
        Logger.Error("ServiceRegistry", "Service '%s' class is invalid. Must have a 'new' constructor.", serviceName)
        return
    end

    local serviceInstance = serviceClass.new(serviceName)
    -- CORRECTED: Use the refined inheritsFromBaseService function
    if not (typeof(serviceInstance) == "table" and inheritsFromBaseService(serviceInstance)) then
        Logger.Error("ServiceRegistry", "Service '%s' does not inherit from BaseService.", serviceName)
        return
    end

    services[serviceName] = serviceInstance
    table.insert(serviceOrder, serviceName)
    Logger.Debug("ServiceRegistry", "Registered service: %s", serviceName)
end

--[[
    ServiceRegistry.Get(serviceName)
    Retrieves a registered service instance.
    @param serviceName string: The name of the service to retrieve.
    @return table: The service instance, or nil if not found.
]]
function ServiceRegistry.Get(serviceName)
    local service = services[serviceName]
    if not service then
        Logger.Warn("ServiceRegistry", "Attempted to get unregistered service: %s", serviceName)
    end
    return service
end

--[[
    ServiceRegistry.InitAll()
    Initializes all registered services in the order they were registered.
]]
function ServiceRegistry.InitAll()
    Logger.Info("ServiceRegistry", "Initializing all services...")
    for _, serviceName in ipairs(serviceOrder) do
        local service = services[serviceName]
        if service then
            service:Init()
        end
    end
    Logger.Info("ServiceRegistry", "All services initialized.")
end

--[[
    ServiceRegistry.StartAll()
    Starts all registered services in the order they were registered.
]]
function ServiceRegistry.StartAll()
    Logger.Info("ServiceRegistry", "Starting all services...")
    for _, serviceName in ipairs(serviceOrder) do
        local service = services[serviceName]
        if service then
            service:Start()
        end
    end
    Logger.Info("ServiceRegistry", "All services started.")
end

--[[
    ServiceRegistry.StopAll()
    Stops all registered services in reverse order.
]]
function ServiceRegistry.StopAll()
    Logger.Info("ServiceRegistry", "Stopping all services...")
    for i = #serviceOrder, 1, -1 do
        local serviceName = serviceOrder[i]
        local service = services[serviceName]
        if service then
            service:Stop()
        end
    end
    Logger.Info("ServiceRegistry", "All services stopped.")
end

--[[
    ServiceRegistry.DestroyAll()
    Destroys all registered services, cleaning up resources.
]]
function ServiceRegistry.DestroyAll()
    Logger.Info("ServiceRegistry", "Destroying all services...")
    for i = #serviceOrder, 1, -1 do
        local serviceName = serviceOrder[i]
        local service = services[serviceName]
        if service then
            service:Destroy()
            services[serviceName] = nil -- Dereference
        end
    end
    serviceOrder = {} -- Clear the order list
    Logger.Info("ServiceRegistry", "All services destroyed.")
end

return ServiceRegistry
