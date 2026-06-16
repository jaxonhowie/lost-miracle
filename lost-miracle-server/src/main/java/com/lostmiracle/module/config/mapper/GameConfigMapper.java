package com.lostmiracle.module.config.mapper;

import com.lostmiracle.module.config.entity.GameConfigEntity;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

@Mapper
public interface GameConfigMapper {

    long countAll();

    List<GameConfigEntity> selectAll();

    GameConfigEntity selectByKey(@Param("configKey") String configKey);

    int insert(GameConfigEntity entity);

    int updateDraft(@Param("configKey") String configKey, @Param("draftJson") String draftJson);

    int publishAll();

    int restoreDraftFromPublished(@Param("configKey") String configKey, @Param("publishedJson") String publishedJson);
}
