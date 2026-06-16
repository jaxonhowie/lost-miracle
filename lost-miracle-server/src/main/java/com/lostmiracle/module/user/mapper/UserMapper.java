package com.lostmiracle.module.user.mapper;

import com.lostmiracle.module.user.entity.UserEntity;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

@Mapper
public interface UserMapper {

    int insert(UserEntity user);

    UserEntity selectByUsername(@Param("username") String username);

    UserEntity selectById(@Param("id") long id);

    long countByUsername(@Param("username") String username);

    List<UserEntity> search(@Param("query") String query, @Param("limit") int limit, @Param("offset") int offset);

    long countSearch(@Param("query") String query);

    int updateStatus(@Param("id") long id, @Param("status") int status);
}
