package com.lostmiracle.module.system.mapper;

import com.lostmiracle.module.system.entity.SystemSettingEntity;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface SystemSettingMapper {

    SystemSettingEntity selectByKey(@Param("key") String key);

    int upsert(@Param("key") String key, @Param("value") String value);
}
