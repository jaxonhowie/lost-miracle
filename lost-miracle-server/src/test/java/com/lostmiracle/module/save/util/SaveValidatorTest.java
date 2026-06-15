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
        Map<String, Object> save = new HashMap<>();
        save.put("player", Map.of("level", 1));
        save.put("inventory", new ArrayList<>());
        assertDoesNotThrow(() -> SaveValidator.validate(save));
    }

    @Test
    void validate_rejectsMissingPlayer() {
        Map<String, Object> save = new HashMap<>();
        save.put("inventory", new ArrayList<>());
        assertThrows(BusinessException.class, () -> SaveValidator.validate(save));
    }
}
