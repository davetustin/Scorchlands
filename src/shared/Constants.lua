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
    SERVER_NOTIFY_RESOURCE_GATHERED = "ServerNotifyResourceGathered",
    SERVER_NOTIFY_RESOURCE_NODE_UPDATE = "ServerNotifyResourceNodeUpdate",
}

-- RemoteFunction names (separate from RemoteEvents)
Constants.REMOTE_FUNCTIONS = {
    CLIENT_REQUEST_BUILD = "ClientRequestBuild",
    CLIENT_REQUEST_REPAIR = "ClientRequestRepair",
    CLIENT_REQUEST_GATHER_RESOURCE = "ClientRequestGatherResource",
}

-- DataStore keys (example)
Constants.DATA_STORE_KEYS = {
    PLAYER_DATA = "PlayerData_",
    BASE_DATA = "BaseData_",
    STRUCTURE_DATA = "StructureData_",
    GLOBAL_SETTINGS = "GlobalSettings",
}

-- Game-specific values (example)
Constants.SUNLIGHT_DAMAGE_INTERVAL = 1.0 -- seconds
Constants.SUNLIGHT_DAMAGE_AMOUNT = 5 -- health points per interval
Constants.STRUCTURE_DEGRADATION_RATE = 0.01 -- percentage per second
Constants.MAX_HEALTH = 100

-- Structure Health System Constants
Constants.STRUCTURE_HEALTH = {
    -- Material types and their properties
    MATERIALS = {
        WOOD = {
            name = "Wood",
            maxHealth = 100,
            sunlightDamageRate = 1, -- damage per second when exposed to sunlight
            repairCost = 1, -- placeholder for future material system
        },
        -- Future materials can be added here:
        -- STONE = { name = "Stone", maxHealth = 200, sunlightDamageRate = 1, repairCost = 2 },
        -- METAL = { name = "Metal", maxHealth = 300, sunlightDamageRate = 0.5, repairCost = 3 },
    },
    
    -- Health check intervals
    HEALTH_CHECK_INTERVAL = 1.0, -- seconds between health checks
    SUNLIGHT_CHECK_INTERVAL = 1.0, -- seconds between sunlight exposure checks
    
    -- Repair notification thresholds
    REPAIR_WARNING_THRESHOLD = 50, -- Show warning when health drops below this
    CRITICAL_HEALTH_THRESHOLD = 20, -- Show critical warning when health drops below this
    
    -- Default material for new structures
    DEFAULT_MATERIAL = "WOOD",
}

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

-- Resource System Constants
Constants.RESOURCES = {
    WOOD = {
        name = "Wood",
        displayName = "Wood",
        description = "Basic building material from trees",
        color = BrickColor.new("Brown"),
        material = Enum.Material.Wood,
        gatherTime = 2.0, -- seconds to gather
        respawnTime = 30.0, -- seconds to respawn
        maxQuantity = 5, -- max resources per node
        modelName = "FallbackWoodNode", -- fallback model created by ResourceNodeBuilder
    },
    -- Future resources can be added here:
    -- STONE = { name = "Stone", displayName = "Stone", ... },
    -- METAL = { name = "Metal", displayName = "Metal", ... },
}

-- Resource Node Constants
Constants.RESOURCE_NODES = {
    DEFAULT_SPAWN_RADIUS = 100, -- studs from spawn point
    MIN_DISTANCE_BETWEEN_NODES = 20, -- minimum distance between resource nodes
    MAX_NODES_PER_RESOURCE_TYPE = 10, -- maximum nodes of each type in the world
    NODE_HEALTH = 100, -- health of resource nodes
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
