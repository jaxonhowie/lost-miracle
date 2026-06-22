package com.lostmiracle.module.admin;

import com.lostmiracle.common.ApiResponse;
import com.lostmiracle.security.AdminSecurityUtils;
import com.lostmiracle.security.GmPrincipal;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/admin/system")
public class AdminSystemController {

    private final AdminSystemService adminSystemService;

    public AdminSystemController(AdminSystemService adminSystemService) {
        this.adminSystemService = adminSystemService;
    }

    @GetMapping("/settings")
    public ApiResponse<Map<String, Object>> getSettings() {
        AdminSecurityUtils.requireRole(GmRole.viewer);
        return ApiResponse.ok(adminSystemService.getSettings());
    }

    @PostMapping("/maintenance")
    public ApiResponse<Void> toggleMaintenance(
            @RequestBody Map<String, Object> body,
            HttpServletRequest httpRequest
    ) {
        GmPrincipal gm = AdminSecurityUtils.requireRole(GmRole.super_);
        boolean enabled = Boolean.TRUE.equals(body.get("enabled"));
        String message = body.get("message") instanceof String s ? s : null;
        adminSystemService.toggleMaintenance(gm.gmAccountId(), enabled, message, clientIp(httpRequest));
        return ApiResponse.ok(null);
    }

    private String clientIp(HttpServletRequest request) {
        String forwarded = request.getHeader("X-Forwarded-For");
        if (forwarded != null && !forwarded.isBlank()) {
            return forwarded.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }
}
