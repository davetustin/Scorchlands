--[[
    Core/CommandSystem.lua
    Description: A scalable system for handling in-game admin commands.
    It registers commands, handles client requests, and dispatches them
    to the appropriate functions with basic authorization.
    Inherits from BaseService.
]]
local BaseService = require(script.Parent.BaseService)
local Logger = require(game.ReplicatedStorage.Shared.Logger)
local Constants = require(game.ReplicatedStorage.Shared.Constants)
local StateValidator = require(script.Parent.StateValidator)
-- CORRECTED: NetworkManager is now in ReplicatedStorage.Shared
local NetworkManager = require(game.ReplicatedStorage.Shared.NetworkManager)
local ServiceRegistry = require(script.Parent.ServiceRegistry) -- To access other services for commands
local GlobalRegistry = require(script.Parent.GlobalRegistry) -- For cross-service communication

local CommandSystem = {}
CommandSystem.__index = CommandSystem
setmetatable(CommandSystem, BaseService) -- Inherit from BaseService

-- Private variables for the service
local _registeredCommands = {}
local _commandRemoteEvent = nil -- RemoteEvent for client-to-server command execution
local _commandFeedbackEvent = nil -- RemoteEvent for server-to-client command feedback

-- Define a simple admin check function (for development/testing)
-- For a production game, this would integrate with a proper admin system (e.g., group ranks, specific user IDs)
local function isAdmin(player)
    -- In development mode, all players can be considered admins for testing
    if Constants.DEVELOPMENT_MODE then
        return true
    end
    -- For production, replace with actual admin check:
    -- return player:GetRankInGroup(YOUR_ADMIN_GROUP_ID) >= YOUR_ADMIN_RANK
    -- or table.find(Constants.ADMIN_USER_IDS, player.UserId)
    return false -- Default to false if not in development mode
end

function CommandSystem.new(serviceName)
    local self = BaseService.new(serviceName)
    setmetatable(self, CommandSystem)
    Logger.Debug(self:GetServiceName(), "CommandSystem instance created.")
    return self
end

function CommandSystem:Init()
    BaseService.Init(self) -- Call parent Init
    Logger.Info(self:GetServiceName(), "CommandSystem initialized.")

    -- CORRECTED: Get the necessary RemoteEvents, assuming they are registered by NetworkManager's main setup
    _commandRemoteEvent = NetworkManager.GetRemoteEvent("CommandExecute")
    _commandFeedbackEvent = NetworkManager.GetRemoteEvent("CommandFeedback")

    if not _commandRemoteEvent or not _commandFeedbackEvent then
        Logger.Fatal(self:GetServiceName(), "Failed to get Command RemoteEvents. NetworkManager setup issue?")
    end
end

