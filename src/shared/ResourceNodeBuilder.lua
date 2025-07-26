--[[
    shared/ResourceNodeBuilder.lua
    Description: Utility module for creating simple resource node models.
    This module provides functions to generate basic resource node models
    for testing purposes when actual models are not available.
]]

local ResourceNodeBuilder = {}

--[[
    ResourceNodeBuilder:CreateWoodNode()
    Creates a simple wood resource node model.
    @return Model: A simple wood node model
]]
function ResourceNodeBuilder:CreateWoodNode()
    local woodNode = Instance.new("Model")
    woodNode.Name = "WoodNode"
    
    -- Create the main trunk part
    local trunk = Instance.new("Part")
    trunk.Name = "Main"
    trunk.Size = Vector3.new(2, 6, 2)
    trunk.Position = Vector3.new(0, 3, 0)
    trunk.Color = Color3.fromRGB(139, 69, 19) -- Brown color
    trunk.Material = Enum.Material.Wood
    trunk.Anchored = true
    trunk.CanCollide = true
    trunk.Parent = woodNode
    
    -- Create some branches
    local branch1 = Instance.new("Part")
    branch1.Name = "Branch1"
    branch1.Size = Vector3.new(1, 1, 4)
    branch1.Position = Vector3.new(0, 4, 2)
    branch1.Color = Color3.fromRGB(139, 69, 19)
    branch1.Material = Enum.Material.Wood
    branch1.Anchored = true
    branch1.CanCollide = true
    branch1.Parent = woodNode
    
    local branch2 = Instance.new("Part")
    branch2.Name = "Branch2"
    branch2.Size = Vector3.new(4, 1, 1)
    branch2.Position = Vector3.new(2, 5, 0)
    branch2.Color = Color3.fromRGB(139, 69, 19)
    branch2.Material = Enum.Material.Wood
    branch2.Anchored = true
    branch2.CanCollide = true
    branch2.Parent = woodNode
    
    -- Create some leaves
    local leaves = Instance.new("Part")
    leaves.Name = "Leaves"
    leaves.Shape = Enum.PartType.Ball
    leaves.Size = Vector3.new(3, 3, 3)
    leaves.Position = Vector3.new(0, 6, 0)
    leaves.Color = Color3.fromRGB(34, 139, 34) -- Forest green
    leaves.Material = Enum.Material.Grass
    leaves.Anchored = true
    leaves.CanCollide = true
    leaves.Parent = woodNode
    
    -- Set the trunk as the primary part
    woodNode.PrimaryPart = trunk
    
    return woodNode
end

--[[
    ResourceNodeBuilder:CreateStoneNode()
    Creates a simple stone resource node model.
    @return Model: A simple stone node model
]]
function ResourceNodeBuilder:CreateStoneNode()
    local stoneNode = Instance.new("Model")
    stoneNode.Name = "StoneNode"
    
    -- Create the main stone part
    local stone = Instance.new("Part")
    stone.Name = "Main"
    stone.Size = Vector3.new(3, 2, 3)
    stone.Position = Vector3.new(0, 1, 0)
    stone.Color = Color3.fromRGB(128, 128, 128) -- Gray color
    stone.Material = Enum.Material.Slate
    stone.Anchored = true
    stone.CanCollide = true
    stone.Parent = stoneNode
    
    -- Create some smaller stone pieces
    local stonePiece1 = Instance.new("Part")
    stonePiece1.Name = "Piece1"
    stonePiece1.Size = Vector3.new(1, 1, 1)
    stonePiece1.Position = Vector3.new(1.5, 1.5, 0)
    stonePiece1.Color = Color3.fromRGB(105, 105, 105)
    stonePiece1.Material = Enum.Material.Slate
    stonePiece1.Anchored = true
    stonePiece1.CanCollide = true
    stonePiece1.Parent = stoneNode
    
    local stonePiece2 = Instance.new("Part")
    stonePiece2.Name = "Piece2"
    stonePiece2.Size = Vector3.new(1, 1, 1)
    stonePiece2.Position = Vector3.new(-1.5, 1.5, 0)
    stonePiece2.Color = Color3.fromRGB(105, 105, 105)
    stonePiece2.Material = Enum.Material.Slate
    stonePiece2.Anchored = true
    stonePiece2.CanCollide = true
    stonePiece2.Parent = stoneNode
    
    -- Set the main stone as the primary part
    stoneNode.PrimaryPart = stone
    
    return stoneNode
end

--[[
    ResourceNodeBuilder:CreateMetalNode()
    Creates a simple metal resource node model.
    @return Model: A simple metal node model
]]
function ResourceNodeBuilder:CreateMetalNode()
    local metalNode = Instance.new("Model")
    metalNode.Name = "MetalNode"
    
    -- Create the main metal part
    local metal = Instance.new("Part")
    metal.Name = "Main"
    metal.Size = Vector3.new(2, 2, 2)
    metal.Position = Vector3.new(0, 1, 0)
    metal.Color = Color3.fromRGB(192, 192, 192) -- Silver color
    metal.Material = Enum.Material.Metal
    metal.Anchored = true
    metal.CanCollide = true
    metal.Parent = metalNode
    
    -- Create some metal shards
    local shard1 = Instance.new("Part")
    shard1.Name = "Shard1"
    shard1.Size = Vector3.new(0.5, 1, 0.5)
    shard1.Position = Vector3.new(1, 1.5, 0)
    shard1.Color = Color3.fromRGB(169, 169, 169)
    shard1.Material = Enum.Material.Metal
    shard1.Anchored = true
    shard1.CanCollide = true
    shard1.Parent = metalNode
    
    local shard2 = Instance.new("Part")
    shard2.Name = "Shard2"
    shard2.Size = Vector3.new(0.5, 1, 0.5)
    shard2.Position = Vector3.new(-1, 1.5, 0)
    shard2.Color = Color3.fromRGB(169, 169, 169)
    shard2.Material = Enum.Material.Metal
    shard2.Anchored = true
    shard2.CanCollide = true
    shard2.Parent = metalNode
    
    -- Set the main metal as the primary part
    metalNode.PrimaryPart = metal
    
    return metalNode
end

--[[
    ResourceNodeBuilder:CreateResourceNode(resourceType)
    Creates a resource node model based on the resource type.
    @param resourceType string: The type of resource ("WOOD", "STONE", "METAL")
    @return Model: The resource node model, or nil if type not supported
]]
function ResourceNodeBuilder:CreateResourceNode(resourceType)
    if resourceType == "WOOD" then
        return self:CreateWoodNode()
    elseif resourceType == "STONE" then
        return self:CreateStoneNode()
    elseif resourceType == "METAL" then
        return self:CreateMetalNode()
    else
        warn("Unsupported resource type: " .. tostring(resourceType))
        return nil
    end
end

return ResourceNodeBuilder 