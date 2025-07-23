# Scorchlands - Game Design and Development Plan

## ✡️ Game Overview
**Title**: Scorchlands  
**Genre**: Survival / Exploration  
**Platform**: Roblox  
**Core Loop**: Build and maintain a base that degrades under sunlight. Venture into dangerous sunlit zones to gather resources needed to repair and expand your base.

---

## ♻ Core Game Loop
1. **Spawn in central shadowed hub**
   - Tutorial introduces sunlight danger and survival basics.

2. **Establish a Shadow Base**
   - Players place initial shelter using basic materials.
   - Structures degrade over time when exposed to sunlight.

3. **Venture Out for Resources**
   - Gather materials (wood, scrap metal, stone, etc.)
   - Deeper zones offer better materials with higher risk.

4. **Avoid the Sun**
   - Exposure drains health.
   - Stay in shadows or craft gear to reduce damage.

5. **Return and Upgrade**
   - Repair, expand, and reinforce base.
   - Upgrade materials to reduce degradation speed.

6. **Repeat Loop**
   - Survive longer, unlock tougher zones, discover better materials.

---

## ⚙️ Design Pillars
| Pillar               | Description                                                                 |
|----------------------|-----------------------------------------------------------------------------|
| Shadow is Safety     | Core tension mechanic.                                                      |
| Base is Home         | Maintain your shelter against sun damage.                                   |
| Risk vs. Reward      | Better materials are in riskier areas.                                      |
| Decay Over Time      | Encourages regular maintenance and return trips.                            |
| Dynamic World        | Weather, sun cycles, and environmental threats enhance gameplay variety.    |

---

## 🌞 Sunlight System
- **Directional Light** simulates sun.
- **Raycasting** from sun to player for exposure detection.
- Exposure timer determines damage interval.
- Sun intensity increases as survival time progresses.
- Random weather events (e.g., cloud cover) influence gameplay.

---

## 🏠 Base Building System
- **Materials**: Wood (fast decay), Stone, Scrap Metal, Solar-resistant tech.
- **Degradation Timers** on all structure components.
- **Crafting Bench**: Combine and upgrade materials.
- **Shadows**: Structures cast usable shade for survival.

---

## 🎓 Crafting & Resource System
- **Craftables**: Shade structures, cloaks, tools, walls, repairs.
- **Resource Types**:
  - *Wood*: Easy to find, quick to decay.
  - *Stone*: Longer lasting.
  - *Metal*: Heat-resistant but rare.
- **Workbench** for crafting new items and repairing structures.

---

## 🌍 Exploration Zones
- **Safe Zone (Hub)**:
  - Shelter, traders, social space.
  - Tutorial and staging area.
- **Outer Zones**:
  - Tiered by distance/difficulty.
  - Zone 1: Forest edge, basic materials.
  - Zone 2: Abandoned ruins, rare loot.
  - Zone 3: Scorched lands, full sun, high rewards.

---

## 👥 Multiplayer & Teamplay
- Solo or group base-building.
- Shared materials and responsibilities.
- Group benefits: faster building, extended exploration.

---

## 🌐 MVP Development Plan
### Phase 1 – Core Systems
- [ ] Sunlight health drain via raycasting
- [ ] Static shadow safe zones
- [ ] Basic structure placement (wall, roof, floor)
- [ ] Structure degradation timers
- [ ] Simple resource nodes and gathering

### Phase 2 – Game Loop
- [ ] Repair & crafting system
- [ ] Base expansion mechanics
- [ ] Zone system with increasing difficulty
- [ ] Day/night/weather cycles

### Phase 3 – Polish & Live Features
- [ ] UI: health, exposure meter, structure durability
- [ ] Player inventory system
- [ ] Tutorial onboarding zone
- [ ] Save system using DataStore
- [ ] Gamepass: cosmetics, base themes, resource boosts

---

## 🎨 Art Style & Visuals
- Stylized and moody
- High contrast lighting (bright sun vs deep shadow)
- Heat shimmer and screen effects under sunlight
- Clean, low-poly structures for performance

---

## ♻ Replayability & Progression
- **XP/Levels**: Unlock gear and abilities.
- **Blueprints**: Unlock structures and upgrades.
- **Leaderboards**: Survival streak, base size, repairs made.

---

## Optional Advanced Features
- Sun-powered enemies
- Shadow-dwelling pets
- Environmental hazards (lava, solar flares)
- Solar panel technology that requires risk exposure

---

## 🔹 Next Steps
Would you like to:
- Expand this into a full GDD template?
- Get Lua code examples for sunlight detection or structure decay?
- Prototype map or asset planning?

Let me know where to go next!

