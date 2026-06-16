package com.lostmiracle.module.admin.mapper;

import com.lostmiracle.module.admin.entity.GmAccountEntity;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface GmAccountMapper {

    int insert(GmAccountEntity account);

    GmAccountEntity selectByUsername(@Param("username") String username);

    GmAccountEntity selectById(@Param("id") long id);

    long countAll();
}
