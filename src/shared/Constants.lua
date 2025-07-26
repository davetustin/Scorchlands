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
    SERVER_NOTIFY_HEALTH_UPDATE = "ServerNotifyHealthUpdate",
    CLIENT_REQUEST_INTERACT = "ClientRequestInteract",
}

-- RemoteFunction names (separate from RemoteEvents)
Constants.REMOTE_FUNCTIONS = {
    CLIENT_REQUEST_BUILD = "ClientRequestBuild",
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

-- Sunlight damage toggles
Constants.PLAYER_SUNLIGHT_DAMAGE_ENABLED_DEFAULT = false -- Set to false as requested
Constants.BUILDING_SUNLIGHT_DAMAGE_ENABLED_DEFAULT = true -- Default to true for buildings

-- Player Health Regeneration toggles (separate controls for sunlight and shadow)
Constants.PLAYER_HEALTH_REGEN = {
    ENABLED_IN_SUNLIGHT = false, -- Health regeneration when player is in sunlight
    ENABLED_IN_SHADOW = true,    -- Health regeneration when player is in shadow
}

-- Building System Constants
Constants.STRUCTURE_TYPES = {
    WALL = "Wall",
    FLOOR = "Floor",
    ROOF = "Roof",
}
Constants.MAX_STRUCTURE_HEALTH = 100 -- Default health for newly placed structures
Constants.MAX_STRUCTURE_COUNT_PER_PLAYER = 100 -- Maximum structures per player

-- Building Grid System Constants
Constants.BUILDING_GRID = {
    GRID_SIZE = 4, -- Grid size for all structures
}

-- Default dimensions for basic building parts (in studs)
Constants.BUILDING_PART_DEFAULTS = {
    Wall = {
        Size = Vector3.new(8, 8, 0.5), -- Common wall size
        Color = BrickColor.new("Dark stone grey"),
        Material = Enum.Material.Concrete,
    },
    Floor = {
        Size = Vector3.new(8, 0.5, 8), -- Common floor tile size
        Color = BrickColor.new("Medium stone grey"),
        Material = Enum.Material.Concrete,
    },
    Roof = {
        Size = Vector3.new(8, 0.5, 8), -- Simple flat roof for now
        Color = BrickColor.new("Dark grey"),
        Material = Enum.Material.Slate,
    },
}

return Constants
