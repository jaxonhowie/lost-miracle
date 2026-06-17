package com.lostmiracle.module.spawn;

import com.lostmiracle.module.save.entity.CharacterSaveEntity;
import com.lostmiracle.module.save.mapper.CharacterSaveMapper;
import com.lostmiracle.module.spawn.dto.SpawnEncounterResponse;
import com.lostmiracle.module.spawn.dto.SpawnSettleRequest;
import com.lostmiracle.module.spawn.dto.SpawnSettleResponse;
import com.lostmiracle.support.IntegrationTestBase;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SpawnSettleIntegrationTest extends IntegrationTestBase {

    private static final String DUNGEON_ID = "bone_crypt";

    @Autowired
    private SpawnService spawnService;

    @Autowired
    private SpawnSettleService spawnSettleService;

    @Autowired
    private CharacterSaveMapper characterSaveMapper;

    @Test
    void settle_shouldApplyRewardsAndBumpSaveVersion() {
        TestUser user = createUser("spawn_settle");
        SpawnEncounterResponse encounter = spawnService.encounter(
                user.characterId(),
                DUNGEON_ID,
                SpawnConstants.SPAWN_NORMAL
        );

        CharacterSaveEntity saveBefore = characterSaveMapper.selectById(user.characterId());
        SpawnSettleResponse response = spawnSettleService.settle(
                user.userId(),
                user.characterId(),
                DUNGEON_ID,
                encounter.slotId(),
                new SpawnSettleRequest(saveBefore.getSaveVersion(), encounter.monsterId())
        );

        assertTrue(response.saveVersion() > saveBefore.getSaveVersion());
        assertTrue(response.exp() > 0);
        assertTrue(response.gold() >= 0);

        CharacterSaveEntity saveAfter = characterSaveMapper.selectById(user.characterId());
        assertEquals(response.saveVersion(), saveAfter.getSaveVersion());
    }
}
