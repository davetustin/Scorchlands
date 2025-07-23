-- src/server/systems/GameSystem.lua

local BaseService = require(script.Parent.Parent.core.BaseService)
local SunlightSystem = require(script.Parent.SunlightSystem)

local GameSystem = setmetatable({}, BaseService)
GameSystem.__index = GameSystem

function GameSystem.new()
    local self = BaseService.new("GameSystem")
    setmetatable(self, GameSystem)
    return self
end

function GameSystem:Init(services)
    BaseService.Init(self, services)
    self.Logger.Info("GameSystem initialized.", self.Name)
    self.SunlightSystem = services["SunlightSystem"]
end

function GameSystem:Start()
    BaseService.Start(self)
    self.Logger.Info("GameSystem started.", self.Name)
    -- Add any additional startup logic here
end

function GameSystem:Shutdown()
    BaseService.Shutdown(self)
    self.Logger.Info("GameSystem shut down.", self.Name)
end

return GameSystem
