--!native
--!optimize

--[[
    Systems/GameSystem.lua
    Description: Comprehensive game management system for Scorchlands.
    
    Features:
    - Centralized game state management
    - Service coordination and lifecycle management
    - Game session handling and player management
    - Performance monitoring and optimization
    - Error handling and recovery mechanisms
    - Debug and administrative controls
    - Statistics and analytics tracking
    
    Usage:
        local gameSystem = GameSystem.new("GameSystem")
        gameSystem:InitializeGame()
        gameSystem:StartGameSession()
        local stats = gameSystem:GetGameStats()
]]

-- Dependencies (must be loaded first)
local BaseService = require(script.Parent.Parent.Core.BaseService)

local GameSystem = {}
GameSystem.__index = GameSystem
setmetatable(GameSystem, { __index = BaseService })

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Dependencies
local Logger = require(script.Parent.Parent.Core.Logger)
local Constants = require(game.ReplicatedStorage.Shared.Constants)
local ServiceRegistry = require(script.Parent.Parent.Core.ServiceRegistry)

-- Performance optimization: Cache frequently used functions
local format = string.format
local tostring = tostring
local type = type
local pairs = pairs
local ipairs = ipairs
local table_insert = table.insert
local table_remove = table.remove
local error = error
local warn = warn
local setmetatable = setmetatable
local typeof = typeof

-- Game system configuration
local GAME_CONFIG = {
    MAX_PLAYERS = 50,
    SESSION_TIMEOUT = 300, -- 5 minutes
    STATS_UPDATE_INTERVAL = 60, -- 1 minute
    DEBUG_MODE = false,
    AUTO_SAVE_INTERVAL = 300 -- 5 minutes
}

-- Game state
local _gameState = {
    initialized = false,
    sessionActive = false,
    sessionStartTime = 0,
    players = {},
    services = {},
    stats = {
        totalPlayers = 0,
        currentPlayers = 0,
        sessionsStarted = 0,
        errors = 0,
        startTime = tick()
    }
}

--[[
    validateService(service, serviceName)
    Validates that a service is properly structured.
    @param service table: Service to validate
    @param serviceName string: Name of the service
    @return boolean: Whether service is valid
]]
local function validateService(service, serviceName)
    if not service then
        Logger.Error("GameSystem", "Service %s is nil", serviceName)
        return false
    end
    
    if type(service) ~= "table" then
        Logger.Error("GameSystem", "Service %s is not a table", serviceName)
        return false
    end
    
    return true
end

--[[
    logGame(message, level)
    Logs game system messages with consistent formatting.
    @param message string: Message to log
    @param level string: Log level (debug, info, warn, error)
]]
local function logGame(message, level)
    level = level or "info"
    local timestamp = format("[%.2f]", tick() - _gameState.stats.startTime)
    local formattedMessage = format("Game %s: %s", timestamp, message)
    
    if level == "error" then
        Logger.Error("GameSystem", message)
        _gameState.stats.errors = _gameState.stats.errors + 1
    elseif level == "warn" then
        Logger.Warn("GameSystem", message)
    elseif level == "debug" then
        Logger.Debug("GameSystem", message)
    else
        Logger.Info("GameSystem", message)
    end
end

--[[
    GameSystem.new(serviceName)
    Creates a new GameSystem instance with validation.
    @param serviceName string: Name of the service
    @return GameSystem: New GameSystem instance
]]
function GameSystem.new(serviceName)
    local self = setmetatable(BaseService.new(serviceName), GameSystem)
    
    Logger.Debug("GameSystem", "GameSystem instance created")
    return self
end

--[[
    GameSystem:OnInit()
    Initializes the game system.
]]
function GameSystem:OnInit()
    logGame("GameSystem initialized", "info")
    return true
end

