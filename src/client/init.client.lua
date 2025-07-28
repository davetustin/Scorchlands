--[[
    client/init.client.luau
    Description: The main client-side initialization script for Scorchlands.
    This script handles client-specific setup, including UI, input, and
    communication with server-side systems like the CommandSystem.
]]

-- Require necessary modules
local Constants = require(game.ReplicatedStorage.Shared.Constants)
local NetworkManager = require(game.ReplicatedStorage.Shared.NetworkManager)
local Logger = require(game.ReplicatedStorage.Shared.Logger)

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService") -- Modern chat service

local LocalPlayer = Players.LocalPlayer

-- Get the RemoteEvents for command communication
local CommandExecuteEvent = NetworkManager.GetRemoteEvent("CommandExecute")
local CommandFeedbackEvent = NetworkManager.GetRemoteEvent("CommandFeedback")

-- This line expects BuildingClient to be a ModuleScript directly under PlayerScripts.
local ClientModulesPath = script.Parent:WaitForChild("Client")
local BuildingClient = require(ClientModulesPath.BuildingClient)
local ResourceClient = require(ClientModulesPath.ResourceClient)

-- NEW: Require the BuildingUI module
local BuildingUI = require(ClientModulesPath.Interface.BuildingUI)

--[[
    handleCommandInput(message)
    Processes chat messages to check for commands and sends them to the server.
    Returns true if the message was a command and should be consumed by the chat.
    @param message string: The raw chat message.
]]
local function handleCommandInput(message)
    -- REMOVED: Local client-side building commands - now handled by BuildingUI
    
    -- Check for server commands (starting with '/')
    if message:sub(1, 1) == "/" then
        local commandString = message:sub(2) -- Remove the leading '/'
        local commandName, rawArgs = commandString:match("^(%S+)%s*(.*)$")

        if commandName then
            if CommandExecuteEvent then
                Logger.Debug("Client", "Executing server command: %s with args: %s", commandName, rawArgs)
                CommandExecuteEvent:FireServer(commandName, rawArgs)
                return true -- Message was a server command, consume it
            else
                Logger.Warn("Client", "CommandExecuteEvent not available to send command. Server may not have registered it.")
            end
        end
    end

    return false -- Message was not a command
end

--[[
    displayFeedback(message)
    Displays feedback messages received from the server.
    @param message string: The feedback message.
]]
local function displayFeedback(message)
    -- Display the message in the chat window.
    -- For simplicity, we'll just print it to output, but in a real game,
    -- you'd use a custom chat UI or TextChatService.
    Logger.Info("Client", "Server feedback: %s", message)
    -- Note: TextChatService doesn't have SendSystemMessage method
    -- In a real implementation, you'd use a custom UI or TextChatService.TextChannels
    -- For now, we'll just use Logger for debugging
end

-- Connect to TextChatService's OnIncomingMessage event
-- This is the modern and recommended way to handle chat input for commands.
if TextChatService then
    TextChatService.OnIncomingMessage = function(textChatMessage) -- CORRECTED: Assigning function directly to callback
        -- Only process messages originating from the local player (to avoid processing other players' messages)
        if textChatMessage.TextSource and textChatMessage.TextSource.UserId == LocalPlayer.UserId then
            if handleCommandInput(textChatMessage.Text) then
                -- Clear the message text to prevent it from appearing in chat
                local success = pcall(function()
                    textChatMessage.Text = ""
                end)
                if not success then
                    Logger.Warn("Client", "Could not clear command message from chat")
                end
            end
        end
    end
    Logger.Info("Client", "TextChatService message listener connected")
else
    Logger.Warn("Client", "TextChatService not found. Command input will not be processed via modern chat.")
end

-- Listen for command feedback from the server
if CommandFeedbackEvent then
    CommandFeedbackEvent.OnClientEvent:Connect(displayFeedback)
    Logger.Info("Client", "CommandFeedback listener connected")
end

-- Initialize the client-side building system
BuildingClient.Init()

-- Initialize the client-side resource system
ResourceClient:Init()

-- NEW: Initialize the BuildingUI system
BuildingUI:Init()

-- NEW: Connect BuildingUI to BuildingClient
BuildingUI:SetBuildingClient(BuildingClient)

-- NEW: Connect BuildingClient callbacks to BuildingUI
BuildingClient:SetCallbacks(
    function(isBuildingMode, structureType)
        -- Callback when building mode changes
        if isBuildingMode then
            -- Logger.Debug("Client", "Building mode enabled: %s", structureType)
        else
            -- Logger.Debug("Client", "Building mode disabled")
            -- Deselect all buttons when building mode is disabled
            BuildingUI:DeselectAll()
        end
    end,
    function(isRepairMode)
        -- Callback when repair mode changes
        if isRepairMode then
            -- Logger.Debug("Client", "Repair mode enabled")
        else
            -- Logger.Debug("Client", "Repair mode disabled")
            -- Deselect all buttons when repair mode is disabled
            BuildingUI:DeselectAll()
        end
    end
)

Logger.Info("Client", "Client initialization complete")

-- Force flush any remaining buffered logs to ensure startup logs are displayed immediately
Logger.FlushBuffer()

-- You can add other client-side initialization here, e.g., UI setup, local effects.
