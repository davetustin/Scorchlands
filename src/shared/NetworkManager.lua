--[[
    ReplicatedStorage/Shared/NetworkManager.lua
    Description: Manages client-server communication via RemoteEvents and RemoteFunctions.
    Provides a centralized and type-safe way to define and handle network events,
    improving security and maintainability. This module is placed in ReplicatedStorage.Shared
    to be accessible by both server and client scripts.
]]
local NetworkManager = {}
local Constants = require(script.Parent.Constants) -- Constants is in the same Shared folder

-- Attempt to require Logger only if running on the server.
-- On the client, ServerScriptService does not exist, so this will be nil.
local Logger = nil
local RunService = game:GetService("RunService")
if RunService:IsServer() then
    Logger = require(game.ServerScriptService.Core.Logger)
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Internal tables to store references to created remotes (primarily used by server for quick lookup)
local _remoteEvents = {}
local _remoteFunctions = {}

--[[
    NetworkManager.RegisterRemoteEvent(eventName)
    Registers a RemoteEvent. This should be called on both client and server.
    @param eventName string: The name of the RemoteEvent (should match Constants.NETWORK_EVENTS).
]]
function NetworkManager.RegisterRemoteEvent(eventName)
    if _remoteEvents[eventName] then
        if Logger then
            Logger.Warn("NetworkManager", "RemoteEvent '%s' already registered.", eventName)
        else
            warn("NetworkManager: RemoteEvent '" .. eventName .. "' already registered.")
        end
        return
    end
    local remoteEvent = Instance.new("RemoteEvent")
    remoteEvent.Name = eventName
    remoteEvent.Parent = ReplicatedStorage -- Or a dedicated "Remotes" folder
    _remoteEvents[eventName] = remoteEvent -- Cache it internally
    if Logger then
        Logger.Debug("NetworkManager", "Registered RemoteEvent: %s", eventName)
    end
end

--[[
    NetworkManager.RegisterRemoteFunction(functionName)
    Registers a RemoteFunction. This should be called on both client and server.
    @param functionName string: The name of the RemoteFunction (should match Constants.NETWORK_EVENTS).
]]
function NetworkManager.RegisterRemoteFunction(functionName)
    if _remoteFunctions[functionName] then
        if Logger then
            Logger.Warn("NetworkManager", "RemoteFunction '%s' already registered.", functionName)
        else
            warn("NetworkManager: RemoteFunction '" .. functionName .. "' already registered.")
        end
        return
    end
    local remoteFunction = Instance.new("RemoteFunction")
    remoteFunction.Name = functionName
    remoteFunction.Parent = ReplicatedStorage -- Or a dedicated "Remotes" folder
    _remoteFunctions[functionName] = remoteFunction -- Cache it internally
    if Logger then
        Logger.Debug("NetworkManager", "Registered RemoteFunction: %s", functionName)
    end
end

--[[
    NetworkManager.GetRemoteEvent(eventName)
    Retrieves a registered RemoteEvent.
    If called on the client, it will wait for the RemoteEvent to exist in ReplicatedStorage.
    @param eventName string: The name of the RemoteEvent.
    @return RemoteEvent: The RemoteEvent instance, or nil if not found or timeout (on client).
]]
function NetworkManager.GetRemoteEvent(eventName)
    if RunService:IsClient() then
        -- On client, always wait for it to be replicated from the server
        local replicatedEvent = ReplicatedStorage:WaitForChild(eventName, 10) -- 10-second timeout
        if replicatedEvent and replicatedEvent:IsA("RemoteEvent") then
            return replicatedEvent
        else
            -- Use error() on client if it fails to ensure developer sees it
            error("NetworkManager: Client: Timed out or failed to get RemoteEvent: " .. eventName)
        end
    else -- On server
        local event = _remoteEvents[eventName]
        if not event then
            -- Use error() on server if it fails
            error("NetworkManager: Server: Attempted to get unregistered RemoteEvent: " .. eventName)
        end
        return event
    end
end

--[[
    NetworkManager.GetRemoteFunction(functionName)
    Retrieves a registered RemoteFunction.
    If called on the client, it will wait for the RemoteFunction to exist in ReplicatedStorage.
    @param functionName string: The name of the RemoteFunction.
    @return RemoteFunction: The RemoteFunction instance, or nil if not found or timeout (on client).
]]
function NetworkManager.GetRemoteFunction(functionName)
    if RunService:IsClient() then
        -- On client, always wait for it to be replicated from the server
        local replicatedFunction = ReplicatedStorage:WaitForChild(functionName, 10) -- 10-second timeout
        if replicatedFunction and replicatedFunction:IsA("RemoteFunction") then
            return replicatedFunction
        else
            -- Use error() on client if it fails to ensure developer sees it
            error("NetworkManager: Client: Timed out or failed to get RemoteFunction: " .. functionName)
        end
    else -- On server
        local func = _remoteFunctions[functionName]
        if not func then
            -- Use error() on server if it fails
            error("NetworkManager: Server: Attempted to get unregistered RemoteFunction: " .. functionName)
        end
        return func
    end
end

-- Example usage on server:
-- NetworkManager.GetRemoteEvent(Constants.NETWORK_EVENTS.CLIENT_REQUEST_BUILD).OnServerEvent:Connect(function(player, ...)
--     -- Handle build request
-- end)

-- Example usage on client:
-- NetworkManager.GetRemoteEvent(Constants.NETWORK_EVENTS.SERVER_NOTIFY_HEALTH_UPDATE):FireServer(...)

return NetworkManager
