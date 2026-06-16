package com.lostmiracle.module.admin;

import com.lostmiracle.common.ApiResponse;
import com.lostmiracle.module.admin.dto.GmAuditLogListResponse;
import com.lostmiracle.security.AdminSecurityUtils;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/admin/audit-log")
public class AdminAuditController {

    private final AdminAuditQueryService adminAuditQueryService;

    public AdminAuditController(AdminAuditQueryService adminAuditQueryService) {
        this.adminAuditQueryService = adminAuditQueryService;
    }

    @GetMapping
    public ApiResponse<GmAuditLogListResponse> list(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int pageSize
    ) {
        AdminSecurityUtils.requireRole(GmRole.viewer);
        return ApiResponse.ok(adminAuditQueryService.listRecent(page, pageSize));
    }
}
