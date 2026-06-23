package com.lostmiracle.module.save.util;

import com.lostmiracle.common.BusinessException;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

class SaveValidatorTest {

    @Test
    void validate_acceptsMinimalSave() {
        Map<String, Object> save = validSave(5, 100);
        assertDoesNotThrow(() -> SaveValidator.validate(save));
    }

    @Test
    void validate_rejectsMissingPlayer() {
        Map<String, Object> save = new HashMap<>();
        save.put("inventory", new ArrayList<>());
        assertThrows(BusinessException.class, () -> SaveValidator.validate(save));
    }

    @Test
    void validate_rejectsInvalidLevel() {
        assertThrows(BusinessException.class, () -> SaveValidator.validate(validSave(0, 0)));
        assertThrows(BusinessException.class, () -> SaveValidator.validate(validSave(101, 0)));
    }

    @Test
    void validate_rejectsInvalidExp() {
        assertThrows(BusinessException.class, () -> SaveValidator.validate(validSave(5, 1250)));
        assertThrows(BusinessException.class, () -> SaveValidator.validate(validSave(5, -1)));
    }

    @Test
    void validate_rejectsInvalidGold() {
        Map<String, Object> negativeGold = validSave(1, 0);
        ((Map<String, Object>) negativeGold.get("player")).put("gold", -1);
        assertThrows(BusinessException.class, () -> SaveValidator.validate(negativeGold));

        Map<String, Object> tooMuchGold = validSave(1, 0);
        ((Map<String, Object>) tooMuchGold.get("player")).put("gold", 10_000_001L);
        assertThrows(BusinessException.class, () -> SaveValidator.validate(tooMuchGold));
    }

    @Test
    void validate_rejectsInvalidEnhanceStone() {
        Map<String, Object> save = validSave(1, 0);
        ((Map<String, Object>) save.get("player")).put("enhance_stone", 100_000);
        assertThrows(BusinessException.class, () -> SaveValidator.validate(save));
    }

    @Test
    void validate_rejectsInventoryItemWithoutIdOrUid() {
        Map<String, Object> save = validSave(1, 0);
        ArrayList<Map<String, Object>> inventory = new ArrayList<>();
        Map<String, Object> badItem = new HashMap<>();
        badItem.put("name", "no_identifier");
        inventory.add(badItem);
        save.put("inventory", inventory);
        assertThrows(BusinessException.class, () -> SaveValidator.validate(save));
    }

    @Test
    void validate_acceptsInventoryItemWithUid() {
        Map<String, Object> save = validSave(1, 0);
        ArrayList<Map<String, Object>> inventory = new ArrayList<>();
        Map<String, Object> item = new HashMap<>();
        item.put("uid", "eq_1");
        item.put("base_id", "vine_wood_sword");
        item.put("enhance_level", 0);
        inventory.add(item);
        save.put("inventory", inventory);
        assertDoesNotThrow(() -> SaveValidator.validate(save));
    }

    @Test
    void validate_acceptsInventoryItemWithIdOnly() {
        Map<String, Object> save = validSave(1, 0);
        ArrayList<Map<String, Object>> inventory = new ArrayList<>();
        Map<String, Object> item = new HashMap<>();
        item.put("id", "vine_wood_sword");
        inventory.add(item);
        save.put("inventory", inventory);
        assertDoesNotThrow(() -> SaveValidator.validate(save));
    }

    @Test
    void validate_acceptsInventoryItemWithBothIdAndUid() {
        Map<String, Object> save = validSave(1, 0);
        ArrayList<Map<String, Object>> inventory = new ArrayList<>();
        Map<String, Object> item = new HashMap<>();
        item.put("id", "vine_wood_sword");
        item.put("uid", "eq_1");
        inventory.add(item);
        save.put("inventory", inventory);
        assertDoesNotThrow(() -> SaveValidator.validate(save));
    }

    @Test
    void validate_rejectsInventoryItemWithBlankIdAndEmptyUid() {
        Map<String, Object> save = validSave(1, 0);
        ArrayList<Map<String, Object>> inventory = new ArrayList<>();
        Map<String, Object> item = new HashMap<>();
        item.put("id", "   ");
        item.put("uid", "");
        inventory.add(item);
        save.put("inventory", inventory);
        assertThrows(BusinessException.class, () -> SaveValidator.validate(save));
    }

    @Test
    void validate_rejectsInventoryItemWithEmptyIdAndBlankUid() {
        Map<String, Object> save = validSave(1, 0);
        ArrayList<Map<String, Object>> inventory = new ArrayList<>();
        Map<String, Object> item = new HashMap<>();
        item.put("id", "");
        item.put("uid", "   ");
        inventory.add(item);
        save.put("inventory", inventory);
        assertThrows(BusinessException.class, () -> SaveValidator.validate(save));
    }

