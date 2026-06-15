package com.lostmiracle.module.character.mapper;

import com.lostmiracle.module.character.entity.CharacterEntity;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

@Mapper
public interface CharacterMapper {

    int insert(CharacterEntity character);

    CharacterEntity selectById(@Param("id") long id);

    List<CharacterEntity> selectByUserId(@Param("userId") long userId);

    long countByUserId(@Param("userId") long userId);

    int updateById(CharacterEntity character);

    int deleteById(@Param("id") long id);
}
