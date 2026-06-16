package com.lostmiracle.module.admin;

import com.lostmiracle.common.ApiResponse;
import com.lostmiracle.module.admin.dto.GmSpawnResetResponse;
import com.lostmiracle.module.spawn.dto.DungeonSpawnStateResponse;
import com.lostmiracle.security.AdminSecurityUtils;
import com.lostmiracle.security.GmPrincipal;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/admin")
public class AdminSpawnController {

    private final AdminSpawnService adminSpawnService;

    public AdminSpawnController(AdminSpawnService adminSpawnService) {
        this.adminSpawnService = adminSpawnService;
    }

    @GetMapping("/dungeons/{dungeonId}/spawns")
    public ApiResponse<DungeonSpawnStateResponse> getSpawns(@PathVariable String dungeonId) {
        AdminSecurityUtils.requireRole(GmRole.viewer);
        return ApiResponse.ok(adminSpawnService.getState(dungeonId));
    }

    @PostMapping("/spawns/{slotId}/reset")
    public ApiResponse<Void> resetSlot(@PathVariable long slotId, HttpServletRequest httpRequest) {
        GmPrincipal gm = AdminSecurityUtils.requireRole(GmRole.operator);
        adminSpawnService.resetSlot(gm, slotId, clientIp(httpRequest));
        return ApiResponse.ok();
    }

    @PostMapping("/dungeons/{dungeonId}/spawns/reset-all")
    public ApiResponse<GmSpawnResetResponse> resetDungeon(
            @PathVariable String dungeonId,
            HttpServletRequest httpRequest
    ) {
        GmPrincipal gm = AdminSecurityUtils.requireRole(GmRole.operator);
        return ApiResponse.ok(adminSpawnService.resetDungeon(gm, dungeonId, clientIp(httpRequest)));
    }

    private String clientIp(HttpServletRequest request) {
        String forwarded = request.getHeader("X-Forwarded-For");
        if (forwarded != null && !forwarded.isBlank()) {
            return forwarded.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }
}
