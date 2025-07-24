--!native
--!optimize

--[[
    server/Core/init.server.luau
    Description: The main server-side initialization script for Scorchlands.
    This script is responsible for setting up the core architecture,
    registering all game services, and managing their lifecycle.
]]

-- Require core modules based on the confirmed folder structure:
-- Constants is in ReplicatedStorage.Shared
local Constants = require(game.ReplicatedStorage.Shared.Constants)
-- All other core modules are in the 'Core' folder, which is likely a sibling to this script
-- if this script itself is named 'Core' and placed directly under ServerScriptService.
local CoreModulesPath = script.Parent:WaitForChild("Core")

local Logger = require(CoreModulesPath.Logger)
local ServiceRegistry = require(CoreModulesPath.ServiceRegistry)
local GlobalRegistry = require(CoreModulesPath.GlobalRegistry)
local DataManager = require(CoreModulesPath.DataManager)
-- NetworkManager is now in ReplicatedStorage.Shared
local NetworkManager = require(game.ReplicatedStorage.Shared.NetworkManager)
local ObjectPool = require(CoreModulesPath.ObjectPool)
local StateValidator = require(CoreModulesPath.StateValidator)
local BaseService = require(CoreModulesPath.BaseService)

-- NEW SERVICES
-- SunlightSystem is in the 'Systems' folder, using WaitForChild for robustness
local SystemsModulesPath = script.Parent:WaitForChild("Systems") -- Assuming Systems is also a sibling folder
local SunlightSystem = require(SystemsModulesPath.SunlightSystem)
local CommandSystem = require(CoreModulesPath.CommandSystem)
-- NEW: BuildingSystem
local BuildingSystem = require(SystemsModulesPath.BuildingSystem)


-- Set up the Logger with the default log level from Constants
Logger.SetLogLevel(Constants.DEFAULT_LOG_LEVEL)
Logger.Info("init.server", "Server initialization started.")

-- Register network events (should be done on both client and server)
-- This is crucial for establishing communication channels.
for _, eventName in pairs(Constants.NETWORK_EVENTS) do
    NetworkManager.RegisterRemoteEvent(eventName)
end
-- Also register the new command system events
NetworkManager.RegisterRemoteEvent("CommandExecute")
NetworkManager.RegisterRemoteEvent("CommandFeedback")
-- NEW: Register BuildingSystem network events
NetworkManager.RegisterRemoteFunction(Constants.NETWORK_EVENTS.CLIENT_REQUEST_BUILD)


-- Register all core services with the ServiceRegistry
-- Register the new SunlightSystem and CommandSystem
ServiceRegistry.RegisterService("SunlightSystem", SunlightSystem)
ServiceRegistry.RegisterService("CommandSystem", CommandSystem)
-- NEW: Register BuildingSystem
ServiceRegistry.RegisterService("BuildingSystem", BuildingSystem)

-- Register DataManager and NetworkManager if they were designed as services
-- For now, they are utility modules, so we'll just make them globally accessible if needed.
-- If they were proper services:
-- ServiceRegistry.RegisterService("DataManager", DataManager)
-- ServiceRegistry.RegisterService("NetworkManager", NetworkManager) -- This line is now redundant if NetworkManager is a global module

-- Initialize all registered services
ServiceRegistry.InitAll()

-- Start all registered services
ServiceRegistry.StartAll()

-- Make some core modules globally accessible via GlobalRegistry if needed
-- This is an alternative to direct 'require' calls if you want a central lookup.
GlobalRegistry.Set("Logger", Logger)
GlobalRegistry.Set("Constants", Constants)
GlobalRegistry.Set("DataManager", DataManager.new()) -- Create an instance if it's not a service
GlobalRegistry.Set("NetworkManager", NetworkManager) -- NetworkManager's methods are static for now


Logger.Info("init.server", "All core services initialized and started.")
Logger.Info("init.server", "Server is now running and ready for game logic.")

-- Keep the server running
while true do
    task.wait(60) -- Wait for a minute to prevent script from stopping
end