--[[
    GameSystem:OnStart()
    Starts the game system and begins session management.
]]
function GameSystem:OnStart()
    logGame("GameSystem started", "info")
    
    -- Initialize game session
    self:InitializeGameSession()
    
    -- Setup player management
    self:SetupPlayerManagement()
    
    -- Setup monitoring
    self:SetupMonitoring()
    
    return true
end

--[[
    GameSystem:OnStop()
    Stops the game system and cleans up.
]]
function GameSystem:OnStop()
    self:EndGameSession()
    _gameState.initialized = false
    
    logGame("GameSystem stopped", "info")
    return true
end

--[[
    GameSystem:InitializeGameSession()
    Initializes a new game session.
]]
function GameSystem:InitializeGameSession()
    _gameState.sessionActive = true
    _gameState.sessionStartTime = tick()
    _gameState.stats.sessionsStarted = _gameState.stats.sessionsStarted + 1
    
    logGame("Game session initialized", "info")
end

--[[
    GameSystem:EndGameSession()
    Ends the current game session.
]]
function GameSystem:EndGameSession()
    if not _gameState.sessionActive then
        return
    end
    
    local sessionDuration = tick() - _gameState.sessionStartTime
    _gameState.sessionActive = false
    
    logGame(format("Game session ended (Duration: %.1fs)", sessionDuration), "info")
end

--[[
    GameSystem:SetupPlayerManagement()
    Sets up player join/leave handling.
]]
function GameSystem:SetupPlayerManagement()
    -- Handle player joining
    self:Connect(Players.PlayerAdded:Connect(function(player)
        self:HandlePlayerJoined(player)
    end))
    
    -- Handle player leaving
    self:Connect(Players.PlayerRemoving:Connect(function(player)
        self:HandlePlayerLeft(player)
    end))
    
    -- Handle existing players
    for _, player in ipairs(Players:GetPlayers()) do
        self:HandlePlayerJoined(player)
    end
    
    logGame("Player management setup completed", "debug")
end

--[[
    GameSystem:HandlePlayerJoined(player)
    Handles a player joining the game.
    @param player Player: Player who joined
]]
function GameSystem:HandlePlayerJoined(player)
    if not player then
        return
    end
    
    -- Validate player
    if typeof(player) ~= "Instance" or not player:IsA("Player") then
        logGame(format("Invalid player joined: %s", tostring(player)), "warn")
        return
    end
    
    -- Check player limit
    if _gameState.stats.currentPlayers >= GAME_CONFIG.MAX_PLAYERS then
        logGame(format("Player limit reached (%d/%d)", _gameState.stats.currentPlayers, GAME_CONFIG.MAX_PLAYERS), "warn")
        return
    end
    
    -- Add player to tracking
    _gameState.players[player.UserId] = {
        name = player.Name,
        joinTime = tick(),
        lastActivity = tick()
    }
    
    _gameState.stats.currentPlayers = _gameState.stats.currentPlayers + 1
    _gameState.stats.totalPlayers = _gameState.stats.totalPlayers + 1
    
    logGame(format("Player joined: %s (ID: %d)", player.Name, player.UserId), "info")
end

--[[
    GameSystem:HandlePlayerLeft(player)
    Handles a player leaving the game.
    @param player Player: Player who left
]]
function GameSystem:HandlePlayerLeft(player)
    if not player then
        return
    end
    
    local playerData = _gameState.players[player.UserId]
    if playerData then
        local sessionTime = tick() - playerData.joinTime
        logGame(format("Player left: %s (Session: %.1fs)", player.Name, sessionTime), "info")
        
        _gameState.players[player.UserId] = nil
        _gameState.stats.currentPlayers = _gameState.stats.currentPlayers - 1
    end
end

--[[
    GameSystem:SetupMonitoring()
    Sets up system monitoring and statistics tracking.
]]
function GameSystem:SetupMonitoring()
    -- Monitor game state
    self:Connect(RunService.Heartbeat:Connect(function()
        self:UpdateGameStats()
    end))
    
    logGame("Monitoring setup completed", "debug")
end

