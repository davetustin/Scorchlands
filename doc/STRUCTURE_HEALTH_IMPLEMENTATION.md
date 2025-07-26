# Structure Health System Implementation

## Overview
The Structure Health System has been successfully implemented for Scorchlands, providing a robust health-based degradation system for player-built structures (walls, floors, roofs) that are exposed to sunlight.

## Key Features Implemented

### 1. Health-Based System
- **Material Types**: Currently supports Wood (expandable to Stone, Metal, etc.)
- **Health Values**: Configurable max health per material type
- **Damage Rates**: Configurable sunlight damage rate per material type
- **Repair System**: Players can repair structures to full health

### 2. Sunlight Integration
- **Automatic Detection**: Uses raycasting to detect direct sunlight exposure
- **Damage Application**: Structures only take damage when exposed to sunlight
- **Performance Optimized**: Configurable check intervals to balance performance and accuracy

### 3. Persistence System
- **Data Storage**: Structure health data persists across server restarts
- **Player Ownership**: Each structure tracks its owner for repair permissions
- **Automatic Saving**: Data is saved when structures are placed, repaired, or destroyed

### 4. Repair Notifications
- **Warning Thresholds**: Configurable health thresholds for repair warnings
- **Critical Alerts**: Separate notifications for critically damaged structures
- **Owner Targeting**: Notifications are sent to structure owners when online

### 5. Client-Side Integration
- **Repair Mode**: Players can toggle repair mode with 'E' key
- **Mouse Targeting**: Click on structures to repair them
- **Visual Feedback**: Clear indication of repair mode status

## Files Modified/Created

### Constants (`src/shared/Constants.lua`)
- Added `STRUCTURE_HEALTH` constants section
- Added material properties (Wood: 100 health, 2 damage/sec)
- Added repair notification thresholds
- Added new RemoteFunction for repair requests

### BuildingSystem (`src/server/Systems/BuildingSystem.lua`)
- **Extended with health tracking**: Added `_structureHealthData` table
- **Sunlight damage system**: Periodic checks for sunlight exposure
- **Health management**: Automatic health updates and structure destruction
- **Persistence integration**: Save/load structure health data
- **Repair functionality**: Server-side repair validation and processing

### DataManager (`src/server/Core/DataManager.lua`)
- **Added structure data methods**: `LoadStructureData()` and `SaveStructureData()`
- **DataStore integration**: Persistent storage for structure health data

### BuildingClient (`src/client/BuildingClient.lua`)
- **Repair mode**: Toggle with 'E' key, disable with 'Q' key
- **Mouse targeting**: Click structures to repair them
- **Network integration**: Repair request handling

### Test Script (`src/server/Systems/StructureHealthTest.lua`)
- **System validation**: Tests for proper initialization
- **Health monitoring**: Logs structure health information
- **Debugging tools**: Comprehensive health status reporting

## Configuration

### Material Properties (in Constants.lua)
```lua
MATERIALS = {
    WOOD = {
        name = "Wood",
        maxHealth = 100,
        sunlightDamageRate = 2, -- damage per second
        repairCost = 1, -- placeholder for future material system
    },
    -- Future materials can be added here
}
```

### Health Check Intervals
- **Health Check**: Every 1.0 seconds
- **Sunlight Check**: Every 0.5 seconds
- **Repair Warning**: Below 25 health
- **Critical Warning**: Below 10 health

## Usage Instructions

### For Players
1. **Building**: Use existing building system (W, F, R keys)
2. **Repair Mode**: Press 'E' to toggle repair mode
3. **Repairing**: Click on damaged structures to repair them
4. **Exit Repair**: Press 'Q' to exit repair mode

### For Developers
1. **Testing**: Use `StructureHealthTest.lua` to validate system
2. **Monitoring**: Check logs for health status and damage events
3. **Configuration**: Adjust constants in `Constants.lua` for balance

## Performance Considerations

### Optimizations Implemented
- **Interval-based checks**: Not every frame to reduce CPU usage
- **Efficient raycasting**: Optimized sunlight detection
- **Memory management**: Automatic cleanup of destroyed structures
- **Cached data**: Structure lookups optimized

### Monitoring
- **Logging**: Comprehensive debug and info logging
- **Health tracking**: Real-time health status monitoring
- **Performance metrics**: Check intervals and processing times

## Future Enhancements

### Planned Features
1. **Material System**: Add Stone, Metal, and other materials
2. **Visual Damage**: Structure appearance changes with health
3. **Repair Costs**: Material requirements for repairs
4. **Advanced Notifications**: UI-based repair alerts
5. **Weather Effects**: Additional environmental damage sources

### Extensibility
- **Easy material addition**: Add new materials to constants
- **Modular damage system**: Extensible damage sources
- **Plugin architecture**: Easy to add new health features

## Testing

### Manual Testing
1. Place structures in sunlight
2. Observe health degradation over time
3. Test repair functionality
4. Verify persistence across server restarts

### Automated Testing
- Use `StructureHealthTest.lua` for system validation
- Check log output for proper initialization
- Monitor health values and damage application

## Security Considerations

### Server-Side Validation
- **Ownership verification**: Only owners can repair structures
- **Rate limiting**: Prevents spam repair attempts
- **Data validation**: All health data validated server-side
- **Anti-exploit**: Structure placement and health validation

### Data Integrity
- **Persistent storage**: Reliable data persistence
- **Error handling**: Graceful failure recovery
- **Data validation**: Consistent data structure enforcement

## Conclusion

The Structure Health System is now fully integrated into Scorchlands, providing a robust foundation for structure degradation and repair mechanics. The system is performant, secure, and easily extensible for future enhancements.

The implementation follows best practices for Roblox development, including proper separation of concerns, comprehensive logging, and robust error handling. The system is ready for production use and can be easily configured and extended as needed. 