    @Test
    void validate_rejectsNonMapInventoryItem() {
        Map<String, Object> save = validSave(1, 0);
        ArrayList<Object> inventory = new ArrayList<>();
        inventory.add("not_a_map");
        save.put("inventory", inventory);
        assertThrows(BusinessException.class, () -> SaveValidator.validate(save));
    }

    @Test
    void validate_rejectsInventoryOverMaxSize() {
        Map<String, Object> save = validSave(1, 0);
        ArrayList<Map<String, Object>> inventory = new ArrayList<>();
        for (int i = 0; i < 201; i++) {
            Map<String, Object> item = new HashMap<>();
            item.put("id", "item_" + i);
            inventory.add(item);
        }
        save.put("inventory", inventory);
        assertThrows(BusinessException.class, () -> SaveValidator.validate(save));
    }

    @Test
    void validate_acceptsInventoryAtMaxSize() {
        Map<String, Object> save = validSave(1, 0);
        ArrayList<Map<String, Object>> inventory = new ArrayList<>();
        for (int i = 0; i < 200; i++) {
            Map<String, Object> item = new HashMap<>();
            item.put("id", "item_" + i);
            inventory.add(item);
        }
        save.put("inventory", inventory);
        assertDoesNotThrow(() -> SaveValidator.validate(save));
    }

    @Test
    void validate_acceptsEnhanceLevelZero() {
        Map<String, Object> save = validSave(1, 0);
        ArrayList<Map<String, Object>> inventory = new ArrayList<>();
        Map<String, Object> item = new HashMap<>();
        item.put("id", "vine_wood_sword");
        item.put("enhance_level", 0);
        inventory.add(item);
        save.put("inventory", inventory);
        assertDoesNotThrow(() -> SaveValidator.validate(save));
    }

    @Test
    void validate_rejectsNegativeEnhanceLevel() {
        Map<String, Object> save = validSave(1, 0);
        ArrayList<Map<String, Object>> inventory = new ArrayList<>();
        Map<String, Object> item = new HashMap<>();
        item.put("id", "vine_wood_sword");
        item.put("enhance_level", -1);
        inventory.add(item);
        save.put("inventory", inventory);
        assertThrows(BusinessException.class, () -> SaveValidator.validate(save));
    }

    @Test
    void validate_acceptsNullEquipmentField() {
        Map<String, Object> save = validSave(1, 0);
        // equipment not present — should be fine
        assertDoesNotThrow(() -> SaveValidator.validate(save));
    }

    @Test
    void validate_rejectsNonMapEquipment() {
        Map<String, Object> save = validSave(1, 0);
        save.put("equipment", "not_a_map");
        assertThrows(BusinessException.class, () -> SaveValidator.validate(save));
    }

    @Test
    void validate_acceptsAllValidEquipmentSlots() {
        Map<String, Object> save = validSave(1, 0);
        Map<String, Object> equipment = new HashMap<>();
        equipment.put("weapon", "vine_wood_sword");
        equipment.put("helmet", "vine_helm");
        equipment.put("armor", "vine_armor");
        equipment.put("legs", "vine_legs");
        equipment.put("gloves", "vine_gloves");
        equipment.put("ring_left", "swamp_ring_1");
        equipment.put("ring_right", "swamp_ring_2");
        equipment.put("necklace", "frozen_necklace_1");
        save.put("equipment", equipment);
        assertDoesNotThrow(() -> SaveValidator.validate(save));
    }

    @Test
    void validate_rejectsEnhanceLevelOverMax() {
        Map<String, Object> save = validSave(1, 0);
        ArrayList<Map<String, Object>> inventory = new ArrayList<>();
        Map<String, Object> item = new HashMap<>();
        item.put("id", "vine_wood_sword");
        item.put("enhance_level", 11);
        inventory.add(item);
        save.put("inventory", inventory);
        assertThrows(BusinessException.class, () -> SaveValidator.validate(save));
    }

    @Test
    void validate_acceptsValidEnhanceLevel() {
        Map<String, Object> save = validSave(1, 0);
        ArrayList<Map<String, Object>> inventory = new ArrayList<>();
        Map<String, Object> item = new HashMap<>();
        item.put("id", "vine_wood_sword");
        item.put("enhance_level", 10);
        inventory.add(item);
        save.put("inventory", inventory);
        assertDoesNotThrow(() -> SaveValidator.validate(save));
    }

