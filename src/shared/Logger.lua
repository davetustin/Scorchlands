--[[
    Shared/Logger.lua
    Description: A robust logging utility for both client and server.
    Provides categorized logging (DEBUG, INFO, WARN, ERROR, FATAL) with
    timestamps and source information. Useful for debugging, monitoring,
    and post-mortem analysis.
]]
local Logger = {}

local Constants = require(game.ReplicatedStorage.Shared.Constants)

local LogLevel = Constants.LOG_LEVEL
local CurrentLogLevel = Constants.DEFAULT_LOG_LEVEL

-- Performance optimization: Cache frequently used functions
local format = string.format
local tostring = tostring
local os_date = os.date
local os_time = os.time
local print = print
local warn = warn
local error = error

-- Log buffer for performance (flush periodically)
local _logBuffer = {}
local _bufferSize = 0
local _maxBufferSize = 20 -- reduced from 50 for faster flushing
local _lastFlush = tick()
local _flushInterval = 1 -- seconds (reduced from 5 for better responsiveness)

-- Log statistics
local _logStats = {
    debug = 0,
    info = 0,
    warn = 0,
    error = 0,
    fatal = 0
}

-- Performance: Cache timestamp format
local function getTimestamp()
    return os_date("%Y-%m-%d %H:%M:%S", os_time())
end

-- Performance: Optimized message formatting
local function formatMessage(level, source, message, ...)
    local formattedSource = source and format("[%s]", source) or ""
    local formattedMessage = format(tostring(message), ...)
    return format("[%s] %s %s: %s", getTimestamp(), level, formattedSource, formattedMessage)
end

-- Performance: Buffer management
local function addToBuffer(level, message)
    _logBuffer[_bufferSize + 1] = {level = level, message = message, timestamp = tick()}
    _bufferSize = _bufferSize + 1
    
    -- Immediate flush for critical messages (ERROR, FATAL, and important INFO)
    if level == "ERROR" or level == "FATAL" or 
       (level == "INFO" and (message:find("SERVER STARTUP") or message:find("initialization complete"))) or
       (level == "DEBUG" and message:find("SunlightSystem") and (message:find("Enabled health regeneration") or message:find("Disabled health regeneration"))) or
       (level == "WARN" and message:find("CommandSystem")) or
       (level == "DEBUG" and message:find("Client") and message:find("Executing server command")) or
       (level == "INFO" and message:find("Server feedback")) or
       (level == "DEBUG" and message:find("BuildingClient") and (message:find("Building mode ENABLED") or message:find("Building mode DISABLED") or message:find("Repair mode ENABLED") or message:find("Repair mode DISABLED"))) then
        Logger.FlushBuffer()
        return
    end
    
    -- Flush buffer if it's full or enough time has passed
    if _bufferSize >= _maxBufferSize or (tick() - _lastFlush) > _flushInterval then
        Logger.FlushBuffer()
    end
end

--[[
    Logger.FlushBuffer()
    Flushes the log buffer to output.
]]
function Logger.FlushBuffer()
    if _bufferSize == 0 then
        return
    end
    
    for i = 1, _bufferSize do
        local entry = _logBuffer[i]
        if entry.level == "ERROR" or entry.level == "FATAL" then
            error(entry.message, 0)
        elseif entry.level == "WARN" then
            warn(entry.message)
        else
            print(entry.message)
        end
    end
    
    -- Clear buffer
    _logBuffer = {}
    _bufferSize = 0
    _lastFlush = tick()
end

--[[
    Logger.SetLogLevel(level)
    Sets the current log level.
    @param level number: The log level to set.
]]
function Logger.SetLogLevel(level)
    if type(level) == "number" and level >= LogLevel.DEBUG and level <= LogLevel.FATAL then
        CurrentLogLevel = level
    else
        warn("Logger: Invalid log level provided. Using default.")
    end
end

--[[
    Logger.GetLogLevel()
    Gets the current log level.
    @return number: The current log level.
]]
function Logger.GetLogLevel()
    return CurrentLogLevel
