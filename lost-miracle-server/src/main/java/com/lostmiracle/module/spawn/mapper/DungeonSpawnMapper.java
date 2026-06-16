package com.lostmiracle.module.spawn.mapper;

import com.lostmiracle.module.spawn.entity.DungeonSpawnSlotEntity;
import org.apache.ibatis.annotations.Param;

import java.util.List;

public interface DungeonSpawnMapper {

    int insert(DungeonSpawnSlotEntity slot);

    long countByDungeonId(@Param("dungeonId") String dungeonId);

    List<DungeonSpawnSlotEntity> selectByDungeonId(@Param("dungeonId") String dungeonId);

    List<DungeonSpawnSlotEntity> selectAvailableByDungeonAndType(
            @Param("dungeonId") String dungeonId,
            @Param("spawnType") String spawnType,
            @Param("now") long now
    );

    DungeonSpawnSlotEntity selectById(@Param("id") long id);

    int tryEngage(
            @Param("id") long id,
            @Param("characterId") long characterId,
            @Param("now") long now
    );

    int releaseEngagement(
            @Param("id") long id,
            @Param("characterId") long characterId
    );

    int applyDefeatCooldown(
            @Param("id") long id,
            @Param("characterId") long characterId,
            @Param("respawnAt") long respawnAt
    );

    int adminResetSlot(@Param("id") long id);

    int adminResetDungeon(@Param("dungeonId") String dungeonId);
}
