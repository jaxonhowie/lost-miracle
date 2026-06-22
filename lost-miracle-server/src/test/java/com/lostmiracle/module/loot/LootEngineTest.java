package com.lostmiracle.module.loot;

import com.lostmiracle.module.config.ConfigDefaults;
import com.lostmiracle.module.config.GameConfigService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.HashMap;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

class LootEngineTest {

    private GameDataCatalog catalog;
    private EquipmentGenerator equipmentGenerator;
    private GameConfigService configService;
    private LootEngine lootEngine;

    @BeforeEach
    void setUp() {
        catalog = mock(GameDataCatalog.class);
        equipmentGenerator = mock(EquipmentGenerator.class);
        configService = mock(GameConfigService.class);
        lootEngine = new LootEngine(catalog, equipmentGenerator, configService);

        // default: empty config (falls back to hardcoded)
        when(configService.getPublishedMap(anyString())).thenReturn(Map.of());
    }

    @Test
    void rollBattleRewards_usesExpPerLevelFromConfig() {
        Map<String, Object> expCfg = Map.of("exp_per_level", 50);
        when(configService.getPublishedMap(ConfigDefaults.LOOT_EXP_PER_LEVEL)).thenReturn(expCfg);
        when(catalog.getMonsterType("m1")).thenReturn("normal");
        when(catalog.getMonsterLevel("m1")).thenReturn(10);

        LootRollResult result = lootEngine.rollBattleRewards("bone_crypt", "m1");

        assertEquals(500, result.exp()); // 10 * 50
    }

    @Test
    void rollBattleRewards_fallsBackToDefaultExp() {
        when(catalog.getMonsterType("m1")).thenReturn("normal");
        when(catalog.getMonsterLevel("m1")).thenReturn(10);

        LootRollResult result = lootEngine.rollBattleRewards("bone_crypt", "m1");

        assertEquals(300, result.exp()); // 10 * 30
    }

    @Test
    void rollBattleRewards_usesEquipRateFromConfig() {
        Map<String, Object> equipCfg = new HashMap<>();
        equipCfg.put("boss", Map.of("rate", 1.0, "min", 5, "max", 5));
        when(configService.getPublishedMap(ConfigDefaults.LOOT_EQUIP_DROP)).thenReturn(equipCfg);
        when(catalog.getMonsterType("m1")).thenReturn("boss");
        when(catalog.getMonsterLevel("m1")).thenReturn(10);
        when(equipmentGenerator.generateEquipment("boss")).thenReturn(Map.of("id", "sword"));

        LootRollResult result = lootEngine.rollBattleRewards("bone_crypt", "m1");

        long equipCount = result.items().stream()
                .filter(i -> i.containsKey("id"))
                .count();
        assertEquals(5, equipCount);
    }

    @Test
    void rollBattleRewards_usesGoldRangeFromConfig() {
        Map<String, Object> goldCfg = new HashMap<>();
        goldCfg.put("normal", Map.of("min", 999, "max", 999));
        when(configService.getPublishedMap(ConfigDefaults.LOOT_GOLD_DROP)).thenReturn(goldCfg);
        when(catalog.getMonsterType("m1")).thenReturn("normal");
        when(catalog.getMonsterLevel("m1")).thenReturn(1);

        LootRollResult result = lootEngine.rollBattleRewards("bone_crypt", "m1");

        assertTrue(result.gold() >= 999);
    }

    @Test
    void rollBattleRewards_usesStoneRateFromConfig() {
        Map<String, Object> stoneCfg = new HashMap<>();
        stoneCfg.put("normal", Map.of("rate", 1.0, "min", 10, "max", 10));
        when(configService.getPublishedMap(ConfigDefaults.LOOT_STONE_DROP)).thenReturn(stoneCfg);
        when(catalog.getMonsterType("m1")).thenReturn("normal");
        when(catalog.getMonsterLevel("m1")).thenReturn(1);

        LootRollResult result = lootEngine.rollBattleRewards("bone_crypt", "m1");

        boolean hasStone = result.items().stream()
                .anyMatch(i -> "enhance_stone".equals(i.get("type")) && ((int) i.get("amount")) >= 10);
        assertTrue(hasStone);
    }

    @Test
    void rollBattleRewards_usesPotionRateFromConfig() {
        Map<String, Object> potionCfg = Map.of("rate", 0.0, "min", 1, "max", 5);
        when(configService.getPublishedMap(ConfigDefaults.LOOT_POTION_DROP)).thenReturn(potionCfg);
        when(catalog.getMonsterType("m1")).thenReturn("normal");
        when(catalog.getMonsterLevel("m1")).thenReturn(1);

        // run multiple times — with rate=0, no potions should appear
        boolean anyPotion = false;
        for (int i = 0; i < 50; i++) {
            LootRollResult result = lootEngine.rollBattleRewards("bone_crypt", "m1");
            if (result.items().stream().anyMatch(item -> "health_potion".equals(item.get("type")))) {
                anyPotion = true;
                break;
            }
        }
        assertFalse(anyPotion, "potion rate=0 should yield no potions");
    }

    @Test
    void rollBattleRewards_fallsBackWhenConfigEmpty() {
        // all configs empty — should use hardcoded defaults
        when(catalog.getMonsterType("m1")).thenReturn("normal");
        when(catalog.getMonsterLevel("m1")).thenReturn(1);

        LootRollResult result = lootEngine.rollBattleRewards("bone_crypt", "m1");

        assertNotNull(result);
        assertTrue(result.gold() >= 10);
    }
}
