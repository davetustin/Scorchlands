--!native
--!optimize

--[[
    client/init.client.luau
    Description: Main client-side initialization script for Scorchlands.
    This script sets up the client-side systems, including command processing,
    building system, and communication with the server.
]]

-- Require shared modules
local Constants = require(game.ReplicatedStorage.Shared.Constants)
local NetworkManager = require(game.ReplicatedStorage.Shared.NetworkManager)

-- Get Roblox services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService") -- Modern chat service

local LocalPlayer = Players.LocalPlayer

-- Get the RemoteEvents for command communication
local CommandExecuteEvent = NetworkManager.GetRemoteEvent("CommandExecute")
local CommandFeedbackEvent = NetworkManager.GetRemoteEvent("CommandFeedback")

if not CommandExecuteEvent or not CommandFeedbackEvent then
    warn("Client: Failed to get Command RemoteEvents. Server may not have registered them or paths are wrong.")
    -- This is a client-side warning, not a fatal error, as the game might still function without commands.
end

-- TEMPORARILY COMMENTED OUT: BuildingClient require
-- local BuildingClient = require(script:WaitForChild("BuildingClient"))

--[[
    handleChatInput(message)
    Processes chat messages to check for commands.
    @param message string: The raw chat message.
]]
local function handleChatInput(message)
    if message:sub(1, 1) == "/" then -- Check if it's a command
        local commandString = message:sub(2) -- Remove the leading '/'
        local commandName, rawArgs = commandString:match("^(%S+)%s*(.*)$")

        if commandName then
            -- Fire the command to the server
            if CommandExecuteEvent then
                CommandExecuteEvent:FireServer(commandName, rawArgs)
            else
                warn("Client: CommandExecuteEvent not available to send command.")
            end
        end
        return true -- Indicate that the message was handled as a command
    end
    -- TEMPORARILY COMMENTED OUT: Building commands
    -- if message:lower() == "/build wall" then
    --     BuildingClient:EnableBuildingMode(Constants.STRUCTURE_TYPES.WALL)
    --     return true
    -- elseif message:lower() == "/build floor" then
    --     BuildingClient:EnableBuildingMode(Constants.STRUCTURE_TYPES.FLOOR)
    --     return true
    -- elseif message:lower() == "/build roof" then
    --     BuildingClient:EnableBuildingMode(Constants.STRUCTURE_TYPES.ROOF)
    --     return true
    -- elseif message:lower() == "/build off" then
    --     BuildingClient:DisableBuildingMode()
    --     return true
    -- end
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
    print("[SERVER FEEDBACK]: " .. message)
    -- If using TextChatService:
    -- TextChatService:SendSystemMessage(message)
end

-- Connect to TextChatService's MessageReceived event
-- This is the modern way to handle chat input.
if TextChatService then
    TextChatService.MessageReceived:Connect(function(textChatMessage)
        if textChatMessage.TextSource then -- Ensure it's from a player
            if textChatMessage.TextSource.UserId == LocalPlayer.UserId then -- Only process messages from this client
                if handleChatInput(textChatMessage.Text) then
                    textChatMessage.Text = "" -- Clear the message from chat if it was a command
                end
            end
        end
    end)
    print("Client: TextChatService message listener connected.")
else
    -- Fallback for older chat or if TextChatService is not preferred
    -- You would need to hook into the default chat system's events, which are more complex.
    warn("Client: TextChatService not found. Command input will not be processed via chat.")
end

-- Listen for command feedback from the server
if CommandFeedbackEvent then
    CommandFeedbackEvent.OnClientEvent:Connect(displayFeedback)
    print("Client: CommandFeedback listener connected.")
end

-- TEMPORARILY COMMENTED OUT: BuildingClient initialization
-- BuildingClient.Init()

print("Client: init.client.luau finished initialization.")

-- You can add other client-side initialization here, e.g., UI setup, local effects.
