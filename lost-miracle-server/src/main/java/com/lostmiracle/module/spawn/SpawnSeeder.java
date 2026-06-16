package com.lostmiracle.module.spawn;

import com.lostmiracle.module.spawn.entity.DungeonSpawnSlotEntity;
import com.lostmiracle.module.spawn.mapper.DungeonSpawnMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

import java.util.List;

@Component
public class SpawnSeeder {

    private static final Logger log = LoggerFactory.getLogger(SpawnSeeder.class);

    private final DungeonSpawnMapper dungeonSpawnMapper;
    private final MonsterCatalog monsterCatalog;

    public SpawnSeeder(DungeonSpawnMapper dungeonSpawnMapper, MonsterCatalog monsterCatalog) {
        this.dungeonSpawnMapper = dungeonSpawnMapper;
        this.monsterCatalog = monsterCatalog;
    }

    @EventListener(ApplicationReadyEvent.class)
    public void seedMissingDungeons() {
        for (String dungeonId : monsterCatalog.listDungeonIds()) {
            if (dungeonSpawnMapper.countByDungeonId(dungeonId) > 0) {
                continue;
            }
            seedDungeon(dungeonId);
            log.info("seeded dungeon spawn slots dungeonId={}", dungeonId);
        }
    }

    private void seedDungeon(String dungeonId) {
        for (String monsterId : monsterCatalog.listMonsterIds(dungeonId, SpawnConstants.SPAWN_NORMAL)) {
            for (int slot = 0; slot < SpawnConstants.NORMAL_SLOTS_PER_MONSTER; slot++) {
                insertSlot(dungeonId, SpawnConstants.SPAWN_NORMAL, monsterId, slot);
            }
        }
        insertSlot(dungeonId, SpawnConstants.SPAWN_ELITE, SpawnConstants.ELITE_POOL, 0);
        insertSlot(dungeonId, SpawnConstants.SPAWN_BOSS, monsterCatalog.getBossId(dungeonId), 0);
    }

    private void insertSlot(String dungeonId, String spawnType, String monsterId, int slotIndex) {
        DungeonSpawnSlotEntity slot = new DungeonSpawnSlotEntity();
        slot.setDungeonId(dungeonId);
        slot.setSpawnType(spawnType);
        slot.setMonsterId(monsterId);
        slot.setSlotIndex(slotIndex);
        slot.setRespawnAt(0L);
        slot.setEngagedCharacterId(null);
        dungeonSpawnMapper.insert(slot);
    }
}
