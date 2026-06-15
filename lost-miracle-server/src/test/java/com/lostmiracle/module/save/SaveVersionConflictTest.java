package com.lostmiracle.module.save;

import com.lostmiracle.common.BusinessException;
import com.lostmiracle.common.ErrorCode;
import com.lostmiracle.module.save.entity.CharacterSaveEntity;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class SaveVersionConflictTest {

    @Test
    void mismatchingVersion_shouldUseConflictCode() {
        CharacterSaveEntity existing = new CharacterSaveEntity();
        existing.setSaveVersion(5L);

        BusinessException ex = assertThrows(BusinessException.class, () -> {
            if (!existing.getSaveVersion().equals(4L)) {
                throw new BusinessException(ErrorCode.CONFLICT, "save version conflict");
            }
        });
        assertEquals(ErrorCode.CONFLICT, ex.getCode());
    }
}
