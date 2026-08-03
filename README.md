[README.md](https://github.com/user-attachments/files/30660410/README.md)
# Farmer Savior

**Farmer Savior** is a top-down 2D farm-defence survival game prototype developed in **Godot**. The player prepares during the day by farming, collecting resources, buying upgrades, repairing damaged objects, and placing defences. At night, enemies attack from outside the farm perimeter and the player must survive while protecting the farm.

This project was originally proposed as:

> **Game Development: A Data-Driven Roguelike System for Enhancing Four Key Player-Experience Dimensions via Procedural Generation and Adaptive Difficulty**

During development, the scope was refined into the final prototype title **Farmer Savior**. Procedural generation and full adaptive difficulty are treated as future-work directions, while the current build focuses on a playable farm-defence vertical slice.

---

## Project Overview

Farmer Savior combines:

- Daytime preparation
- Night-time enemy waves
- Farming and resource collection
- Pistol and hoe combat
- Enemy drops
- Upgrade purchasing
- Inventory management
- War Table defence placement
- Pesticide Turrets
- Damageable fences
- Repair systems
- Save/load support
- Tutorial progression
- Telemetry logging
- Dark horror pixel-art presentation
- Ambient music and gameplay sound effects

The goal of the prototype is to demonstrate a readable combat loop, meaningful preparation choices, fair enemy pressure, and a clear day-night farm-defence structure.

---

## Engine and Tools

- **Game Engine:** Godot
- **Language:** GDScript
- **Art Style:** 2D pixel art with a dark rural horror theme
- **Version Control:** Git / GitHub
- **Target Platform:** Windows desktop prototype

Recommended Godot version:

```text
Godot 4.x
```

The project was developed and tested using a Godot 4 workflow.

---

## Main Gameplay Loop

1. **Daytime Preparation**
   - Explore the farm and house.
   - Plant crops.
   - Collect and manage resources.
   - Use the Workshop to buy upgrades.
   - Use the War Table to place defences.
   - Repair damaged structures when possible.

2. **Night Defence**
   - At night, enemies spawn outside the farm.
   - Enemies approach the perimeter, attack fences, and enter through breaches.
   - The player uses weapons and defences to survive.
   - Pesticide Turrets automatically attack enemies but can be damaged or lose durability.

3. **Progression**
   - Enemies and crops provide resources.
   - Resources are used for planting, repairing, and upgrades.
   - The next day begins only after the remaining night enemies are defeated.

---

## Controls

Default controls may be changed in the in-game **Settings** menu.

| Action | Default Input |
|---|---|
| Move Up | W |
| Move Down | S |
| Move Left | A |
| Move Right | D |
| Aim | Mouse |
| Shoot / Select | Left Mouse Button |
| Hoe Attack | Right Mouse Button / X |
| Reload | R |
| Interact | E |
| Repair | F |
| Inventory | I / Bag Button |
| Pause / Back | Esc |

The Settings menu supports control rebinding and saves custom input bindings locally.

---

## Implemented Features

### Player and Combat

- Player movement and directional animations
- Pistol shooting
- Reserve-ammo reload system
- Current ammo / max ammo / reserve ammo HUD
- Hoe melee attack with timed hitbox activation
- Player damage feedback and death sequence

### Enemies

- Crop Mite
- Rot Crop
- Blight Pig
- Tutorial boss
- Enemy movement, attacks, hurt states, and death states
- Special attack behaviours such as Rot Crop pulse and Blight Pig charge

### Farming and Resources

- Seeds
- Scrap
- Mutant Seeds
- Crop planting
- Crop growth and rewards
- Enemy resource drops
- Inventory resource tracking

### Defence Systems

- War Table placement interface
- Pesticide Turrets
- Turret firing, durability, health bar, damaged state, broken state, collision, and field repair
- Damageable perimeter fences
- Enemy interaction with fences and breaches

### UI and Menus

- Title screen
- Pause menu
- Save/load menu
- Inventory UI
- Workshop upgrade UI
- War Table placement UI
- Settings / control rebinding menu
- Weapon and ammo HUD
- Tutorial objective text

### Save, Load, and Telemetry

- Manual save slots
- Autosave support
- Player state persistence
- Pistol ammo persistence
- Inventory/resource persistence
- Crop state persistence
- Defence and fence state persistence
- Upgrade persistence
- JSON-lines telemetry logging for important gameplay events

### Audio

- Farm/menu ambient music
- Night ambience layer
- Basic gameplay sound effects:
  - Pistol shot
  - Reload
  - Enemy hit
  - Enemy death
  - Pickup collected
  - Turret fire
  - Night starts
  - Button click

---

## Folder Structure

The project is organised using separate folders for scripts, scenes, sprites, and audio assets.

```text
Farmer Savior/
├── assets/
│   └── audio/
│       ├── music/
│       ├── ambience/
│       └── sfx/
├── scenes/
│   ├── main/
│   ├── maps/
│   ├── player/
│   ├── enemies/
│   ├── farm/
│   ├── items/
│   └── ui/
├── scripts/
│   ├── managers/
│   ├── player/
│   ├── enemies/
│   ├── farm/
│   ├── items/
│   ├── ui/
│   └── weapons/
└── sprites/
    ├── player/
    ├── enemies/
    ├── farm/
    ├── items/
    ├── maps/
    └── ui/
```

---

## How to Run

1. Install Godot 4.x.
2. Clone or download this repository.
3. Open Godot.
4. Click **Import**.
5. Select the project folder containing `project.godot`.
6. Open the project.
7. Press **F5** or click **Run Project**.

---

## Important Setup Notes

### AudioManager Autoload

The audio system uses an autoload singleton.

In Godot, check:

```text
Project → Project Settings → Globals → Autoload
```

There should be an autoload entry similar to:

```text
Name: AudioManager
Path: res://scripts/managers/AudioManager.gd
Global Variable: Enabled
```

### Audio Import Settings

For looping ambience/music, ensure the audio files are imported correctly. If needed, select the file in Godot, open the **Import** tab, set loop mode, and click **Reimport**.

### Pixel Art Import Settings

For pixel-art sprites, recommended import settings are:

```text
Filter: Off / Nearest
Mipmaps: Off
Compression: Lossless
Repeat: Disabled
```

---

## Known Limitations

This is a student capstone prototype, not a finished commercial game. Some systems are intentionally simplified or left as future work.

Known limitations include:

- Farming depth is still limited.
- Resource-management balance needs longer playtesting.
- Upgrade variety is not yet deep enough for full build diversity.
- Full procedural generation was not implemented.
- Full adaptive difficulty was not implemented.
- Advanced pathfinding such as flow fields was deferred.
- NightLight gameplay is not treated as a final evaluated feature.
- More art polish and scale consistency would improve presentation.
- Audio volume balancing and accessibility options can be expanded further.
- Save/load works for the prototype, but production-grade crash recovery and schema migration were not implemented.

---

## Future Work

Possible future improvements include:

- More crop types and farming decisions
- Deeper resource sinks and economy balancing
- More upgrades and build paths
- Additional enemy types and boss behaviours
- More polished fence and defence visuals
- Better enemy pathfinding under large wave counts
- Expanded accessibility settings
- Volume sliders and separate audio buses
- More telemetry-based balancing
- Procedural map generation as a later research direction
- Bounded adaptive difficulty after baseline telemetry is stable

---

## Team / Project Context

This repository was developed as part of the **Farmer Savior Capstone Project**.

Final prototype title:

```text
Farmer Savior
```

Original proposal title:

```text
Game Development: A Data-Driven Roguelike System for Enhancing Four Key Player-Experience Dimensions via Procedural Generation and Adaptive Difficulty
```

---

## Status

Current status:

```text
Final capstone prototype / vertical slice
```

The prototype demonstrates the main gameplay loop and is suitable for final project demonstration, report evidence, and further development.
