package com.lostmiracle.module.user.mapper;

import com.lostmiracle.module.user.entity.UserEntity;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface UserMapper {

    int insert(UserEntity user);

    UserEntity selectByUsername(@Param("username") String username);

    long countByUsername(@Param("username") String username);
}
