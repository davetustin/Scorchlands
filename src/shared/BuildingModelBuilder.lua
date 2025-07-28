--[[
    shared/BuildingModelBuilder.lua
    Description: Generates simple building part models for the building system.
    Creates basic models for walls, floors, and roofs that can be used as templates.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(script.Parent.Constants)

local BuildingModelBuilder = {}

--[[
    BuildingModelBuilder:CreateWallModel()
    Creates a simple wall model.
    @return Model: The created wall model
]]
function BuildingModelBuilder:CreateWallModel()
    local model = Instance.new("Model")
    model.Name = "Wall"
    
    local part = Instance.new("Part")
    part.Name = "Main"
    part.Size = Constants.BUILDING_PART_DEFAULTS.Wall.Size
    part.Color = Constants.BUILDING_PART_DEFAULTS.Wall.Color.Color
    part.Material = Constants.BUILDING_PART_DEFAULTS.Wall.Material
    part.Anchored = true
    part.CanCollide = true
    part.Parent = model
    
    model.PrimaryPart = part
    
    return model
end

--[[
    BuildingModelBuilder:CreateFloorModel()
    Creates a simple floor model.
    @return Model: The created floor model
]]
function BuildingModelBuilder:CreateFloorModel()
    local model = Instance.new("Model")
    model.Name = "Floor"
    
    local part = Instance.new("Part")
    part.Name = "Main"
    part.Size = Constants.BUILDING_PART_DEFAULTS.Floor.Size
    part.Color = Constants.BUILDING_PART_DEFAULTS.Floor.Color.Color
    part.Material = Constants.BUILDING_PART_DEFAULTS.Floor.Material
    part.Anchored = true
    part.CanCollide = true
    part.Parent = model
    
    model.PrimaryPart = part
    
    return model
end

--[[
    BuildingModelBuilder:CreateRoofModel()
    Creates a simple roof model.
    @return Model: The created roof model
]]
function BuildingModelBuilder:CreateRoofModel()
    local model = Instance.new("Model")
    model.Name = "Roof"
    
    local part = Instance.new("Part")
    part.Name = "Main"
    part.Size = Constants.BUILDING_PART_DEFAULTS.Roof.Size
    part.Color = Constants.BUILDING_PART_DEFAULTS.Roof.Color.Color
    part.Material = Constants.BUILDING_PART_DEFAULTS.Roof.Material
    part.Anchored = true
    part.CanCollide = true
    part.Parent = model
    
    model.PrimaryPart = part
    
    return model
end

--[[
    BuildingModelBuilder:CreateBuildingModel(structureType)
    Creates a building model based on the structure type.
    @param structureType string: The type of structure to create
    @return Model|nil: The created model or nil if type is invalid
]]
function BuildingModelBuilder:CreateBuildingModel(structureType)
    if structureType == Constants.STRUCTURE_TYPES.WALL then
        return self:CreateWallModel()
    elseif structureType == Constants.STRUCTURE_TYPES.FLOOR then
        return self:CreateFloorModel()
    elseif structureType == Constants.STRUCTURE_TYPES.ROOF then
        return self:CreateRoofModel()
    else
        return nil
    end
end

--[[
    BuildingModelBuilder:CreateAllModels()
    Creates all building models and places them in ReplicatedStorage.
    This should be called during game initialization.
]]
function BuildingModelBuilder:CreateAllModels()
    local modelsFolder = ReplicatedStorage:FindFirstChild("BuildingModels")
    if not modelsFolder then
        modelsFolder = Instance.new("Folder")
        modelsFolder.Name = "BuildingModels"
        modelsFolder.Parent = ReplicatedStorage
    end
    
    -- Create wall model
    local wallModel = self:CreateWallModel()
    wallModel.Parent = modelsFolder
    
    -- Create floor model
    local floorModel = self:CreateFloorModel()
    floorModel.Parent = modelsFolder
    
    -- Create roof model
    local roofModel = self:CreateRoofModel()
    roofModel.Parent = modelsFolder
    
    return modelsFolder
end

return BuildingModelBuilder 