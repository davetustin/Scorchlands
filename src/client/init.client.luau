--!native
--!optimize

--[[
    client/init.client.luau
    Description: The main client-side initialization script for Scorchlands.
    This script handles client-specific setup, including UI, input, and
    communication with server-side systems like the CommandSystem.
]]

-- Require necessary modules
local Constants = require(game.ReplicatedStorage.Shared.Constants)
-- NetworkManager is now correctly located in ReplicatedStorage.Shared for client access.
local NetworkManager = require(game.ReplicatedStorage.Shared.NetworkManager)

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
                -- Pass commandName and then the rawArgs string.
                -- The server's CommandSystem:ExecuteCommand expects commandString and then varargs.
                -- If rawArgs is empty, it will be passed as nil, which is fine.
                CommandExecuteEvent:FireServer(commandName, rawArgs)
            else
                warn("Client: CommandExecuteEvent not available to send command.")
            end
        end
        return true -- Indicate that the message was handled as a command
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
                -- CORRECTED: Use textChatMessage.Text instead of textChatMessage.Message
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


print("Client: init.client.luau finished initialization.")

-- You can add other client-side initialization here, e.g., UI setup, local effects.