end

--[[
    Logger.Debug(source, message, ...)
    Logs a debug message.
    @param source string: The source of the log message.
    @param message string: The message to log.
    @param ... any: Additional arguments for string formatting.
]]
function Logger.Debug(source, message, ...)
    if CurrentLogLevel <= LogLevel.DEBUG then
        _logStats.debug = _logStats.debug + 1
        local formattedMessage = formatMessage("DEBUG", source, message, ...)
        addToBuffer("DEBUG", formattedMessage)
    end
end

--[[
    Logger.Info(source, message, ...)
    Logs an info message.
    @param source string: The source of the log message.
    @param message string: The message to log.
    @param ... any: Additional arguments for string formatting.
]]
function Logger.Info(source, message, ...)
    if CurrentLogLevel <= LogLevel.INFO then
        _logStats.info = _logStats.info + 1
        local formattedMessage = formatMessage("INFO", source, message, ...)
        addToBuffer("INFO", formattedMessage)
    end
end

--[[
    Logger.Warn(source, message, ...)
    Logs a warning message.
    @param source string: The source of the log message.
    @param message string: The message to log.
    @param ... any: Additional arguments for string formatting.
]]
function Logger.Warn(source, message, ...)
    if CurrentLogLevel <= LogLevel.WARN then
        _logStats.warn = _logStats.warn + 1
        local formattedMessage = formatMessage("WARN", source, message, ...)
        addToBuffer("WARN", formattedMessage)
    end
end

--[[
    Logger.Error(source, message, ...)
    Logs an error message.
    @param source string: The source of the log message.
    @param message string: The message to log.
    @param ... any: Additional arguments for string formatting.
]]
function Logger.Error(source, message, ...)
    if CurrentLogLevel <= LogLevel.ERROR then
        _logStats.error = _logStats.error + 1
        local formattedMessage = formatMessage("ERROR", source, message, ...)
        addToBuffer("ERROR", formattedMessage)
    end
end

--[[
    Logger.Fatal(source, message, ...)
    Logs a fatal message and throws an error.
    @param source string: The source of the log message.
    @param message string: The message to log.
    @param ... any: Additional arguments for string formatting.
]]
function Logger.Fatal(source, message, ...)
    if CurrentLogLevel <= LogLevel.FATAL then
        _logStats.fatal = _logStats.fatal + 1
        local formattedMessage = formatMessage("FATAL", source, message, ...)
        addToBuffer("FATAL", formattedMessage)
    end
end

--[[
    Logger.GetStats()
    Gets logging statistics.
    @return table: Logging statistics.
]]
function Logger.GetStats()
    return {
        debug = _logStats.debug,
        info = _logStats.info,
        warn = _logStats.warn,
        error = _logStats.error,
        fatal = _logStats.fatal,
        bufferSize = _bufferSize,
        totalLogs = _logStats.debug + _logStats.info + _logStats.warn + _logStats.error + _logStats.fatal
    }
end

--[[
    Logger.ResetStats()
    Resets logging statistics.
]]
function Logger.ResetStats()
    _logStats = {
        debug = 0,
        info = 0,
        warn = 0,
        error = 0,
        fatal = 0
    }
end

--[[
    Logger.SetBufferSize(size)
    Sets the maximum buffer size.
    @param size number: The maximum buffer size.
]]
function Logger.SetBufferSize(size)
    if type(size) == "number" and size > 0 then
        _maxBufferSize = size
    end
end

--[[
    Logger.SetFlushInterval(interval)
    Sets the flush interval in seconds.
    @param interval number: The flush interval in seconds.
]]
function Logger.SetFlushInterval(interval)
    if type(interval) == "number" and interval > 0 then
        _flushInterval = interval
    end
end

-- Auto-flush on script end
local RunService = game:GetService("RunService")
if RunService:IsServer() then
    game:BindToClose(function()
        Logger.FlushBuffer()
    end)
end

return Logger 