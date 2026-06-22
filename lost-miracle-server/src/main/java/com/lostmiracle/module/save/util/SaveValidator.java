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
            "weapon", "head", "body", "legs", "feet",
            "ring_left", "ring_right", "necklace"
    );

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
        validateEquipped(save);
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
    private static void validateEquipped(Map<String, Object> save) {
        Object equippedObj = save.get("equipped");
        if (equippedObj == null) {
            return;
        }
        if (!(equippedObj instanceof Map<?, ?> equippedMap)) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "equipped must be an object");
        }
        Map<String, Object> equipped = (Map<String, Object>) equippedMap;
        for (String slot : equipped.keySet()) {
            if (!VALID_EQUIPMENT_SLOTS.contains(slot)) {
                throw new BusinessException(ErrorCode.BAD_REQUEST, "invalid equipment slot: " + slot);
            }
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
}
