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

-- Register all core services with the ServiceRegistry
print("Registering services...")
ServiceRegistry.RegisterService("SunlightSystem", SunlightSystem)
ServiceRegistry.RegisterService("CommandSystem", CommandSystem)
ServiceRegistry.RegisterService("BuildingSystem", BuildingSystem)
print("✓ All services registered")

-- Initialize all registered services
print("Initializing services...")
ServiceRegistry.InitAll()
print("✓ All services initialized")

-- Start all registered services
print("Starting services...")
ServiceRegistry.StartAll()
print("✓ All services started")

-- Make some core modules globally accessible via GlobalRegistry if needed
-- This is an alternative to direct 'require' calls if you want a central lookup.
GlobalRegistry.Set("Logger", Logger)
GlobalRegistry.Set("Constants", Constants)
GlobalRegistry.Set("DataManager", DataManager.new()) -- Create an instance if it's not a service
GlobalRegistry.Set("NetworkManager", NetworkManager) -- NetworkManager's methods are static for now

Logger.Info("init.server", "All core services initialized and started.")
Logger.Info("init.server", "Server is now running and ready for game logic.")
print("=== SERVER STARTUP COMPLETE ===")

-- Keep the server running
while true do
    task.wait(60) -- Wait for a minute to prevent script from stopping
end
