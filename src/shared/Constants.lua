--!native
--!optimize

--[[
    shared/Constants.lua
    Description: Centralized constants for the game.
    This module provides a single source of truth for all magic strings,
    numerical values, and configuration settings used throughout the game.
    Benefits: Easy modification, reduced typos, improved readability.
]]
local Constants = {}

-- Game-wide constants
Constants.GAME_TITLE = "Scorchlands"
Constants.VERSION = "0.0.1-alpha"
Constants.DEVELOPMENT_MODE = true -- Set to false for production builds

-- Logging levels
Constants.LOG_LEVEL = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
    FATAL = 5,
}

-- Default log level for the Logger
Constants.DEFAULT_LOG_LEVEL = Constants.LOG_LEVEL.DEBUG

-- Network event names (example)
Constants.NETWORK_EVENTS = {
    CLIENT_REQUEST_BUILD = "ClientRequestBuild",
    SERVER_NOTIFY_HEALTH_UPDATE = "ServerNotifyHealthUpdate",
    CLIENT_REQUEST_INTERACT = "ClientRequestInteract",
}

-- DataStore keys (example)
Constants.DATA_STORE_KEYS = {
    PLAYER_DATA = "PlayerData_",
    BASE_DATA = "BaseData_",
    GLOBAL_SETTINGS = "GlobalSettings",
}

-- Game-specific values (example)
Constants.SUNLIGHT_DAMAGE_INTERVAL = 1.0 -- seconds
Constants.SUNLIGHT_DAMAGE_AMOUNT = 5 -- health points per interval
Constants.STRUCTURE_DEGRADATION_RATE = 0.01 -- percentage per second
Constants.MAX_HEALTH = 100

-- NEW: Sunlight damage toggles
Constants.PLAYER_SUNLIGHT_DAMAGE_ENABLED_DEFAULT = false -- Set to false as requested
Constants.BUILDING_SUNLIGHT_DAMAGE_ENABLED_DEFAULT = true -- Default to true for buildings

-- NEW: Player Health Regeneration toggle
Constants.PLAYER_HEALTH_REGEN_ENABLED_DEFAULT = false -- Set to false by default as requested

return Constants
