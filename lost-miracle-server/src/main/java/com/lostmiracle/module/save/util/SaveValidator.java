package com.lostmiracle.module.save.util;

import com.lostmiracle.common.BusinessException;
import com.lostmiracle.common.ErrorCode;

import java.util.List;
import java.util.Map;
import java.util.Set;

public final class SaveValidator {

    private static final int MAX_INVENTORY_SIZE = 200;
    private static final int MIN_LEVEL = 1;
    private static final int MAX_LEVEL = 100;
    private static final long MAX_GOLD = 10_000_000L;
    private static final int MAX_ENHANCE_STONE = 99_999;
    private static final int MAX_BLESSED_ENHANCE_STONE = 9_999;
    private static final int MAX_JEWELRY_ENHANCE_STONE = 99_999;
    private static final int MAX_BLESSED_JEWELRY_ENHANCE_STONE = 9_999;
    private static final int MAX_HEALTH_POTION = 9_999;
    private static final int MAX_ENHANCE_LEVEL = 10;

    private static final Set<String> VALID_EQUIPMENT_SLOTS = Set.of(
            "weapon", "helmet", "armor", "legs", "gloves",
            "ring_left", "ring_right", "necklace"
    );

    private static final Set<String> VALID_CLASSES = Set.of(
            "warrior", "ranger", "assassin", "elven"
    );

    private static final int MAX_STAT_VALUE = 9_999;
    private static final int MAX_ALTAR_BUFFS = 10;
    private static final long MAX_KILL_COUNT = 99_999L;
    private static final double MAX_BATTLE_ROAR_DURATION = 600.0;
    private static final double MAX_ATK_SPD_PERCENT = 200.0;

    private SaveValidator() {
    }

