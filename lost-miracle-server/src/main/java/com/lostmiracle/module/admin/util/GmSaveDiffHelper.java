package com.lostmiracle.module.admin.util;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;

public final class GmSaveDiffHelper {

    private static final int MAX_CHANGES = 120;

    private static final Map<String, String> LABELS = Map.ofEntries(
            Map.entry("player.gold", "金币"),
            Map.entry("player.level", "等级"),
            Map.entry("player.exp", "经验"),
            Map.entry("player.enhance_stone", "强化石"),
            Map.entry("player.blessed_enhance_stone", "祝福强化石"),
            Map.entry("player.jewelry_enhance_stone", "首饰强化石"),
            Map.entry("player.blessed_jewelry_enhance_stone", "祝福首饰石"),
            Map.entry("player.health_potion", "生命药水"),
            Map.entry("player.class", "职业"),
            Map.entry("player.battle_roar_remaining", "战吼剩余秒数"),
            Map.entry("player.battle_roar_atk_spd_percent", "战吼攻速加成"),
            Map.entry("player.primary_stats.STR", "力量 STR"),
            Map.entry("player.primary_stats.AGI", "敏捷 AGI"),
            Map.entry("player.primary_stats.INT", "智力 INT"),
            Map.entry("player.base_stats.max_hp", "生命上限"),
            Map.entry("player.base_stats.max_mp", "魔法上限"),
            Map.entry("player.base_stats.atk", "攻击"),
            Map.entry("player.base_stats.def", "防御"),
            Map.entry("player.base_stats.spd", "速度"),
            Map.entry("player.base_stats.hit", "命中"),
            Map.entry("player.base_stats.dodge", "闪避"),
            Map.entry("world.current_dungeon_id", "当前地牢"),
            Map.entry("world.auto_battle", "自动战斗"),
            Map.entry("dungeon.normal_kill_count", "普通击杀"),
            Map.entry("dungeon.elite_kill_count", "精英击杀"),
            Map.entry("dungeon.boss_kill_count", "Boss 击杀"),
            Map.entry("equipment.weapon", "武器槽"),
            Map.entry("equipment.helmet", "头盔槽"),
            Map.entry("equipment.armor", "护甲槽"),
            Map.entry("equipment.legs", "护腿槽"),
            Map.entry("equipment.gloves", "手套槽"),
            Map.entry("equipment.ring_left", "左戒槽"),
            Map.entry("equipment.ring_right", "右戒槽"),
            Map.entry("equipment.necklace", "项链槽")
    );

    private GmSaveDiffHelper() {
    }

    @SuppressWarnings("unchecked")
    public static List<String> summarize(Map<String, Object> before, Map<String, Object> after) {
        List<String> changes = new ArrayList<>();
        diffValue(changes, "", before, after);
        if (changes.isEmpty()) {
            changes.add("未检测到字段级变更（若 checksum 已变化，可能是 JSON 字段顺序或非业务字段差异）");
        }
        return changes;
    }

    @SuppressWarnings("unchecked")
    private static void diffValue(List<String> changes, String path, Object before, Object after) {
        if (changes.size() >= MAX_CHANGES) {
            return;
        }

        if (path.equals("inventory")) {
            diffInventory(changes, inventoryMap(before), inventoryMap(after));
            return;
        }

        if (before instanceof Map<?, ?> beforeMap && after instanceof Map<?, ?> afterMap) {
            diffMap(changes, path, (Map<String, Object>) beforeMap, (Map<String, Object>) afterMap);
            return;
        }

        if (before instanceof List<?> beforeList && after instanceof List<?> afterList) {
            diffList(changes, path, beforeList, afterList);
            return;
        }

        if (!valuesEqual(before, after)) {
            addChange(changes, path, before, after);
        }
    }

    private static void diffMap(
            List<String> changes,
            String path,
            Map<String, Object> before,
            Map<String, Object> after
    ) {
        Set<String> keys = new LinkedHashSet<>();
        keys.addAll(before.keySet());
        keys.addAll(after.keySet());
        for (String key : keys) {
            if (changes.size() >= MAX_CHANGES) {
                return;
            }
            String childPath = path.isEmpty() ? key : path + "." + key;
            Object oldValue = before.get(key);
            Object newValue = after.get(key);
            if (oldValue == null && newValue == null) {
                continue;
            }
            if (oldValue == null || newValue == null) {
                addChange(changes, childPath, oldValue, newValue);
                continue;
            }
            diffValue(changes, childPath, oldValue, newValue);
        }
    }

