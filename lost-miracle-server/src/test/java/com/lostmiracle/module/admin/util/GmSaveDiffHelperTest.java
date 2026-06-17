package com.lostmiracle.module.admin.util;

import org.junit.jupiter.api.Test;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertTrue;

class GmSaveDiffHelperTest {

    @Test
    void summarize_shouldReportPlayerGoldChange() {
        Map<String, Object> before = saveWithGold(0);
        Map<String, Object> after = saveWithGold(500);

        List<String> changes = GmSaveDiffHelper.summarize(before, after);

        assertTrue(changes.stream().anyMatch(line -> line.contains("金币") && line.contains("500")));
    }

    @Test
    void summarize_shouldReportBaseStatsChange() {
        Map<String, Object> before = saveWithBaseStat("atk", 10);
        Map<String, Object> after = saveWithBaseStat("atk", 99);

        List<String> changes = GmSaveDiffHelper.summarize(before, after);

        assertTrue(changes.stream().anyMatch(line -> line.contains("攻击") && line.contains("99")));
    }

    @Test
    void summarize_shouldReportInventoryItemChangeByUid() {
        Map<String, Object> before = saveWithInventoryItem("eq_1", 0);
        Map<String, Object> after = saveWithInventoryItem("eq_1", 5);

        List<String> changes = GmSaveDiffHelper.summarize(before, after);

        assertTrue(changes.stream().anyMatch(line -> line.contains("eq_1") && line.contains("enhance_level")));
    }

    private static Map<String, Object> saveWithGold(long gold) {
        Map<String, Object> save = baseSave();
        Map<String, Object> player = map(save.get("player"));
        player.put("gold", gold);
        return save;
    }

    private static Map<String, Object> saveWithBaseStat(String key, int value) {
        Map<String, Object> save = baseSave();
        Map<String, Object> player = map(save.get("player"));
        Map<String, Object> baseStats = map(player.get("base_stats"));
        baseStats.put(key, value);
        player.put("base_stats", baseStats);
        return save;
    }

    private static Map<String, Object> saveWithInventoryItem(String uid, int enhanceLevel) {
        Map<String, Object> save = baseSave();
        Map<String, Object> item = new LinkedHashMap<>();
        item.put("uid", uid);
        item.put("name", "测试剑");
        item.put("base_id", "sword_test");
        item.put("enhance_level", enhanceLevel);
        save.put("inventory", List.of(item));
        return save;
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> baseSave() {
        Map<String, Object> save = new LinkedHashMap<>();
        Map<String, Object> player = new LinkedHashMap<>();
        player.put("gold", 0L);
        player.put("level", 1);
        player.put("base_stats", new LinkedHashMap<>());
        player.put("primary_stats", Map.of("STR", 10, "AGI", 3, "INT", 3));
        save.put("player", player);
        save.put("equipment", new LinkedHashMap<>());
        save.put("inventory", List.of());
        save.put("world", Map.of("current_dungeon_id", "bone_crypt", "auto_battle", false));
        save.put("dungeon", Map.of("normal_kill_count", 0, "elite_kill_count", 0, "boss_kill_count", 0));
        return save;
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> map(Object value) {
        return (Map<String, Object>) value;
    }
}