    @Test
    void validate_rejectsInvalidEquipmentSlot() {
        Map<String, Object> save = validSave(1, 0);
        Map<String, Object> equipment = new HashMap<>();
        equipment.put("invalid_slot", "vine_wood_sword");
        save.put("equipment", equipment);
        assertThrows(BusinessException.class, () -> SaveValidator.validate(save));
    }

    @Test
    void validate_acceptsValidEquipmentSlots() {
        Map<String, Object> save = validSave(1, 0);
        Map<String, Object> equipment = new HashMap<>();
        equipment.put("weapon", "vine_wood_sword");
        equipment.put("ring_left", "swamp_ring_1");
        equipment.put("necklace", "frozen_necklace_1");
        save.put("equipment", equipment);
        assertDoesNotThrow(() -> SaveValidator.validate(save));
    }

    @Test
    void validate_rejectsInvalidPlayerClass() {
        Map<String, Object> save = validSave(1, 0);
        ((Map<String, Object>) save.get("player")).put("class", "hacker");
        assertThrows(BusinessException.class, () -> SaveValidator.validate(save));
    }

    @Test
    void validate_acceptsValidPlayerClass() {
        Map<String, Object> save = validSave(1, 0);
        ((Map<String, Object>) save.get("player")).put("class", "warrior");
        assertDoesNotThrow(() -> SaveValidator.validate(save));
    }

    @Test
    void validate_rejectsNegativePrimaryStat() {
        Map<String, Object> save = validSave(1, 0);
        Map<String, Object> stats = new HashMap<>();
        stats.put("STR", -1);
        stats.put("AGI", 3);
        stats.put("INT", 3);
        ((Map<String, Object>) save.get("player")).put("primary_stats", stats);
        assertThrows(BusinessException.class, () -> SaveValidator.validate(save));
    }

    @Test
    void validate_rejectsPrimaryStatOverMax() {
        Map<String, Object> save = validSave(1, 0);
        Map<String, Object> stats = new HashMap<>();
        stats.put("STR", 10_000);
        ((Map<String, Object>) save.get("player")).put("primary_stats", stats);
        assertThrows(BusinessException.class, () -> SaveValidator.validate(save));
    }

    @Test
    void validate_rejectsAltarBuffsTooLarge() {
        Map<String, Object> save = validSave(1, 0);
        ArrayList<Object> buffs = new ArrayList<>();
        for (int i = 0; i < 11; i++) {
            buffs.add(Map.of("stat", "STR", "value", 5, "battles_remaining", 3));
        }
        ((Map<String, Object>) save.get("player")).put("altar_buffs", buffs);
        assertThrows(BusinessException.class, () -> SaveValidator.validate(save));
    }

    @Test
    void validate_acceptsValidExtendedFields() {
        Map<String, Object> save = validSave(1, 0);
        Map<String, Object> player = (Map<String, Object>) save.get("player");
        player.put("class", "warrior");
        player.put("primary_stats", Map.of("STR", 10, "AGI", 3, "INT", 3));
        player.put("base_stats", Map.of("max_hp", 150, "atk", 13));
        player.put("altar_buffs", new ArrayList<>());
        player.put("battle_roar_remaining", 120.0);
        player.put("battle_roar_atk_spd_percent", 20.0);
        Map<String, Object> dungeon = new HashMap<>();
        dungeon.put("normal_kill_count", 50);
        dungeon.put("elite_kill_count", 10);
        dungeon.put("boss_kill_count", 3);
        save.put("dungeon", dungeon);
        save.put("world", Map.of("current_dungeon_id", "bone_crypt", "auto_battle", true));
        assertDoesNotThrow(() -> SaveValidator.validate(save));
    }

    @Test
    void validate_rejectsNegativeBattleRoar() {
        Map<String, Object> save = validSave(1, 0);
        ((Map<String, Object>) save.get("player")).put("battle_roar_remaining", -1.0);
        assertThrows(BusinessException.class, () -> SaveValidator.validate(save));
    }

    @Test
    void validate_rejectsNonMapDungeon() {
        Map<String, Object> save = validSave(1, 0);
        save.put("dungeon", "not_a_map");
        assertThrows(BusinessException.class, () -> SaveValidator.validate(save));
    }

    private Map<String, Object> validSave(int level, int exp) {
        Map<String, Object> player = new HashMap<>();
        player.put("level", level);
        player.put("exp", exp);
        player.put("gold", 500);
        player.put("enhance_stone", 5);
        Map<String, Object> save = new HashMap<>();
        save.put("player", player);
        save.put("inventory", new ArrayList<>());
        return save;
    }
}
