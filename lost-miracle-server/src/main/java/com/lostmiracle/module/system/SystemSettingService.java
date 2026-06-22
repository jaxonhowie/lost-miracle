package com.lostmiracle.module.system;

import com.lostmiracle.module.system.entity.SystemSettingEntity;
import com.lostmiracle.module.system.mapper.SystemSettingMapper;
import org.springframework.stereotype.Service;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class SystemSettingService {

    private static final String KEY_MAINTENANCE_MODE = "maintenance_mode";
    private static final String KEY_MAINTENANCE_MESSAGE = "maintenance_message";
    private static final String DEFAULT_MESSAGE = "服务器维护中，请稍后再试";

    private final SystemSettingMapper settingMapper;
    private final Map<String, String> cache = new ConcurrentHashMap<>();

    public SystemSettingService(SystemSettingMapper settingMapper) {
        this.settingMapper = settingMapper;
        // warm cache on startup
        cache.put(KEY_MAINTENANCE_MODE, getRaw(KEY_MAINTENANCE_MODE));
        cache.put(KEY_MAINTENANCE_MESSAGE, getRaw(KEY_MAINTENANCE_MESSAGE));
    }

    public boolean isMaintenanceMode() {
        return "true".equals(cache.getOrDefault(KEY_MAINTENANCE_MODE, "false"));
    }

    public String getMaintenanceMessage() {
        return cache.getOrDefault(KEY_MAINTENANCE_MESSAGE, DEFAULT_MESSAGE);
    }

    public Map<String, Object> getSettings() {
        return Map.of(
                KEY_MAINTENANCE_MODE, isMaintenanceMode(),
                KEY_MAINTENANCE_MESSAGE, getMaintenanceMessage()
        );
    }

    public void setMaintenanceMode(boolean enabled, String message) {
        settingMapper.upsert(KEY_MAINTENANCE_MODE, String.valueOf(enabled));
        cache.put(KEY_MAINTENANCE_MODE, String.valueOf(enabled));
        if (message != null && !message.isBlank()) {
            settingMapper.upsert(KEY_MAINTENANCE_MESSAGE, message);
            cache.put(KEY_MAINTENANCE_MESSAGE, message);
        }
    }

    public void clearCache() {
        cache.put(KEY_MAINTENANCE_MODE, getRaw(KEY_MAINTENANCE_MODE));
        cache.put(KEY_MAINTENANCE_MESSAGE, getRaw(KEY_MAINTENANCE_MESSAGE));
    }

    private String getRaw(String key) {
        SystemSettingEntity entity = settingMapper.selectByKey(key);
        return entity != null ? entity.getValue() : "";
    }
}
