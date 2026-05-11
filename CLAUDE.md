# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**失落奇迹 (Lost Miracle)** — a 2D side-scrolling dungeon crawler / loot RPG. MVP scope: one dungeon floor, three enemy tiers (mob/elite/boss), loot drops, equipment, and gear enhancement.

## Tech Stack

- **Engine**: Godot 4.6.2 stable
- **Language**: GDScript (no C# in MVP)
- **Resolution**: 1280x720, side-view, TileMapLayer-based maps
- **Combat**: Real-time collision, melee attacks, simple skill system

## Architecture

### Scene Structure

```
res://
  scenes/
    player/          — Player.tscn, Player.gd
    monsters/        — BaseMonster.tscn/gd + per-monster scenes
    maps/            — DungeonFloor1.tscn/gd
    items/           — DropItem.tscn/gd
    ui/              — HUD, Inventory, Equipment, Enhance panels
  scripts/
    systems/         — Drop, Spawn, Inventory, Equipment, Enhance, Save systems
    data/            — Database autoloads (Item, Monster, DropTable)
  data/              — JSON data files (items, monsters, drops, spawns)
```

### Core Systems

- **Data-driven design**: All item/monster/drop definitions live in JSON files under `data/`, not hardcoded in scripts.
- **Systems as autoloads**: Game systems should be autoload singletons. Current autoloads: `ItemDatabase`, `DropTableDatabase`, `DropSystem`, `InventorySystem`.
- **Monsters use inheritance**: BaseMonster provides the state machine (Idle/Patrol/Chase/Attack/Hit/Dead); individual monsters extend it.
- **Equipment instances**: Equipped items have a unique UID and enhance level — they are NOT just item_id references.

### Key Data Schemas

- **Item**: `{ name, type (equipment|material), slot, quality, attack, defense, hp, enhanceable }`
- **Equipment instance**: `{ uid, item_id, enhance_level, locked }`
- **Drop table entry**: `{ item_id, min, max, rate }` grouped by monster_id
- **Spawn point**: `{ spawn_id, monster_id, position, respawn_seconds, max_alive }`

### Damage Formula

```
final_damage = max(1, attacker_attack - defender_defense)
if crit: final_damage *= crit_damage
```

### Enhancement Rules

- +1 to +5: failure does NOT downgrade
- +6 to +8: failure downgrades by 1
- +9 to +10: failure downgrades by 1, no gear destruction
- Weapon: +10% attack per level; Armor: +8% defense, +5% HP per level

### Refresh Timers

| Type   | Respawn  | Persisted in save? |
|--------|----------|--------------------|
| Mob    | 60s      | No                 |
| Elite  | 15min    | Yes                |
| Boss   | 1 hour   | Yes                |

Mobs must not respawn if player is within 300px of spawn point. Max 6 mobs per area.

## Development Order

1. Player movement, jumping, attack
2. Map collision (TileMapLayer)
3. Mob combat
4. Drop system
5. Inventory system
6. Equipment system
7. Enhancement system
8. Elite mobs
9. Boss
10. Spawn/refresh system
11. Save system
12. UI polish

Do NOT start with Boss or enhancement UI. Get "kill mob → loot → equip → get stronger" loop working first.

## Controls

| Action | Key |
|--------|-----|
| Move | A / D |
| Jump | Space |
| Attack | Left Mouse Button |
| Skills 1/2/3 | 1 / 2 / 3 |
| Quick Item 1 | F1 |
| Inventory | Tab |

## Art Specs

| Entity | Sprite Size |
|--------|-------------|
| Player | 48x64 or 64x64 |
| Mobs   | 48x48 / 64x64 |
| Elites | 80x80 |
| Boss   | 128x128 or 160x160 |

Equipment quality colors: normal=white, fine=green, rare=blue, epic=purple. No legendaries in MVP.
