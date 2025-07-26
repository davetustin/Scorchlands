--[[
    server/Core/init.server.luau
    Description: The main server-side initialization script for Scorchlands.
    This script is responsible for setting up the core architecture,
    registering all game services, and managing their lifecycle.
]]

print("=== SERVER STARTUP BEGIN ===")

-- Require core modules based on the confirmed folder structure:
local Constants = require(game.ReplicatedStorage.Shared.Constants)
print("✓ Constants loaded")

local Server = script.Parent:WaitForChild("Server")
local CoreModulesPath = Server.Core
local SystemsModulesPath = Server.Systems
print("✓ Server paths resolved")

local Logger = require(game.ReplicatedStorage.Shared.Logger)
local ServiceRegistry = require(CoreModulesPath.ServiceRegistry)
local GlobalRegistry = require(CoreModulesPath.GlobalRegistry)
local DataManager = require(CoreModulesPath.DataManager)
local NetworkManager = require(game.ReplicatedStorage.Shared.NetworkManager)
local SunlightSystem = require(SystemsModulesPath.SunlightSystem)
local CommandSystem = require(CoreModulesPath.CommandSystem)
local BuildingSystem = require(SystemsModulesPath.BuildingSystem)
local ResourceSystem = require(SystemsModulesPath.ResourceSystem)
print("✓ All modules loaded")

-- Set up the Logger with the default log level from Constants
Logger.SetLogLevel(Constants.DEFAULT_LOG_LEVEL)
Logger.Info("init.server", "Server initialization started.")

-- Register network events (should be done on both client and server)
-- This is crucial for establishing communication channels.
print("Registering network events...")
for _, eventName in pairs(Constants.NETWORK_EVENTS) do
    NetworkManager.RegisterRemoteEvent(eventName)
    print("✓ Registered RemoteEvent:", eventName)
end

-- Also register the new command system events
NetworkManager.RegisterRemoteEvent("CommandExecute")
NetworkManager.RegisterRemoteEvent("CommandFeedback")
print("✓ Registered command system events")

-- NEW: Register BuildingSystem network events
print("Registering CLIENT_REQUEST_BUILD RemoteFunction...")
NetworkManager.RegisterRemoteFunction(Constants.REMOTE_FUNCTIONS.CLIENT_REQUEST_BUILD)
print("✓ Registered CLIENT_REQUEST_BUILD RemoteFunction")

print("Registering CLIENT_REQUEST_REPAIR RemoteFunction...")
NetworkManager.RegisterRemoteFunction(Constants.REMOTE_FUNCTIONS.CLIENT_REQUEST_REPAIR)
print("✓ Registered CLIENT_REQUEST_REPAIR RemoteFunction")

print("Registering CLIENT_REQUEST_GATHER_RESOURCE RemoteFunction...")
NetworkManager.RegisterRemoteFunction(Constants.REMOTE_FUNCTIONS.CLIENT_REQUEST_GATHER_RESOURCE)
print("✓ Registered CLIENT_REQUEST_GATHER_RESOURCE RemoteFunction")

-- Make some core modules globally accessible via GlobalRegistry if needed
-- This is an alternative to direct 'require' calls if you want a central lookup.
-- NOTE: This must happen BEFORE services are started so they can access these modules
GlobalRegistry.Set("Logger", Logger)
GlobalRegistry.Set("Constants", Constants)

-- Create and register DataManager instance with debugging
local dataManagerInstance = DataManager.new()
print("✓ DataManager instance created")
print("✓ DataManager type: " .. typeof(dataManagerInstance))
print("✓ DataManager LoadStructureData method: " .. tostring(dataManagerInstance.LoadStructureData))

GlobalRegistry.Set("DataManager", dataManagerInstance)
GlobalRegistry.Set("NetworkManager", NetworkManager) -- NetworkManager's methods are static for now

print("✓ Global modules registered")

-- Register all core services with the ServiceRegistry
print("Registering services...")
ServiceRegistry.RegisterService("SunlightSystem", SunlightSystem)
ServiceRegistry.RegisterService("CommandSystem", CommandSystem)
ServiceRegistry.RegisterService("BuildingSystem", BuildingSystem)
ServiceRegistry.RegisterService("ResourceSystem", ResourceSystem)
print("✓ All services registered")

-- Initialize all registered services
print("Initializing services...")
ServiceRegistry.InitAll()
print("✓ All services initialized")

-- Start all registered services
print("Starting services...")
ServiceRegistry.StartAll()
print("✓ All services started")

-- Services register themselves in GlobalRegistry during Start()
-- No need to register them again here
print("✓ Services started and self-registered in GlobalRegistry")

-- Set up RemoteFunction connections after services are started
print("Setting up RemoteFunction connections...")

-- Wait a moment for services to complete their GlobalRegistry registration
task.wait(0.1)

-- Get the services from GlobalRegistry with retry mechanism
local buildingSystem = nil
local resourceSystem = nil
local maxRetries = 5
local retryCount = 0

while (not buildingSystem or not resourceSystem) and retryCount < maxRetries do
    if not buildingSystem then
        buildingSystem = GlobalRegistry.Get("BuildingSystem")
    end
    if not resourceSystem then
        resourceSystem = GlobalRegistry.Get("ResourceSystem")
    end
    
    if not buildingSystem or not resourceSystem then
        retryCount = retryCount + 1
        print("Attempt " .. retryCount .. " to get services from GlobalRegistry...")
        task.wait(0.1) -- Wait 0.1 seconds before retrying
    end
end

-- Set up BuildingSystem RemoteFunction connections
if buildingSystem then
    local buildRequestFunction = NetworkManager.GetRemoteFunction(Constants.REMOTE_FUNCTIONS.CLIENT_REQUEST_BUILD)
    if buildRequestFunction then
        buildRequestFunction.OnServerInvoke = function(player, structureType, cframe)
            return buildingSystem:HandleBuildRequest(player, structureType, cframe)
        end
        print("✓ Connected CLIENT_REQUEST_BUILD RemoteFunction")
    end
    
    local repairRequestFunction = NetworkManager.GetRemoteFunction(Constants.REMOTE_FUNCTIONS.CLIENT_REQUEST_REPAIR)
    if repairRequestFunction then
        repairRequestFunction.OnServerInvoke = function(player, structureId)
            return buildingSystem:RepairStructure(structureId, player)
        end
        print("✓ Connected CLIENT_REQUEST_REPAIR RemoteFunction")
    end
else
    print("⚠ BuildingSystem not found in GlobalRegistry")
end

-- Set up ResourceSystem RemoteFunction connections
if resourceSystem then
    local gatherResourceFunction = NetworkManager.GetRemoteFunction(Constants.REMOTE_FUNCTIONS.CLIENT_REQUEST_GATHER_RESOURCE)
    if gatherResourceFunction then
        gatherResourceFunction.OnServerInvoke = function(player, nodeId)
            return resourceSystem:HandleGatherRequest(player, nodeId)
        end
        print("✓ Connected CLIENT_REQUEST_GATHER_RESOURCE RemoteFunction")
    end
else
    print("⚠ ResourceSystem not found in GlobalRegistry")
end

print("✓ RemoteFunction connections set up")

Logger.Info("init.server", "All core services initialized and started.")
Logger.Info("init.server", "Server is now running and ready for game logic.")

-- Force flush any remaining buffered logs to ensure startup logs are displayed immediately
Logger.FlushBuffer()

print("=== SERVER STARTUP COMPLETE ===")

-- Keep the server running
while true do
    task.wait(60) -- Wait for a minute to prevent script from stopping
end
