--[[
    server/Core/init.server.luau
    Description: The main server-side initialization script for Scorchlands.
    This script is responsible for setting up the core architecture,
    registering all game services, and managing their lifecycle.
]]

print("=== SERVER STARTUP BEGIN ===")

-- Require core modules
local Logger = require(game.ReplicatedStorage.Shared.Logger)
local Constants = require(game.ReplicatedStorage.Shared.Constants)
local DataManager = require(game.ServerScriptService.Server.Core.DataManager)
local NetworkManager = require(game.ReplicatedStorage.Shared.NetworkManager)
local ServiceRegistry = require(game.ServerScriptService.Server.Core.ServiceRegistry)
local GlobalRegistry = require(game.ServerScriptService.Server.Core.GlobalRegistry)

-- Register core modules in GlobalRegistry for service access
GlobalRegistry.Set("Logger", Logger)
GlobalRegistry.Set("Constants", Constants)
GlobalRegistry.Set("DataManager", DataManager)
GlobalRegistry.Set("NetworkManager", NetworkManager)

-- NEW: Require BuildingModelBuilder with error handling
local BuildingModelBuilder = nil
print("Attempting to load BuildingModelBuilder...")
local success, result = pcall(function()
    return require(game.ReplicatedStorage.Shared.BuildingModelBuilder)
end)
if success then
    BuildingModelBuilder = result
    print("✓ BuildingModelBuilder loaded successfully")
else
    print("⚠ Failed to load BuildingModelBuilder: " .. tostring(result))
    print("Error details: " .. debug.traceback())
end

-- Require services
local BuildingSystem = require(game.ServerScriptService.Server.Systems.BuildingSystem)
local SunlightSystem = require(game.ServerScriptService.Server.Systems.SunlightSystem)
local ResourceSystem = require(game.ServerScriptService.Server.Systems.ResourceSystem)
local CommandSystem = require(game.ServerScriptService.Server.Core.CommandSystem)

-- Initialize core modules
-- Note: Logger, DataManager, and NetworkManager don't have Init() methods
-- They are initialized when required

-- NEW: Create building models
if BuildingModelBuilder then
    BuildingModelBuilder:CreateAllModels()
    print("✓ Building models created")
else
    print("⚠ BuildingModelBuilder not loaded, skipping building model creation.")
end

-- Register network events and functions
NetworkManager.RegisterRemoteEvent("CommandExecute")
NetworkManager.RegisterRemoteEvent("CommandFeedback")
NetworkManager.RegisterRemoteEvent("ServerNotifyResourceGathered")
NetworkManager.RegisterRemoteEvent("ServerNotifyResourceNodeUpdate")
NetworkManager.RegisterRemoteFunction("ClientRequestBuild")
NetworkManager.RegisterRemoteFunction("ClientRequestRepair")
NetworkManager.RegisterRemoteFunction("ClientRequestGatherResource")

-- Register services
ServiceRegistry.RegisterService("BuildingSystem", BuildingSystem)
ServiceRegistry.RegisterService("SunlightSystem", SunlightSystem)
ServiceRegistry.RegisterService("ResourceSystem", ResourceSystem)
ServiceRegistry.RegisterService("CommandSystem", CommandSystem)

-- Initialize all services first
ServiceRegistry.InitAll()

-- Start all services
ServiceRegistry.StartAll()

-- Set up RemoteFunction connections after services are started
task.wait(0.1) -- Give services time to register in GlobalRegistry

-- Retry mechanism for getting services from GlobalRegistry
local maxRetries = 5
local retryCount = 0
local buildingSystem = nil
local resourceSystem = nil

while (not buildingSystem or not resourceSystem) and retryCount < maxRetries do
    if not buildingSystem then
        buildingSystem = GlobalRegistry.Get("BuildingSystem")
    end
    if not resourceSystem then
        resourceSystem = GlobalRegistry.Get("ResourceSystem")
    end
    
    if not buildingSystem or not resourceSystem then
        retryCount = retryCount + 1
        Logger.Debug("Server", "Attempt %d to get services from GlobalRegistry...", retryCount)
        task.wait(0.1)
    end
end

-- Connect CLIENT_REQUEST_BUILD RemoteFunction
if buildingSystem then
    local clientRequestBuild = NetworkManager.GetRemoteFunction(Constants.REMOTE_FUNCTIONS.CLIENT_REQUEST_BUILD)
    if clientRequestBuild then
        clientRequestBuild.OnServerInvoke = function(player, structureType, cframe)
            return buildingSystem:HandleBuildRequest(player, structureType, cframe)
        end
        Logger.Debug("Server", "✓ Connected CLIENT_REQUEST_BUILD RemoteFunction")
    else
        Logger.Warn("Server", "⚠ CLIENT_REQUEST_BUILD RemoteFunction not found")
    end
else
    Logger.Warn("Server", "⚠ BuildingSystem not found in GlobalRegistry")
end

-- Connect CLIENT_REQUEST_REPAIR RemoteFunction
if buildingSystem then
    local clientRequestRepair = NetworkManager.GetRemoteFunction(Constants.REMOTE_FUNCTIONS.CLIENT_REQUEST_REPAIR)
    if clientRequestRepair then
        clientRequestRepair.OnServerInvoke = function(player, structureId)
            return buildingSystem:HandleRepairRequest(player, structureId)
        end
        Logger.Debug("Server", "✓ Connected CLIENT_REQUEST_REPAIR RemoteFunction")
    else
        Logger.Warn("Server", "⚠ CLIENT_REQUEST_REPAIR RemoteFunction not found")
    end
else
    Logger.Warn("Server", "⚠ BuildingSystem not found in GlobalRegistry")
end

-- Connect CLIENT_REQUEST_GATHER_RESOURCE RemoteFunction
if resourceSystem then
    local clientRequestGatherResource = NetworkManager.GetRemoteFunction(Constants.REMOTE_FUNCTIONS.CLIENT_REQUEST_GATHER_RESOURCE)
    if clientRequestGatherResource then
        clientRequestGatherResource.OnServerInvoke = function(player, nodeId)
            return resourceSystem:HandleGatherRequest(player, nodeId)
        end
        Logger.Debug("Server", "✓ Connected CLIENT_REQUEST_GATHER_RESOURCE RemoteFunction")
    else
        Logger.Warn("Server", "⚠ CLIENT_REQUEST_GATHER_RESOURCE RemoteFunction not found")
    end
else
    Logger.Warn("Server", "⚠ ResourceSystem not found in GlobalRegistry")
end

Logger.Debug("Server", "✓ RemoteFunction connections set up")

-- Handle player joining
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
    Logger.Info("Server", "Loading structures for joining player %s (UserId: %d)", player.Name, player.UserId)
    
    -- Load player's structures
    if buildingSystem then
        buildingSystem:LoadPlayerStructures(player)
    end
end)

-- Handle player leaving
-- Note: BuildingSystem handles player leaving in its OnPlayerLeaving method
-- No additional save call needed here to avoid duplicate saves

Logger.Info("Server", "Server initialization complete")

-- Force flush any remaining buffered logs to ensure startup logs are displayed immediately
Logger.FlushBuffer()

print("=== SERVER STARTUP COMPLETE ===")

-- Keep the server running
while true do
    task.wait(60) -- Wait for a minute to prevent script from stopping
end
