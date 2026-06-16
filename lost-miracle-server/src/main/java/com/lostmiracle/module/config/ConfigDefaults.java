package com.lostmiracle.module.config;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.util.LinkedHashMap;
import java.util.Map;

public final class ConfigDefaults {

    public static final String LOOT_EQUIP_DROP = "loot.equip_drop";
    public static final String LOOT_GOLD_DROP = "loot.gold_drop";
    public static final String LOOT_STONE_DROP = "loot.stone_drop";
    public static final String DUNGEON_EXPLORE = "dungeon.explore";
    public static final String ENHANCE_RULES = "enhance.rules";
    public static final String SPAWN_CONSTANTS = "spawn.constants";

    private ConfigDefaults() {
    }

    public static Map<String, DefaultEntry> all(ObjectMapper objectMapper) {
        Map<String, DefaultEntry> entries = new LinkedHashMap<>();
        entries.put(LOOT_EQUIP_DROP, entry("装备掉率", lootEquipDrop()));
        entries.put(LOOT_GOLD_DROP, entry("金币掉落区间", lootGoldDrop()));
        entries.put(LOOT_STONE_DROP, entry("强化石掉落", lootStoneDrop()));
        entries.put(DUNGEON_EXPLORE, entry("地牢探索事件权重", dungeonExplore(objectMapper)));
        entries.put(ENHANCE_RULES, entry("强化规则", enhanceRules(objectMapper)));
        entries.put(SPAWN_CONSTANTS, entry("刷怪槽常量", spawnConstants()));
        return entries;
    }

    private static DefaultEntry entry(String description, Map<String, Object> json) {
        return new DefaultEntry(description, json);
    }

    private static Map<String, Object> lootEquipDrop() {
        return Map.of(
                "normal", Map.of("rate", 0.30, "min", 1, "max", 1),
                "elite", Map.of("rate", 0.60, "min", 1, "max", 2),
                "boss", Map.of("rate", 1.0, "min", 2, "max", 3)
        );
    }

    private static Map<String, Object> lootGoldDrop() {
        return Map.of(
                "normal", Map.of("min", 10, "max", 30),
                "elite", Map.of("min", 30, "max", 80),
                "boss", Map.of("min", 100, "max", 300)
        );
    }

    private static Map<String, Object> lootStoneDrop() {
        return Map.of(
                "normal", Map.of("min", 0, "max", 1, "rate", 0.10),
                "elite", Map.of("min", 1, "max", 2, "rate", 0.25),
                "boss", Map.of("min", 2, "max", 5, "rate", 0.50)
        );
    }

    private static Map<String, Object> dungeonExplore(ObjectMapper objectMapper) {
        return readClasspathJson(objectMapper, "data/dungeon_events.json");
    }

    private static Map<String, Object> enhanceRules(ObjectMapper objectMapper) {
        return readClasspathJson(objectMapper, "data/enhance_rules.json");
    }

    private static Map<String, Object> spawnConstants() {
        return Map.of(
                "normal_slots_per_monster", 3,
                "normal_cooldown_sec", 60,
                "elite_cooldown_sec", 180,
                "boss_cooldown_sec", 300
        );
    }

    private static Map<String, Object> readClasspathJson(ObjectMapper objectMapper, String path) {
        try (var input = ConfigDefaults.class.getClassLoader().getResourceAsStream(path)) {
            if (input == null) {
                return Map.of();
            }
            return objectMapper.readValue(input, new TypeReference<Map<String, Object>>() {
            });
        } catch (Exception e) {
            return Map.of();
        }
    }

    public record DefaultEntry(String description, Map<String, Object> json) {
    }
}