function CommandSystem:Start()
    BaseService.Start(self) -- Call parent Start
    
    -- Register this service in GlobalRegistry for cross-service communication
    GlobalRegistry.Set("CommandSystem", self)
    
    Logger.Info(self:GetServiceName(), "CommandSystem started. Ready to process commands.")

    -- Connect the server-side listener for command execution
    if _commandRemoteEvent then
        self._commandExecuteConnection = _commandRemoteEvent.OnServerEvent:Connect(function(player, commandString, ...)
            self:ExecuteCommand(player, commandString, ...)
        end)
    end

    -- Register the core commands
    self:RegisterCommand("sunlightdamage", "Toggles player sunlight damage on/off. Usage: /sunlightdamage [on|off]", function(player, status)
        local sunlightSystem = ServiceRegistry.Get("SunlightSystem")
        if not sunlightSystem then
            self:SendFeedback(player, "Error: SunlightSystem not found.")
            Logger.Error(self:GetServiceName(), "SunlightSystem not found when executing sunlightdamage command.")
            return
        end

        local newStatus = nil
        if type(status) == "string" then
            status = status:lower()
            if status == "on" then
                newStatus = true
            elseif status == "off" then
                newStatus = false
            end
        end

        if newStatus ~= nil then
            sunlightSystem:SetSunlightDamageEnabled(newStatus)
            self:SendFeedback(player, "Player sunlight damage is now: " .. (newStatus and "ENABLED" or "DISABLED"))
            Logger.Info(self:GetServiceName(), "%s toggled player sunlight damage to %s.", player.Name, newStatus and "ON" or "OFF")
        else
            local currentStatus = sunlightSystem:IsSunlightDamageEnabled()
            self:SendFeedback(player, "Current player sunlight damage status: " .. (currentStatus and "ENABLED" or "DISABLED") .. ". Usage: /sunlightdamage [on|off]")
        end
    end)

    self:RegisterCommand("buildingsunlight", "Toggles building sunlight damage on/off. Usage: /buildingsunlight [on|off]", function(player, status)
        local buildingSystem = ServiceRegistry.Get("BuildingSystem")
        if not buildingSystem then
            self:SendFeedback(player, "Error: BuildingSystem not found.")
            Logger.Error(self:GetServiceName(), "BuildingSystem not found when executing buildingsunlight command.")
            return
        end

        local newStatus = nil
        if type(status) == "string" then
            status = status:lower()
            if status == "on" then
                newStatus = true
            elseif status == "off" then
                newStatus = false
            end
        end

        if newStatus ~= nil then
            buildingSystem:SetBuildingSunlightDamageEnabled(newStatus)
            self:SendFeedback(player, "Building sunlight damage is now: " .. (newStatus and "ENABLED" or "DISABLED"))
            Logger.Info(self:GetServiceName(), "%s toggled building sunlight damage to %s.", player.Name, newStatus and "ON" or "OFF")
        else
            local currentStatus = buildingSystem:IsBuildingSunlightDamageEnabled()
            self:SendFeedback(player, "Current building sunlight damage status: " .. (currentStatus and "ENABLED" or "DISABLED") .. ". Usage: /buildingsunlight [on|off]")
        end
    end)

    -- Example: A simple "hello" command
    self:RegisterCommand("hello", "Says hello to the player. Usage: /hello", function(player)
        self:SendFeedback(player, "Hello, " .. player.Name .. "!")
        Logger.Info(self:GetServiceName(), "%s used the hello command.", player.Name)
    end)

    -- Resource system commands
    self:RegisterCommand("spawnresource", "Spawns a resource node at your position. Usage: /spawnresource [wood|stone|metal]", function(player, resourceType)
        local resourceSystem = ServiceRegistry.Get("ResourceSystem")
        if not resourceSystem then
            self:SendFeedback(player, "Error: ResourceSystem not found.")
            Logger.Error(self:GetServiceName(), "ResourceSystem not found when executing spawnresource command.")
            return
        end

        local validTypes = {"wood", "stone", "metal"}
        resourceType = resourceType and resourceType:lower() or "wood"
        
        if not table.find(validTypes, resourceType) then
            self:SendFeedback(player, "Invalid resource type. Valid types: " .. table.concat(validTypes, ", "))
            return
        end

        local character = player.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then
            self:SendFeedback(player, "Error: Character not found.")
            return
        end

        local position = character.HumanoidRootPart.Position
        local nodeId = resourceSystem:ForceSpawnResourceNode(resourceType:upper(), position)
        
        if nodeId then
            self:SendFeedback(player, "Spawned " .. resourceType .. " resource node at your position.")
            Logger.Info(self:GetServiceName(), "%s spawned %s resource node.", player.Name, resourceType)
        else
            self:SendFeedback(player, "Failed to spawn resource node.")
        end
    end)

    self:RegisterCommand("listresources", "Lists all available resource types. Usage: /listresources", function(player)
        local resourceTypes = {"wood", "stone", "metal"}
        local resourceList = table.concat(resourceTypes, ", ")
        self:SendFeedback(player, "Available resource types: " .. resourceList)
        Logger.Info(self:GetServiceName(), "%s listed resource types.", player.Name)
    end)

    Logger.Info(self:GetServiceName(), "Core commands registered.")
end

