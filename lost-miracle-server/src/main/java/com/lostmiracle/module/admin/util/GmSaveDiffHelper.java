package com.lostmiracle.module.admin.util;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;

public final class GmSaveDiffHelper {

    private static final Set<String> PLAYER_FIELDS = Set.of(
            "gold", "level", "exp", "enhance_stone", "blessed_enhance_stone",
            "jewelry_enhance_stone", "blessed_jewelry_enhance_stone", "health_potion"
    );

    private GmSaveDiffHelper() {
    }

    @SuppressWarnings("unchecked")
    public static List<String> summarize(Map<String, Object> before, Map<String, Object> after) {
        List<String> changes = new ArrayList<>();

        Map<String, Object> beforePlayer = playerMap(before);
        Map<String, Object> afterPlayer = playerMap(after);
        for (String field : PLAYER_FIELDS) {
            Object oldValue = beforePlayer.get(field);
            Object newValue = afterPlayer.get(field);
            if (!Objects.equals(oldValue, newValue)) {
                changes.add("player." + field + ": " + format(oldValue) + " -> " + format(newValue));
            }
        }

        int beforeInventory = inventorySize(before);
        int afterInventory = inventorySize(after);
        if (beforeInventory != afterInventory) {
            changes.add("inventory.size: " + beforeInventory + " -> " + afterInventory);
        }

        Object beforeEquipment = before.get("equipment");
        Object afterEquipment = after.get("equipment");
        if (!Objects.equals(beforeEquipment, afterEquipment)) {
            changes.add("equipment: changed");
        }

        if (changes.isEmpty()) {
            changes.add("save: structure changed (no tracked field diff)");
        }
        return changes;
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> playerMap(Map<String, Object> save) {
        Object player = save.get("player");
        if (player instanceof Map<?, ?> map) {
            return (Map<String, Object>) map;
        }
        return Map.of();
    }

    private static int inventorySize(Map<String, Object> save) {
        Object inventory = save.get("inventory");
        if (inventory instanceof List<?> list) {
            return list.size();
        }
        return 0;
    }

    private static String format(Object value) {
        return value == null ? "null" : String.valueOf(value);
    }
}
