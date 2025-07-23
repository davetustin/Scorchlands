--!native
--!optimize

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

local remoteEvents = {}
local remoteFunctions = {}

--[[
    NetworkManager.RegisterRemoteEvent(eventName)
    Registers a RemoteEvent. This should be called on both client and server.
    @param eventName string: The name of the RemoteEvent (should match Constants.NETWORK_EVENTS).
]]
function NetworkManager.RegisterRemoteEvent(eventName)
    if remoteEvents[eventName] then
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
    remoteEvents[eventName] = remoteEvent
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
    if remoteFunctions[functionName] then
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
    remoteFunctions[functionName] = remoteFunction
    if Logger then
        Logger.Debug("NetworkManager", "Registered RemoteFunction: %s", functionName)
    end
end

--[[
    NetworkManager.GetRemoteEvent(eventName)
    Retrieves a registered RemoteEvent.
    If called on the client, it will wait for the RemoteEvent to exist in ReplicatedStorage.
    @param eventName string: The name of the RemoteEvent.
    @return RemoteEvent: The RemoteEvent instance, or nil if not found (on server) or timeout (on client).
]]
function NetworkManager.GetRemoteEvent(eventName)
    local event = remoteEvents[eventName]
    if event then
        return event
    end

    -- If not found in our internal table, try to find it in ReplicatedStorage
    -- and potentially wait for it if on the client.
    if RunService:IsClient() then
        -- On client, wait for it to be replicated from the server
        local replicatedEvent = ReplicatedStorage:WaitForChild(eventName, 10) -- 10-second timeout
        if replicatedEvent and replicatedEvent:IsA("RemoteEvent") then
            remoteEvents[eventName] = replicatedEvent -- Cache it for future calls
            return replicatedEvent
        else
            if Logger then
                Logger.Error("NetworkManager", "Client: Timed out or failed to get RemoteEvent: %s", eventName)
            else
                error("NetworkManager: Client: Timed out or failed to get RemoteEvent: " .. eventName)
            end
            return nil -- Return nil on timeout/failure
        end
    else -- On server
        if Logger then
            Logger.Error("NetworkManager", "Server: Attempted to get unregistered RemoteEvent: %s", eventName)
        else
            error("NetworkManager: Server: Attempted to get unregistered RemoteEvent: " .. eventName)
        end
        return nil
    end
end

--[[
    NetworkManager.GetRemoteFunction(functionName)
    Retrieves a registered RemoteFunction.
    If called on the client, it will wait for the RemoteFunction to exist in ReplicatedStorage.
    @param functionName string: The name of the RemoteFunction.
    @return RemoteFunction: The RemoteFunction instance, or nil if not found (on server) or timeout (on client).
]]
function NetworkManager.GetRemoteFunction(functionName)
    local func = remoteFunctions[functionName]
    if func then
        return func
    end

    if RunService:IsClient() then
        local replicatedFunction = ReplicatedStorage:WaitForChild(functionName, 10) -- 10-second timeout
        if replicatedFunction and replicatedFunction:IsA("RemoteFunction") then
            remoteFunctions[functionName] = replicatedFunction -- Cache it for future calls
            return replicatedFunction
        else
            if Logger then
                Logger.Error("NetworkManager", "Client: Timed out or failed to get RemoteFunction: %s", functionName)
            else
                error("NetworkManager: Client: Timed out or failed to get RemoteFunction: " .. functionName)
            end
            return nil
        end
    else -- On server
        if Logger then
            Logger.Error("NetworkManager", "Server: Attempted to get unregistered RemoteFunction: %s", functionName)
        else
            error("NetworkManager: Server: Attempted to get unregistered RemoteFunction: " .. functionName)
        end
        return nil
    end
end

-- Example usage on server:
-- NetworkManager.GetRemoteEvent(Constants.NETWORK_EVENTS.CLIENT_REQUEST_BUILD).OnServerEvent:Connect(function(player, ...)
--     -- Handle build request
-- end)

-- Example usage on client:
-- NetworkManager.GetRemoteEvent(Constants.NETWORK_EVENTS.SERVER_NOTIFY_HEALTH_UPDATE):FireServer(...)

return NetworkManager
