package com.lostmiracle.module.save.mapper;

import com.lostmiracle.module.save.entity.CharacterSaveEntity;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface CharacterSaveMapper {

    CharacterSaveEntity selectById(@Param("characterId") long characterId);

    int insert(CharacterSaveEntity save);

    int updateById(CharacterSaveEntity save);

    int deleteById(@Param("characterId") long characterId);
}
