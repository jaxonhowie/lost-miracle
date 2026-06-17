package com.lostmiracle.module.loot;

import com.lostmiracle.common.BusinessException;
import com.lostmiracle.common.ErrorCode;
import com.lostmiracle.module.spawn.SpawnConstants;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public final class SaveRewardApplier {

    private SaveRewardApplier() {
    }

    @SuppressWarnings("unchecked")
    public static void apply(Map<String, Object> save, LootRollResult rewards) {
        Map<String, Object> player = requirePlayer(save);
        addExp(player, rewards.exp());
        applyItems(save, player, rewards.items());
        incrementDungeonKills(save, rewards.monsterType());
    }

    @SuppressWarnings("unchecked")
    private static void applyItems(
            Map<String, Object> save,
            Map<String, Object> player,
            List<Map<String, Object>> items
    ) {
        List<Map<String, Object>> inventory = requireInventory(save);
        for (Map<String, Object> item : items) {
            if (item.containsKey("uid")) {
                inventory.add(new HashMap<>(item));
                continue;
            }
            String type = String.valueOf(item.getOrDefault("type", ""));
            int amount = intValue(item.get("amount"));
            switch (type) {
                case "gold" -> player.put("gold", intValue(player.get("gold")) + amount);
                case "enhance_stone" -> player.put("enhance_stone", intValue(player.get("enhance_stone")) + amount);
                case "jewelry_enhance_stone" ->
                        player.put("jewelry_enhance_stone", intValue(player.get("jewelry_enhance_stone")) + amount);
                case "blessed_jewelry_enhance_stone" ->
                        player.put("blessed_jewelry_enhance_stone", intValue(player.get("blessed_jewelry_enhance_stone")) + amount);
                case "health_potion" -> player.put("health_potion", intValue(player.get("health_potion")) + amount);
                default -> {
                }
            }
        }
        save.put("inventory", inventory);
    }

    @SuppressWarnings("unchecked")
    private static void incrementDungeonKills(Map<String, Object> save, String monsterType) {
        Object dungeonObj = save.get("dungeon");
        Map<String, Object> dungeon;
        if (dungeonObj instanceof Map<?, ?> existing) {
            dungeon = (Map<String, Object>) existing;
        } else {
            dungeon = new HashMap<>();
            save.put("dungeon", dungeon);
        }
        String key = switch (monsterType) {
            case SpawnConstants.SPAWN_ELITE -> "elite_kill_count";
            case SpawnConstants.SPAWN_BOSS -> "boss_kill_count";
            default -> "normal_kill_count";
        };
        dungeon.put(key, intValue(dungeon.get(key)) + 1);
    }

    @SuppressWarnings("unchecked")
    private static void addExp(Map<String, Object> player, int amount) {
        int exp = intValue(player.get("exp")) + amount;
        int level = intValue(player.get("level"));
        if (level < 1) {
            level = 1;
        }
        String playerClass = String.valueOf(player.getOrDefault("class", "warrior"));
        Map<String, Object> primaryStats = ensurePrimaryStats(player);

        while (exp >= expRequired(level)) {
            exp -= expRequired(level);
            level++;
            applyLevelUp(playerClass, level, primaryStats);
        }

        player.put("exp", exp);
        player.put("level", level);
        player.put("primary_stats", primaryStats);
        player.put("base_stats", deriveBaseStats(primaryStats));
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> ensurePrimaryStats(Map<String, Object> player) {
        Object statsObj = player.get("primary_stats");
        if (statsObj instanceof Map<?, ?> stats) {
            Map<String, Object> copy = new HashMap<>();
            for (Map.Entry<?, ?> entry : stats.entrySet()) {
                copy.put(String.valueOf(entry.getKey()), intValue(entry.getValue()));
            }
            return copy;
        }
        Map<String, Object> defaults = new HashMap<>();
        defaults.put("STR", 10);
        defaults.put("AGI", 5);
        defaults.put("INT", 3);
        return defaults;
    }

    private static void applyLevelUp(String playerClass, int level, Map<String, Object> primaryStats) {
        ClassStats stats = classStats(playerClass);
        primaryStats.put(stats.main(), intValue(primaryStats.get(stats.main())) + 1);
        int cycle = (level - 1) % 3;
        switch (cycle) {
            case 0 -> primaryStats.put(stats.subA(), intValue(primaryStats.get(stats.subA())) + 1);
            case 1 -> primaryStats.put(stats.subB(), intValue(primaryStats.get(stats.subB())) + 1);
            case 2 -> primaryStats.put(stats.main(), intValue(primaryStats.get(stats.main())) + 1);
            default -> {
            }
        }
    }

    private static Map<String, Object> deriveBaseStats(Map<String, Object> primaryStats) {
        int str = intValue(primaryStats.get("STR"));
        int agi = intValue(primaryStats.get("AGI"));
        int intel = intValue(primaryStats.get("INT"));
        Map<String, Object> base = new HashMap<>();
        base.put("max_hp", 100 + str * 5);
        base.put("max_mp", 50 + intel * 10);
        base.put("atk", 10 + str / 3);
        base.put("def", agi / 3);
        base.put("spd", agi);
        base.put("crit_rate", 0.05 + str * 0.005);
        base.put("crit_dmg", 1.5);
        base.put("lifesteal", 0.0);
        base.put("dodge", 0.05 + agi * 0.005);
        base.put("hit", 1.0);
        return base;
    }

    private static ClassStats classStats(String playerClass) {
        return switch (playerClass) {
            case "ranger", "assassin" -> new ClassStats("AGI", "STR", "INT");
            case "elven" -> new ClassStats("INT", "STR", "AGI");
            default -> new ClassStats("STR", "AGI", "INT");
        };
    }

    private static int expRequired(int level) {
        return level * level * 50;
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> requirePlayer(Map<String, Object> save) {
        Object playerObj = save.get("player");
        if (!(playerObj instanceof Map<?, ?> playerMap)) {
            throw new BusinessException(ErrorCode.INTERNAL_ERROR, "invalid save player data");
        }
        return (Map<String, Object>) playerMap;
    }

    @SuppressWarnings("unchecked")
    private static List<Map<String, Object>> requireInventory(Map<String, Object> save) {
        Object inventoryObj = save.get("inventory");
        if (!(inventoryObj instanceof List<?> inventory)) {
            throw new BusinessException(ErrorCode.INTERNAL_ERROR, "invalid save inventory data");
        }
        List<Map<String, Object>> result = new ArrayList<>();
        for (Object item : inventory) {
            if (item instanceof Map<?, ?> map) {
                result.add((Map<String, Object>) map);
            }
        }
        return result;
    }

    private static int intValue(Object value) {
        if (value instanceof Number number) {
            return number.intValue();
        }
        if (value == null) {
            return 0;
        }
        try {
            return Integer.parseInt(String.valueOf(value));
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    private record ClassStats(String main, String subA, String subB) {
    }
}
