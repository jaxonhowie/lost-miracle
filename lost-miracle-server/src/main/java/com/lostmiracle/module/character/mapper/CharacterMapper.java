package com.lostmiracle.module.character.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.lostmiracle.module.character.entity.CharacterEntity;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface CharacterMapper extends BaseMapper<CharacterEntity> {
}
