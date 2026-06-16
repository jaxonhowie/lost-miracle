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
