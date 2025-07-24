--[[
    client/init.client.luau
    Description: The main client-side initialization script for Scorchlands.
    This script handles client-specific setup, including UI, input, and
    communication with server-side systems like the CommandSystem.
]]

-- Require necessary modules
local Constants = require(game.ReplicatedStorage.Shared.Constants)
local NetworkManager = require(game.ReplicatedStorage.Shared.NetworkManager)

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService") -- Modern chat service

local LocalPlayer = Players.LocalPlayer

-- Get the RemoteEvents for command communication
local CommandExecuteEvent = NetworkManager.GetRemoteEvent("CommandExecute")
local CommandFeedbackEvent = NetworkManager.GetRemoteEvent("CommandFeedback")

-- These warnings are now handled within NetworkManager's GetRemoteEvent/Function methods
-- if not CommandExecuteEvent or not CommandFeedbackEvent then
--     warn("Client: Failed to get Command RemoteEvents. Server may not have registered them or paths are wrong.")
-- end

-- This line expects BuildingClient to be a ModuleScript directly under PlayerScripts.
local ClientModulesPath = script.Parent:WaitForChild("Client")
local BuildingClient = require(ClientModulesPath.BuildingClient)

--[[
    handleCommandInput(message)
    Processes chat messages to check for commands and sends them to the server.
    Returns true if the message was a command and should be consumed by the chat.
    @param message string: The raw chat message.
]]
local function handleCommandInput(message)
    print("Client Debug: handleCommandInput called with message: '" .. message .. "'")
    -- Check for server commands (starting with '/')
    if message:sub(1, 1) == "/" then
        print("Client Debug: Message starts with '/'")
        local commandString = message:sub(2) -- Remove the leading '/'
        local commandName, rawArgs = commandString:match("^(%S+)%s*(.*)$")

        if commandName then
            print("Client Debug: Detected commandName: '" .. commandName .. "' rawArgs: '" .. rawArgs .. "'")
            if CommandExecuteEvent then
                print("Client Debug: Firing CommandExecuteEvent to server for command: '" .. commandName .. "'")
                CommandExecuteEvent:FireServer(commandName, rawArgs)
                return true -- Message was a server command, consume it
            else
                warn("Client: CommandExecuteEvent not available to send command. Server may not have registered it.")
            end
        end
    end

    -- Check for local client-side building commands (for testing)
    local lowerMessage = message:lower()
    if lowerMessage == "/build wall" then
        print("Client Debug: /build wall command detected.")
        BuildingClient:EnableBuildingMode(Constants.STRUCTURE_TYPES.WALL)
        return true
    elseif lowerMessage == "/build floor" then
        print("Client Debug: /build floor command detected.")
        BuildingClient:EnableBuildingMode(Constants.STRUCTURE_TYPES.FLOOR)
        return true
    elseif lowerMessage == "/build roof" then
        print("Client Debug: /build roof command detected.")
        BuildingClient:EnableBuildingMode(Constants.STRUCTURE_TYPES.ROOF)
        return true
    elseif lowerMessage == "/build off" then
        print("Client Debug: /build off command detected.")
        BuildingClient:DisableBuildingMode()
        return true
    end

    print("Client Debug: Message was not a recognized command.")
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
    if TextChatService then
        TextChatService:SendSystemMessage(message)
    end
end

-- Connect to TextChatService's OnIncomingMessage event
-- This is the modern and recommended way to handle chat input for commands.
if TextChatService then
    TextChatService.OnIncomingMessage = function(textChatMessage)
        print("Client Debug: TextChatService.OnIncomingMessage fired.")
        -- Only process messages originating from the local player (to avoid processing other players' messages)
        -- and if the message has a TextSource (meaning it's from a user, not a system message, etc.)
        if textChatMessage.TextSource and textChatMessage.TextSource.UserId == LocalPlayer.UserId then
            print("Client Debug: Message from local player.")
            if handleCommandInput(textChatMessage.Text) then
                print("Client Debug: Command handled, clearing chat message.")
                -- If it's a command, modify the message to hide it from public chat.
                -- Setting FilteredText to an empty string makes it not appear publicly.
                textChatMessage.FilteredText = ""
            end
        else
            print("Client Debug: Message not from local player or no TextSource.")
        end
    end
    print("Client: TextChatService message listener connected.")
else
    warn("Client: TextChatService not found. Command input will not be processed via modern chat.")
    -- If TextChatService is not available (e.g., in very old games or specific setups),
    -- you would need a fallback to the deprecated Chat service's Chatted event,
    -- which is not recommended for new development.
end

-- Listen for command feedback from the server
if CommandFeedbackEvent then
    CommandFeedbackEvent.OnClientEvent:Connect(displayFeedback)
    print("Client: CommandFeedback listener connected.")
end

-- Initialize the client-side building system
BuildingClient.Init()

print("Client: init.client.luau finished initialization.")

-- You can add other client-side initialization here, e.g., UI setup, local effects.