    private static void diffList(List<String> changes, String path, List<?> before, List<?> after) {
        int max = Math.max(before.size(), after.size());
        for (int i = 0; i < max; i++) {
            if (changes.size() >= MAX_CHANGES) {
                return;
            }
            String childPath = path + "[" + i + "]";
            Object oldValue = i < before.size() ? before.get(i) : null;
            Object newValue = i < after.size() ? after.get(i) : null;
            if (oldValue == null && newValue == null) {
                continue;
            }
            if (oldValue == null || newValue == null) {
                addChange(changes, childPath, oldValue, newValue);
                continue;
            }
            diffValue(changes, childPath, oldValue, newValue);
        }
    }

    @SuppressWarnings("unchecked")
    private static void diffInventory(
            List<String> changes,
            Map<String, Map<String, Object>> before,
            Map<String, Map<String, Object>> after
    ) {
        if (before.size() != after.size()) {
            addChange(changes, "inventory.size", before.size(), after.size());
        }

        Set<String> uids = new LinkedHashSet<>();
        uids.addAll(before.keySet());
        uids.addAll(after.keySet());
        for (String uid : uids) {
            if (changes.size() >= MAX_CHANGES) {
                return;
            }
            Map<String, Object> oldItem = before.get(uid);
            Map<String, Object> newItem = after.get(uid);
            if (oldItem == null) {
                addChange(changes, "inventory[+" + uid + "]", null, itemSummary(newItem));
                continue;
            }
            if (newItem == null) {
                addChange(changes, "inventory[- " + uid + "]", itemSummary(oldItem), null);
                continue;
            }
            diffMap(changes, "inventory[" + uid + "]", oldItem, newItem);
        }
    }

    private static void addChange(List<String> changes, String path, Object before, Object after) {
        if (changes.size() >= MAX_CHANGES) {
            return;
        }
        String label = LABELS.getOrDefault(path, path);
        changes.add(label + ": " + format(before) + " → " + format(after));
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Map<String, Object>> inventoryMap(Object inventory) {
        if (!(inventory instanceof List<?> list)) {
            return Map.of();
        }
        Map<String, Map<String, Object>> byUid = new LinkedHashMap<>();
        for (Object item : list) {
            if (item instanceof Map<?, ?> raw) {
                Map<String, Object> map = (Map<String, Object>) raw;
                String uid = String.valueOf(map.getOrDefault("uid", ""));
                if (!uid.isBlank()) {
                    byUid.put(uid, map);
                }
            }
        }
        return byUid;
    }

    private static String itemSummary(Map<String, Object> item) {
        if (item == null) {
            return "空";
        }
        String name = String.valueOf(item.getOrDefault("name", item.getOrDefault("base_id", "?")));
        Object enhance = item.get("enhance_level");
        if (enhance == null) {
            return name;
        }
        return name + " +" + enhance;
    }

    private static boolean valuesEqual(Object before, Object after) {
        if (before == after) {
            return true;
        }
        if (before == null || after == null) {
            return false;
        }
        if (before instanceof Number beforeNumber && after instanceof Number afterNumber) {
            if (beforeNumber instanceof Double || beforeNumber instanceof Float
                    || afterNumber instanceof Double || afterNumber instanceof Float) {
                return Double.compare(beforeNumber.doubleValue(), afterNumber.doubleValue()) == 0;
            }
            return beforeNumber.longValue() == afterNumber.longValue();
        }
        if (before instanceof Boolean || after instanceof Boolean) {
            return Objects.equals(normalizeBoolean(before), normalizeBoolean(after));
        }
        if (before instanceof String beforeString && after instanceof String afterString) {
            return beforeString.equals(afterString);
        }
        return Objects.equals(before, after);
    }

    private static Boolean normalizeBoolean(Object value) {
        if (value instanceof Boolean bool) {
            return bool;
        }
        if (value instanceof Number number) {
            return number.intValue() != 0;
        }
        if (value instanceof String str) {
            return switch (str.trim().toLowerCase()) {
                case "true", "1", "yes", "是" -> true;
                case "false", "0", "no", "否" -> false;
                default -> null;
            };
        }
        return null;
    }

    private static String format(Object value) {
        if (value == null) {
            return "空";
        }
        if (value instanceof Boolean bool) {
            return bool ? "是" : "否";
        }
        if (value instanceof String str) {
            return str.isBlank() ? "空" : str;
        }
        if (value instanceof Number number) {
            if (number instanceof Double || number instanceof Float) {
                double d = number.doubleValue();
                if (d == Math.rint(d)) {
                    return String.valueOf((long) d);
                }
            }
            return String.valueOf(number);
        }
        if (value instanceof Map<?, ?> map) {
            return map.toString();
        }
        if (value instanceof List<?> list) {
            return "列表(" + list.size() + "项)";
        }
        return String.valueOf(value);
    }
}
