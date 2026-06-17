package com.lostmiracle.module.save.mapper;

import com.lostmiracle.module.save.entity.CharacterSaveEntity;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface CharacterSaveMapper {

    CharacterSaveEntity selectById(@Param("characterId") long characterId);

    int insert(CharacterSaveEntity save);

    /**
     * 乐观锁更新：仅当 DB 中 save_version 仍等于 expectedVersion 时才写入，返回受影响行数。
     * 返回 0 表示版本已被并发修改，调用方应按冲突处理。
     */
    int updateWithVersion(@Param("save") CharacterSaveEntity save, @Param("expectedVersion") long expectedVersion);

    int deleteById(@Param("characterId") long characterId);
}