function CommandSystem:Stop()
    BaseService.Stop(self) -- Call parent Stop
    if self._commandExecuteConnection then
        self._commandExecuteConnection:Disconnect()
        self._commandExecuteConnection = nil
    end
    _registeredCommands = {} -- Clear registered commands
    Logger.Info(self:GetServiceName(), "CommandSystem stopped.")
end

--[[
    CommandSystem:RegisterCommand(name, description, func)
    Registers a new command with the system.
    @param name string: The name of the command (e.g., "teleport").
    @param description string: A brief description of the command.
    @param func function: The function to execute when the command is called.
                          It receives (player, ...) as arguments.
]]
function CommandSystem:RegisterCommand(name, description, func)
    if type(name) ~= "string" or type(description) ~= "string" or type(func) ~= "function" then
        Logger.Warn(self:GetServiceName(), "Attempted to register command with invalid arguments: %s, %s, %s",
            tostring(name), tostring(description), tostring(func))
        return
    end
    if _registeredCommands[name:lower()] then
        Logger.Warn(self:GetServiceName(), "Command '%s' is already registered.", name)
        return
    end

    _registeredCommands[name:lower()] = {
        description = description,
        func = func
    }
    Logger.Debug(self:GetServiceName(), "Registered command: /%s", name)
end

--[[
    CommandSystem:ExecuteCommand(player, commandString, ...)
    Parses and executes a command received from a client.
    Includes authorization checks.
    @param player Player: The player who sent the command.
    @param commandString string: The raw command string (e.g., "sunlightdamage on").
    @param ... any: Additional arguments passed with the command.
]]
function CommandSystem:ExecuteCommand(player, commandString, ...)
    -- Security: Validate input
    if not player then
        Logger.Warn(self:GetServiceName(), "Command executed with nil player")
        return
    end
    
    if not StateValidator.ValidateCommandInput(commandString) then
        self:SendFeedback(player, "Invalid command input.")
        Logger.Warn(self:GetServiceName(), "Invalid command input from %s: %s", player.Name, commandString)
        return
    end
    
    -- Security: Rate limiting
    if not StateValidator.CheckRateLimit(player, "command_execution") then
        self:SendFeedback(player, "Rate limit exceeded. Please wait before using commands again.")
        Logger.Warn(self:GetServiceName(), "Command rate limit exceeded for %s", player.Name)
        return
    end

    -- Security: Admin check
    if not isAdmin(player) then
        self:SendFeedback(player, "You do not have permission to use commands.")
        Logger.Warn(self:GetServiceName(), "Unauthorized command attempt by %s: %s", player.Name, commandString)
        return
    end

    local args = {...}
    local commandName = string.lower(commandString)

    local commandData = _registeredCommands[commandName]
    if commandData then
        local success, err = pcall(function()
            commandData.func(player, unpack(args))
        end)
        if not success then
            self:SendFeedback(player, "Error executing command '" .. commandName .. "': " .. tostring(err))
            Logger.Error(self:GetServiceName(), "Error executing command '%s' by %s: %s", commandName, player.Name, err)
        end
    else
        self:SendFeedback(player, "Unknown command: /" .. commandName .. ". Type /help for a list of commands.")
        Logger.Warn(self:GetServiceName(), "%s attempted unknown command: %s", player.Name, commandName)
    end
end

--[[
    CommandSystem:SendFeedback(player, message)
    Sends a feedback message back to a specific client.
    @param player Player: The player to send feedback to.
    @param message string: The message to send.
]]
function CommandSystem:SendFeedback(player, message)
    if _commandFeedbackEvent then
        _commandFeedbackEvent:FireClient(player, message)
    else
        Logger.Warn(self:GetServiceName(), "CommandFeedback RemoteEvent not available to send message to %s: %s", player.Name, message)
    end
end

--[[
    CommandSystem:GetCommands()
    Returns a table of all registered commands (name and description).
    @return table: A table where keys are command names and values are their descriptions.
]]
function CommandSystem:GetCommands()
    local commandsList = {}
    for name, data in pairs(_registeredCommands) do
        commandsList[name] = data.description
    end
    return commandsList
end

return CommandSystem
