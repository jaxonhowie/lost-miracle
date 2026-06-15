package com.lostmiracle.module.mail.mapper;

import com.lostmiracle.module.mail.entity.MailEntity;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.time.LocalDateTime;
import java.util.List;

@Mapper
public interface MailMapper {

    MailEntity selectById(@Param("id") long id);

    List<MailEntity> selectByCharacterId(@Param("characterId") long characterId);

    int updateClaimed(@Param("id") long id, @Param("claimed") int claimed, @Param("claimedAt") LocalDateTime claimedAt);

    int deleteByCharacterId(@Param("characterId") long characterId);
}
