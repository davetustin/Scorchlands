--!native
--!optimize

--[[
    Core/Logger.lua
    Description: A robust logging utility.
    Provides categorized logging (DEBUG, INFO, WARN, ERROR, FATAL) with
    timestamps and source information. Useful for debugging, monitoring,
    and post-mortem analysis.
]]
local Logger = {}
-- CORRECTED: Constants is in ReplicatedStorage.Shared, not script.Parent
local Constants = require(game.ReplicatedStorage.Shared.Constants)

local LogLevel = Constants.LOG_LEVEL
local CurrentLogLevel = Constants.DEFAULT_LOG_LEVEL

local function getTimestamp()
    return os.date("%Y-%m-%d %H:%M:%S", os.time())
end

local function formatMessage(level, source, message, ...)
    local formattedSource = source and string.format("[%s]", source) or ""
    local formattedMessage = string.format(tostring(message), ...)
    return string.format("[%s] %s %s: %s", getTimestamp(), level, formattedSource, formattedMessage)
end

function Logger.SetLogLevel(level)
    if type(level) == "number" and level >= LogLevel.DEBUG and level <= LogLevel.FATAL then
        CurrentLogLevel = level
    else
        warn("Logger: Invalid log level provided. Using default.")
    end
end

function Logger.Debug(source, message, ...)
    if CurrentLogLevel <= LogLevel.DEBUG then
        print(formatMessage("DEBUG", source, message, ...))
    end
end

function Logger.Info(source, message, ...)
    if CurrentLogLevel <= LogLevel.INFO then
        print(formatMessage("INFO", source, message, ...))
    end
end

function Logger.Warn(source, message, ...)
    if CurrentLogLevel <= LogLevel.WARN then
        warn(formatMessage("WARN", source, message, ...))
    end
end

function Logger.Error(source, message, ...)
    if CurrentLogLevel <= LogLevel.ERROR then
        -- For errors, we might want to also send to an analytics service or Discord webhook
        error(formatMessage("ERROR", source, message, ...), 0) -- Level 0 to avoid printing stack trace from this function
    end
end

function Logger.Fatal(source, message, ...)
    if CurrentLogLevel <= LogLevel.FATAL then
        local msg = formatMessage("FATAL", source, message, ...)
        error(msg, 2) -- Level 2 to show where the fatal error was called
    end
end

return Logger
