package com.lostmiracle.module.system;

import com.lostmiracle.module.system.entity.SystemSettingEntity;
import com.lostmiracle.module.system.mapper.SystemSettingMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class SystemSettingServiceTest {

    private SystemSettingMapper settingMapper;
    private SystemSettingService service;

    @BeforeEach
    void setUp() {
        settingMapper = mock(SystemSettingMapper.class);
        // default: maintenance off
        when(settingMapper.selectByKey("maintenance_mode")).thenReturn(setting("false"));
        when(settingMapper.selectByKey("maintenance_message")).thenReturn(setting("维护中"));
        service = new SystemSettingService(settingMapper);
    }

    @Test
    void isMaintenanceMode_defaultFalse() {
        assertFalse(service.isMaintenanceMode());
    }

    @Test
    void isMaintenanceMode_afterEnable() {
        service.setMaintenanceMode(true, null);
        assertTrue(service.isMaintenanceMode());
        verify(settingMapper).upsert("maintenance_mode", "true");
    }

    @Test
    void isMaintenanceMode_afterDisable() {
        service.setMaintenanceMode(true, null);
        service.setMaintenanceMode(false, null);
        assertFalse(service.isMaintenanceMode());
    }

    @Test
    void getMaintenanceMessage_default() {
        assertEquals("维护中", service.getMaintenanceMessage());
    }

    @Test
    void getMaintenanceMessage_afterUpdate() {
        service.setMaintenanceMode(false, "紧急维护");
        assertEquals("紧急维护", service.getMaintenanceMessage());
        verify(settingMapper).upsert("maintenance_message", "紧急维护");
    }

    @Test
    void getSettings_returnsBothKeys() {
        var settings = service.getSettings();
        assertTrue(settings.containsKey("maintenance_mode"));
        assertTrue(settings.containsKey("maintenance_message"));
    }

    @Test
    void clearCache_refreshesFromDb() {
        service.setMaintenanceMode(true, null);
        // simulate DB change
        when(settingMapper.selectByKey("maintenance_mode")).thenReturn(setting("false"));
        service.clearCache();
        assertFalse(service.isMaintenanceMode());
    }

    private SystemSettingEntity setting(String value) {
        SystemSettingEntity entity = new SystemSettingEntity();
        entity.setValue(value);
        return entity;
    }
}
