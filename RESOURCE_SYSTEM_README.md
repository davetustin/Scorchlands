# Resource System Implementation

## Overview

The Resource System for Scorchlands provides a complete resource gathering mechanic that allows players to collect materials from nodes scattered throughout the world. This system is designed to be extensible and follows the same architectural patterns as other systems in the game.

## Features

### Core Functionality
- **Resource Nodes**: Spawnable resource nodes that players can interact with
- **Gathering Mechanics**: Hold-to-gather system with configurable timing
- **Respawn System**: Automatic respawning of depleted resource nodes
- **Visual Feedback**: Nodes change appearance when depleted and restored
- **Proximity Prompts**: Easy-to-use interaction system

### Resource Types
Currently implemented resources:
- **Wood**: Basic building material (default starting resource)
- **Stone**: Durable building material (placeholder for future implementation)
- **Metal**: Premium building material (placeholder for future implementation)

## Architecture

### Server-Side Components

#### ResourceSystem (`src/server/Systems/ResourceSystem.lua`)
The main service that manages all resource-related functionality:
- Spawns and manages resource nodes
- Handles player interactions
- Manages respawn timers
- Provides API for other systems

#### Key Methods:
- `Init()`: Initializes the system and loads resource models
- `Start()`: Begins spawning nodes and respawn checks
- `ForceSpawnResourceNode(resourceType, position)`: Spawns a node at a specific location
- `GetResourceNodeById(nodeId)`: Retrieves node data
- `GetAllResourceNodes()`: Returns all active nodes

### Client-Side Components

#### ResourceClient (`src/client/ResourceClient.lua`)
Handles client-side resource interactions:
- Receives server notifications about gathered resources
- Displays UI feedback to players
- Manages resource-related sound effects

### Shared Components

#### Constants (`src/shared/Constants.lua`)
Configuration for the resource system:
```lua
Constants.RESOURCES = {
    WOOD = {
        name = "Wood",
        displayName = "Wood",
        description = "Basic building material from trees",
        gatherTime = 2.0, -- seconds to gather
        respawnTime = 30.0, -- seconds to respawn
        maxQuantity = 5, -- max resources per node
        modelName = "WoodNode",
    },
    -- Additional resources...
}

Constants.RESOURCE_NODES = {
    DEFAULT_SPAWN_RADIUS = 100,
    MIN_DISTANCE_BETWEEN_NODES = 20,
    MAX_NODES_PER_RESOURCE_TYPE = 10,
    NODE_HEALTH = 100,
}
```

#### ResourceNodeBuilder (`src/shared/ResourceNodeBuilder.lua`)
Utility for creating resource node models:
- `CreateWoodNode()`: Creates a simple tree model
- `CreateStoneNode()`: Creates a simple stone formation
- `CreateMetalNode()`: Creates a simple metal deposit
- `CreateResourceNode(resourceType)`: Generic factory method

## Usage

### For Players
1. **Finding Resources**: Look for resource nodes in the world (trees, stone formations, etc.)
2. **Gathering**: Approach a node and hold the interaction key (E by default)
3. **Feedback**: Receive notifications about gathered resources
4. **Respawn**: Wait for nodes to respawn after depletion

### For Developers

#### Adding New Resource Types
1. Add the resource definition to `Constants.RESOURCES`
2. Create a model in ReplicatedStorage or add a builder method to `ResourceNodeBuilder`
3. Update the resource system to handle the new type

#### Spawning Resource Nodes
```lua
-- Via command system
/spawnresource wood
/spawnresource stone
/spawnresource metal

-- Via code
local resourceSystem = ServiceRegistry.Get("ResourceSystem")
local nodeId = resourceSystem:ForceSpawnResourceNode("WOOD", Vector3.new(0, 0, 0))
```

#### Customizing Resource Behavior
Modify the constants in `Constants.lua`:
- `gatherTime`: How long players must hold to gather
- `respawnTime`: How long before a depleted node respawns
- `maxQuantity`: Maximum resources per node
- `MIN_DISTANCE_BETWEEN_NODES`: Spacing between nodes

## Network Events

### Server to Client
- `SERVER_NOTIFY_RESOURCE_GATHERED`: Notifies when resources are gathered
- `SERVER_NOTIFY_RESOURCE_NODE_UPDATE`: Notifies about node state changes

### Client to Server
- `CLIENT_REQUEST_GATHER_RESOURCE`: Request to gather from a node (handled via ProximityPrompt)

## Testing

Run the test suite to verify functionality:
```lua
local ResourceSystemTests = require(game.ServerScriptService.Server.Tests.ResourceSystemTests)
ResourceSystemTests:RunAllTests()
```

## Future Enhancements

### Planned Features
- **Resource Inventory**: Player inventory system for storing gathered resources
- **Crafting System**: Use gathered resources to craft items
- **Resource Quality**: Different quality levels for resources
- **Tool Requirements**: Require specific tools for gathering certain resources
- **Environmental Effects**: Weather and time affecting resource availability

### Technical Improvements
- **Performance Optimization**: Object pooling for resource nodes
- **Persistence**: Save/load resource node states
- **Advanced Spawning**: Biome-based resource spawning
- **Resource Clustering**: Group related resources together

## Integration with Other Systems

### Building System
Resources gathered can be used for building structures (future integration)

### Economy System
Resources can be traded or sold (future integration)

### Quest System
Resource gathering can be part of quest objectives (future integration)

## Troubleshooting

### Common Issues
1. **Nodes not spawning**: Check if ResourceSystem is properly initialized
2. **ProximityPrompts not working**: Verify the model has a PrimaryPart
3. **Respawn not working**: Check respawn timer configuration
4. **Models not loading**: Ensure models exist in ReplicatedStorage or fallback builders are working

### Debug Commands
- `/listresources`: Shows available resource types
- `/spawnresource [type]`: Spawns a resource node at player position

## Performance Considerations

- Resource nodes are limited per type to prevent performance issues
- Respawn checks run on a reasonable interval (every 5 seconds)
- Models are cached to reduce instantiation overhead
- Depleted nodes are visually simplified to reduce rendering cost 