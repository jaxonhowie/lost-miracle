package com.lostmiracle.module.config.mapper;

import com.lostmiracle.module.config.entity.GameConfigPublishEntity;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

@Mapper
public interface GameConfigPublishMapper {

    int insert(GameConfigPublishEntity entity);

    List<GameConfigPublishEntity> selectRecent(@Param("limit") int limit);

    GameConfigPublishEntity selectById(@Param("id") long id);

    Long selectCurrentVersion();

    int updateCurrentVersion(@Param("version") long version);
}