    @SuppressWarnings("unchecked")
    public static void validate(Map<String, Object> save) {
        Object playerObj = save.get("player");
        if (!(playerObj instanceof Map<?, ?> playerMap)) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "missing player data");
        }
        Map<String, Object> player = (Map<String, Object>) playerMap;
        if (!player.containsKey("level")) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "missing player.level");
        }

        int level = intValue(player.get("level"));
        if (level < MIN_LEVEL || level > MAX_LEVEL) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "invalid player.level");
        }

        if (player.containsKey("exp")) {
            int exp = intValue(player.get("exp"));
            if (exp < 0 || exp >= expRequired(level)) {
                throw new BusinessException(ErrorCode.BAD_REQUEST, "invalid player.exp");
            }
        }

        validateNonNegativeLong(player, "gold", MAX_GOLD);
        validateNonNegativeInt(player, "enhance_stone", MAX_ENHANCE_STONE);
        validateNonNegativeInt(player, "blessed_enhance_stone", MAX_BLESSED_ENHANCE_STONE);
        validateNonNegativeInt(player, "jewelry_enhance_stone", MAX_JEWELRY_ENHANCE_STONE);
        validateNonNegativeInt(player, "blessed_jewelry_enhance_stone", MAX_BLESSED_JEWELRY_ENHANCE_STONE);
        validateNonNegativeInt(player, "health_potion", MAX_HEALTH_POTION);

        Object inventoryObj = save.get("inventory");
        if (!(inventoryObj instanceof List<?> inventory)) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "missing inventory");
        }
        if (inventory.size() > MAX_INVENTORY_SIZE) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "inventory too large");
        }
        validateInventoryItems(inventory);
        validateEquipment(save);
        validatePlayerExtended(player);
        validateDungeon(save);
        validateWorld(save);
    }

    @SuppressWarnings("unchecked")
    private static void validateInventoryItems(List<?> inventory) {
        for (int i = 0; i < inventory.size(); i++) {
            Object itemObj = inventory.get(i);
            if (!(itemObj instanceof Map<?, ?> itemMap)) {
                throw new BusinessException(ErrorCode.BAD_REQUEST, "inventory[" + i + "] not an object");
            }
            Map<String, Object> item = (Map<String, Object>) itemMap;

            if (itemIdentifier(item).isBlank()) {
                throw new BusinessException(ErrorCode.BAD_REQUEST, "inventory[" + i + "] must have a non-empty id or uid");
            }

            if (item.containsKey("enhance_level")) {
                int enhanceLevel = intValue(item.get("enhance_level"));
                if (enhanceLevel < 0 || enhanceLevel > MAX_ENHANCE_LEVEL) {
                    throw new BusinessException(ErrorCode.BAD_REQUEST,
                            "inventory[" + i + "].enhance_level must be 0-" + MAX_ENHANCE_LEVEL);
                }
            }
        }
    }

    private static String itemIdentifier(Map<String, Object> item) {
        Object idObj = item.get("id");
        if (idObj instanceof String id && !id.isBlank()) {
            return id;
        }
        Object uidObj = item.get("uid");
        if (uidObj instanceof String uid && !uid.isBlank()) {
            return uid;
        }
        return "";
    }

    @SuppressWarnings("unchecked")
    private static void validateEquipment(Map<String, Object> save) {
        Object equippedObj = save.get("equipment");
        if (equippedObj == null) {
            return;
        }
        if (!(equippedObj instanceof Map<?, ?> equippedMap)) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "equipment must be an object");
        }
        Map<String, Object> equipped = (Map<String, Object>) equippedMap;
        for (String slot : equipped.keySet()) {
            if (!VALID_EQUIPMENT_SLOTS.contains(slot)) {
                throw new BusinessException(ErrorCode.BAD_REQUEST, "invalid equipment slot: " + slot);
            }
        }
    }

    @SuppressWarnings("unchecked")
    private static void validatePlayerExtended(Map<String, Object> player) {
        if (player.containsKey("class")) {
            Object classObj = player.get("class");
            if (!(classObj instanceof String cls) || !VALID_CLASSES.contains(cls)) {
                throw new BusinessException(ErrorCode.BAD_REQUEST,
                        "invalid player.class, allowed: " + VALID_CLASSES);
            }
        }

        if (player.containsKey("primary_stats")) {
            Object statsObj = player.get("primary_stats");
            if (!(statsObj instanceof Map<?, ?> statsMap)) {
                throw new BusinessException(ErrorCode.BAD_REQUEST, "player.primary_stats must be an object");
            }
            Map<String, Object> stats = (Map<String, Object>) statsMap;
            for (Map.Entry<String, Object> entry : stats.entrySet()) {
                long v = longValue(entry.getValue());
                if (v < 0 || v > MAX_STAT_VALUE) {
                    throw new BusinessException(ErrorCode.BAD_REQUEST,
                            "player.primary_stats." + entry.getKey() + " out of range");
                }
            }
        }

        if (player.containsKey("base_stats")) {
            Object statsObj = player.get("base_stats");
            if (!(statsObj instanceof Map<?, ?>)) {
                throw new BusinessException(ErrorCode.BAD_REQUEST, "player.base_stats must be an object");
            }
        }

        if (player.containsKey("altar_buffs")) {
            Object buffsObj = player.get("altar_buffs");
            if (!(buffsObj instanceof List<?> buffs)) {
                throw new BusinessException(ErrorCode.BAD_REQUEST, "player.altar_buffs must be an array");
            }
            if (buffs.size() > MAX_ALTAR_BUFFS) {
                throw new BusinessException(ErrorCode.BAD_REQUEST,
                        "player.altar_buffs too large (max " + MAX_ALTAR_BUFFS + ")");
            }
        }

        if (player.containsKey("battle_roar_remaining")) {
            double v = doubleValue(player.get("battle_roar_remaining"));
            if (v < 0 || v > MAX_BATTLE_ROAR_DURATION) {
                throw new BusinessException(ErrorCode.BAD_REQUEST, "invalid player.battle_roar_remaining");
            }
        }

        if (player.containsKey("battle_roar_atk_spd_percent")) {
            double v = doubleValue(player.get("battle_roar_atk_spd_percent"));
            if (v < 0 || v > MAX_ATK_SPD_PERCENT) {
                throw new BusinessException(ErrorCode.BAD_REQUEST, "invalid player.battle_roar_atk_spd_percent");
            }
        }
    }

    @SuppressWarnings("unchecked")
    private static void validateDungeon(Map<String, Object> save) {
        Object dungeonObj = save.get("dungeon");
        if (dungeonObj == null) {
            return;
        }
        if (!(dungeonObj instanceof Map<?, ?> dungeonMap)) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "dungeon must be an object");
        }
        Map<String, Object> dungeon = (Map<String, Object>) dungeonMap;
        for (String key : new String[]{"normal_kill_count", "elite_kill_count", "boss_kill_count"}) {
            if (dungeon.containsKey(key)) {
                long v = longValue(dungeon.get(key));
                if (v < 0 || v > MAX_KILL_COUNT) {
                    throw new BusinessException(ErrorCode.BAD_REQUEST, "invalid dungeon." + key);
                }
            }
        }
    }

    @SuppressWarnings("unchecked")
    private static void validateWorld(Map<String, Object> save) {
        Object worldObj = save.get("world");
        if (worldObj == null) {
            return;
        }
        if (!(worldObj instanceof Map<?, ?>)) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "world must be an object");
        }
    }

    private static int expRequired(int level) {
        return level * level * 50;
    }

    private static void validateNonNegativeInt(Map<String, Object> player, String field, int max) {
        if (!player.containsKey(field)) {
            return;
        }
        long value = longValue(player.get(field));
        if (value < 0 || value > max) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "invalid player." + field);
        }
    }

    private static void validateNonNegativeLong(Map<String, Object> player, String field, long max) {
        if (!player.containsKey(field)) {
            return;
        }
        long value = longValue(player.get(field));
        if (value < 0 || value > max) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "invalid player." + field);
        }
    }

    private static int intValue(Object value) {
        return (int) longValue(value);
    }

    private static long longValue(Object value) {
        if (value instanceof Number number) {
            return number.longValue();
        }
        if (value == null) {
            return 0L;
        }
        try {
            return Long.parseLong(String.valueOf(value));
        } catch (NumberFormatException e) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "invalid numeric value");
        }
    }

    private static double doubleValue(Object value) {
        if (value instanceof Number number) {
            return number.doubleValue();
        }
        if (value == null) {
            return 0.0;
        }
        try {
            return Double.parseDouble(String.valueOf(value));
        } catch (NumberFormatException e) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "invalid numeric value");
        }
    }
}
