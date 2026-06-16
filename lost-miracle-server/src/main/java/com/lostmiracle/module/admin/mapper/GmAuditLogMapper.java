package com.lostmiracle.module.admin.mapper;

import com.lostmiracle.module.admin.entity.GmAuditLogEntity;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

@Mapper
public interface GmAuditLogMapper {

    int insert(GmAuditLogEntity log);

    List<GmAuditLogEntity> selectRecent(
            @Param("limit") int limit,
            @Param("offset") int offset
    );
}