--[[
    GameSystem:UpdateGameStats()
    Updates game statistics and monitoring data.
]]
function GameSystem:UpdateGameStats()
    local currentTime = tick()
    
    -- Update player activity
    for userId, playerData in pairs(_gameState.players) do
        playerData.lastActivity = currentTime
    end
    
    -- Log periodic stats
    if currentTime % GAME_CONFIG.STATS_UPDATE_INTERVAL < 1/60 then
        logGame(format("Game stats - Players: %d/%d, Session: %.1fs", 
            _gameState.stats.currentPlayers, GAME_CONFIG.MAX_PLAYERS,
            _gameState.sessionActive and (currentTime - _gameState.sessionStartTime) or 0), "debug")
    end
end

--[[
    GameSystem:GetGameStats()
    Returns comprehensive game statistics.
    @return table: Game statistics
]]
function GameSystem:GetGameStats()
    local currentTime = tick()
    local sessionDuration = _gameState.sessionActive and (currentTime - _gameState.sessionStartTime) or 0
    
    return {
        sessionActive = _gameState.sessionActive,
        sessionDuration = sessionDuration,
        totalPlayers = _gameState.stats.totalPlayers,
        currentPlayers = _gameState.stats.currentPlayers,
        sessionsStarted = _gameState.stats.sessionsStarted,
        errors = _gameState.stats.errors,
        uptime = currentTime - _gameState.stats.startTime,
        maxPlayers = GAME_CONFIG.MAX_PLAYERS
    }
end

--[[
    GameSystem:GetPlayerStats()
    Returns player statistics and information.
    @return table: Player statistics
]]
function GameSystem:GetPlayerStats()
    local playerStats = {}
    
    for userId, playerData in pairs(_gameState.players) do
        local sessionTime = tick() - playerData.joinTime
        table_insert(playerStats, {
            userId = userId,
            name = playerData.name,
            joinTime = playerData.joinTime,
            sessionTime = sessionTime,
            lastActivity = playerData.lastActivity
        })
    end
    
    return playerStats
end

--[[
    GameSystem:IsSessionActive()
    Returns whether a game session is currently active.
    @return boolean: Whether session is active
]]
function GameSystem:IsSessionActive()
    return _gameState.sessionActive
end

--[[
    GameSystem:GetSessionDuration()
    Returns the current session duration.
    @return number: Session duration in seconds
]]
function GameSystem:GetSessionDuration()
    if not _gameState.sessionActive then
        return 0
    end
    
    return tick() - _gameState.sessionStartTime
end

--[[
    GameSystem:SetDebugMode(enabled)
    Sets debug mode for detailed logging.
    @param enabled boolean: Whether to enable debug mode
]]
function GameSystem:SetDebugMode(enabled)
    if type(enabled) ~= "boolean" then
        logGame(format("Invalid debug mode value: %s", tostring(enabled)), "warn")
        return
    end
    
    GAME_CONFIG.DEBUG_MODE = enabled
    logGame(format("Debug mode %s", enabled and "ENABLED" or "DISABLED"), "info")
end

--[[
    GameSystem:ResetStats()
    Resets game statistics.
]]
function GameSystem:ResetStats()
    _gameState.stats = {
        totalPlayers = 0,
        currentPlayers = 0,
        sessionsStarted = 0,
        errors = 0,
        startTime = tick()
    }
    
    logGame("Game statistics reset", "info")
end

--[[
    GameSystem:GetServiceStatus()
    Returns the status of all registered services.
    @return table: Service status information
]]
function GameSystem:GetServiceStatus()
    local serviceStatus = {}
    
    for serviceName, service in pairs(ServiceRegistry.GetAllServices()) do
        if validateService(service, serviceName) then
            table_insert(serviceStatus, {
                name = serviceName,
                initialized = service.IsInitialized and service:IsInitialized() or false,
                running = service.IsRunning and service:IsRunning() or false
            })
        end
    end
    
    return serviceStatus
end

return GameSystem
