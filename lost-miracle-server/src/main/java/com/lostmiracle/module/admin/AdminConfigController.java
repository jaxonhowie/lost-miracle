package com.lostmiracle.module.admin;

import com.lostmiracle.common.ApiResponse;
import com.lostmiracle.module.config.dto.ConfigItemResponse;
import com.lostmiracle.module.config.dto.ConfigListResponse;
import com.lostmiracle.module.config.dto.ConfigPublishHistoryResponse;
import com.lostmiracle.module.config.dto.ConfigPublishRequest;
import com.lostmiracle.module.config.dto.ConfigPublishResultResponse;
import com.lostmiracle.module.config.dto.ConfigUpdateRequest;
import com.lostmiracle.security.AdminSecurityUtils;
import com.lostmiracle.security.GmPrincipal;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/admin/config")
public class AdminConfigController {

    private final AdminConfigService adminConfigService;

    public AdminConfigController(AdminConfigService adminConfigService) {
        this.adminConfigService = adminConfigService;
    }

    @GetMapping
    public ApiResponse<ConfigListResponse> list() {
        AdminSecurityUtils.requireRole(GmRole.viewer);
        return ApiResponse.ok(adminConfigService.list());
    }

    @GetMapping("/{configKey:.+}")
    public ApiResponse<ConfigItemResponse> get(@PathVariable String configKey) {
        AdminSecurityUtils.requireRole(GmRole.viewer);
        return ApiResponse.ok(adminConfigService.get(configKey));
    }

    @PutMapping("/{configKey:.+}")
    public ApiResponse<ConfigItemResponse> updateDraft(
            @PathVariable String configKey,
            @Valid @RequestBody ConfigUpdateRequest request,
            HttpServletRequest httpRequest
    ) {
        GmPrincipal gm = AdminSecurityUtils.requireRole(GmRole.operator);
        return ApiResponse.ok(adminConfigService.updateDraft(gm, configKey, request, clientIp(httpRequest)));
    }

    @PostMapping("/publish")
    public ApiResponse<ConfigPublishResultResponse> publish(
            @RequestBody(required = false) ConfigPublishRequest request,
            HttpServletRequest httpRequest
    ) {
        GmPrincipal gm = AdminSecurityUtils.requireRole(GmRole.operator);
        ConfigPublishRequest body = request == null ? new ConfigPublishRequest(null) : request;
        return ApiResponse.ok(adminConfigService.publish(gm, body, clientIp(httpRequest)));
    }

    @GetMapping("/history")
    public ApiResponse<ConfigPublishHistoryResponse> history(
            @RequestParam(defaultValue = "20") int limit
    ) {
        AdminSecurityUtils.requireRole(GmRole.viewer);
        return ApiResponse.ok(adminConfigService.history(limit));
    }

    @PostMapping("/rollback/{publishId}")
    public ApiResponse<ConfigPublishResultResponse> rollback(
            @PathVariable long publishId,
            HttpServletRequest httpRequest
    ) {
        GmPrincipal gm = AdminSecurityUtils.requireRole(GmRole.super_);
        return ApiResponse.ok(adminConfigService.rollback(gm, publishId, clientIp(httpRequest)));
    }

    private String clientIp(HttpServletRequest request) {
        String forwarded = request.getHeader("X-Forwarded-For");
        if (forwarded != null && !forwarded.isBlank()) {
            return forwarded.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }
}
