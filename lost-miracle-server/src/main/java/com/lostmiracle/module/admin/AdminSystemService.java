package com.lostmiracle.module.admin;

import com.lostmiracle.module.system.SystemSettingService;
import org.springframework.stereotype.Service;

import java.util.Map;

@Service
public class AdminSystemService {

    private final SystemSettingService systemSettingService;
    private final GmAuditService gmAuditService;

    public AdminSystemService(SystemSettingService systemSettingService, GmAuditService gmAuditService) {
        this.systemSettingService = systemSettingService;
        this.gmAuditService = gmAuditService;
    }

    public Map<String, Object> getSettings() {
        return systemSettingService.getSettings();
    }

    public void toggleMaintenance(long gmAccountId, boolean enabled, String message, String ip) {
        systemSettingService.setMaintenanceMode(enabled, message);
        gmAuditService.log(
                gmAccountId, "MAINTENANCE_TOGGLE", "system", "maintenance",
                Map.of("enabled", enabled, "message", message != null ? message : ""),
                ip
        );
    }
}
