package com.lostmiracle.module.enhance;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.lostmiracle.module.config.GameConfigService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.HashMap;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class EnhanceRollEngineTest {

    private EnhanceRollEngine engine;

    @BeforeEach
    void setUp() {
        GameConfigService gameConfigService = mock(GameConfigService.class);
        when(gameConfigService.getPublishedMap(org.mockito.ArgumentMatchers.anyString())).thenReturn(Map.of());
        engine = new EnhanceRollEngine(new EnhanceRulesLoader(new ObjectMapper(), gameConfigService));
    }

    @Test
    void maxLevel_armor_isTen() {
        Map<String, Object> equipment = armor(9);
        assertEquals(10, engine.maxLevel(equipment));
    }

    @Test
    void maxLevel_jewelry_isThree() {
        Map<String, Object> equipment = jewelry(2);
        assertEquals(3, engine.maxLevel(equipment));
    }

    @Test
    void roll_atMaxLevel_fails() {
        Map<String, Object> equipment = armor(10);
        EnhanceRollEngine.RollResult result = engine.roll(equipment, false, 0);
        assertFalse(result.success());
        assertEquals(10, result.newLevel());
    }

    @Test
    void roll_plusZero_alwaysSucceedsWithFullRate() {
        Map<String, Object> equipment = armor(0);
        EnhanceRollEngine.RollResult result = engine.roll(equipment, false, 1.0);
        assertTrue(result.success());
        assertEquals(1, result.newLevel());
    }

    private Map<String, Object> armor(int level) {
        Map<String, Object> equipment = new HashMap<>();
        equipment.put("type", "armor");
        equipment.put("slot", "weapon");
        equipment.put("enhance_level", level);
        equipment.put("safe_enhance_until", 3);
        return equipment;
    }

    private Map<String, Object> jewelry(int level) {
        Map<String, Object> equipment = new HashMap<>();
        equipment.put("type", "jewelry");
        equipment.put("slot", "ring");
        equipment.put("enhance_level", level);
        return equipment;
    }
}
