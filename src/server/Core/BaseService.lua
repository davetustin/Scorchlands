--[[
    Core/BaseService.lua
    Description: Base class for all game services.
    Provides common functionality and a standardized lifecycle for services,
    including initialization, start-up, and shutdown methods.
    Encourages modularity and clear responsibilities.
]]
local BaseService = {}
local Logger = require(script.Parent.Logger) -- Logger is in the same Core folder

BaseService.__index = BaseService

function BaseService.new(serviceName)
    local self = setmetatable({}, BaseService)
    self._serviceName = serviceName or "UnnamedService"
    self._isInitialized = false
    self._isStarted = false
    Logger.Debug("BaseService", "Created service: %s", self._serviceName)
    return self
end

--[[
    :Init()
    Initializes the service. This method should be overridden by child services
    to perform one-time setup tasks that do not depend on other services being started.
]]
function BaseService:Init()
    if self._isInitialized then
        Logger.Warn(self._serviceName, "Service already initialized.")
        return
    end
    self._isInitialized = true
    Logger.Info(self._serviceName, "Service initialized.")
end

--[[
    :Start()
    Starts the service. This method should be overridden by child services
    to begin their main operations, potentially depending on other services
    that have also started.
]]
function BaseService:Start()
    if not self._isInitialized then
        Logger.Warn(self._serviceName, "Service not initialized before starting.")
        self:Init() -- Attempt to initialize if not already
    end
    if self._isStarted then
        Logger.Warn(self._serviceName, "Service already started.")
        return
    end
    self._isStarted = true
    Logger.Info(self._serviceName, "Service started.")
end

--[[
    :Stop()
    Stops the service. This method should be overridden by child services
    to clean up resources, disconnect events, etc., before shutdown.
]]
function BaseService:Stop()
    if not self._isStarted then
        Logger.Warn(self._serviceName, "Service not started, cannot stop.")
        return
    end
    self._isStarted = false
    Logger.Info(self._serviceName, "Service stopped.")
end

--[[
    :Destroy()
    Cleans up the service entirely. This method should be overridden by child services
    to perform final cleanup before the service is garbage collected.
]]
function BaseService:Destroy()
    self:Stop() -- Ensure service is stopped before destroying
    Logger.Info(self._serviceName, "Service destroyed.")
    -- Clear metatable to prevent further calls
    setmetatable(self, nil)
end

function BaseService:IsInitialized()
    return self._isInitialized
end

function BaseService:IsStarted()
    return self._isStarted
end

function BaseService:GetServiceName()
    return self._serviceName
end

return BaseService
