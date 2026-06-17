package com.lostmiracle.module.save;

import com.lostmiracle.common.BusinessException;
import com.lostmiracle.common.ErrorCode;
import com.lostmiracle.module.save.dto.UploadSaveRequest;
import com.lostmiracle.module.save.entity.CharacterSaveEntity;
import com.lostmiracle.module.save.mapper.CharacterSaveMapper;
import com.lostmiracle.support.IntegrationTestBase;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.util.HashMap;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class SaveServiceIntegrationTest extends IntegrationTestBase {

    @Autowired
    private SaveService saveService;

    @Autowired
    private CharacterSaveMapper characterSaveMapper;

    @Test
    void upload_withStaleVersion_shouldConflict() throws Exception {
        TestUser user = createUser("save_conflict");
        CharacterSaveEntity save = characterSaveMapper.selectById(user.characterId());
        Map<String, Object> saveMap = readSaveMap(save.getSaveJson());
        Map<String, Object> player = new HashMap<>((Map<String, Object>) saveMap.get("player"));
        player.put("gold", 999);
        saveMap.put("player", player);

        BusinessException ex = assertThrows(
                BusinessException.class,
                () -> saveService.upload(
                        user.userId(),
                        user.characterId(),
                        new UploadSaveRequest(0L, System.currentTimeMillis() / 1000, saveMap, false)
                )
        );
        assertEquals(ErrorCode.CONFLICT, ex.getCode());
    }

    @Test
    void updateWithVersion_failure_shouldConflict() throws Exception {
        TestUser user = createUser("save_cas");
        CharacterSaveEntity save = characterSaveMapper.selectById(user.characterId());
        long expectedVersion = save.getSaveVersion();
        Map<String, Object> saveMap = readSaveMap(save.getSaveJson());

        jdbcTemplate.update(
                "UPDATE character_save SET save_version = save_version + 1 WHERE character_id = ?",
                user.characterId()
        );

        BusinessException ex = assertThrows(
                BusinessException.class,
                () -> saveService.upload(
                        user.userId(),
                        user.characterId(),
                        new UploadSaveRequest(expectedVersion, System.currentTimeMillis() / 1000, saveMap, false)
                )
        );
        assertEquals(ErrorCode.CONFLICT, ex.getCode());
    }
}
