package com.lostmiracle.module.achievement.mapper;

import com.lostmiracle.module.achievement.entity.AchievementProgressEntity;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

@Mapper
public interface AchievementProgressMapper {

    AchievementProgressEntity selectByCharacterAndAchievement(
            @Param("characterId") long characterId,
            @Param("achievementId") String achievementId
    );

    List<AchievementProgressEntity> selectByCharacterId(@Param("characterId") long characterId);

    int insert(AchievementProgressEntity progress);

    int updateById(AchievementProgressEntity progress);

    int deleteByCharacterId(@Param("characterId") long characterId);
}
