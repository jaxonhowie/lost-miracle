package com.lostmiracle.module.enhance;

import com.lostmiracle.module.enhance.dto.EnhanceRollRequest;
import com.lostmiracle.module.enhance.dto.EnhanceRollResponse;
import com.lostmiracle.module.save.entity.CharacterSaveEntity;
import com.lostmiracle.module.save.mapper.CharacterSaveMapper;
import com.lostmiracle.support.IntegrationTestBase;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class EnhanceServiceIntegrationTest extends IntegrationTestBase {

    @Autowired
    private EnhanceService enhanceService;

    @Autowired
    private CharacterSaveMapper characterSaveMapper;

    @Test
    void roll_shouldPersistNewSaveVersion() throws Exception {
        TestUser user = createUser("enhance_roll");
        CharacterSaveEntity save = characterSaveMapper.selectById(user.characterId());
        Map<String, Object> saveMap = readSaveMap(save.getSaveJson());

        @SuppressWarnings("unchecked")
        Map<String, Object> player = (Map<String, Object>) saveMap.get("player");
        player.put("enhance_stone", 5);

        Map<String, Object> equipment = new HashMap<>();
        equipment.put("uid", "eq_test_1");
        equipment.put("base_id", "vine_wood_sword");
        equipment.put("name", "紫藤木剑");
        equipment.put("slot", "weapon");
        equipment.put("type", "weapon");
        equipment.put("enhance_level", 0);
        equipment.put("base_stats", Map.of("atk", 14));
        equipment.put("effects", Map.of());
        equipment.put("is_blessed", false);
        equipment.put("quality", "normal");

        @SuppressWarnings("unchecked")
        List<Map<String, Object>> inventory = new ArrayList<>((List<Map<String, Object>>) saveMap.get("inventory"));
        inventory.add(equipment);
        saveMap.put("inventory", inventory);

        long versionBeforeRoll = save.getSaveVersion();
        save.setSaveJson(objectMapper.writeValueAsString(saveMap));
        assertEquals(1, characterSaveMapper.updateWithVersion(save, versionBeforeRoll));

        CharacterSaveEntity current = characterSaveMapper.selectById(user.characterId());
        EnhanceRollResponse response = enhanceService.roll(
                user.userId(),
                user.characterId(),
                new EnhanceRollRequest("eq_test_1", false, current.getSaveVersion())
        );

        assertTrue(response.saveVersion() > current.getSaveVersion());
        assertTrue(response.save().containsKey("inventory"));
    }
}
