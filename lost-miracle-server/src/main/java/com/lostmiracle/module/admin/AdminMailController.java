package com.lostmiracle.module.admin;

import com.lostmiracle.common.ApiResponse;
import com.lostmiracle.module.admin.dto.AdminSendMailRequest;
import com.lostmiracle.security.AdminSecurityUtils;
import com.lostmiracle.security.GmPrincipal;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/admin/mail")
public class AdminMailController {

    private final AdminMailService adminMailService;
    private final GmAuditService gmAuditService;

    public AdminMailController(AdminMailService adminMailService, GmAuditService gmAuditService) {
        this.adminMailService = adminMailService;
        this.gmAuditService = gmAuditService;
    }

    @PostMapping("/send")
    public ApiResponse<Map<String, Object>> send(
            @Valid @RequestBody AdminSendMailRequest request,
            HttpServletRequest httpRequest
    ) {
        GmPrincipal gm = AdminSecurityUtils.requireRole(GmRole.operator);
        int count = adminMailService.sendMail(request);

        String action = request.getCharacterId() != null ? "MAIL_SEND" : "MAIL_BROADCAST";
        String targetId = request.getCharacterId() != null ? String.valueOf(request.getCharacterId()) : "ALL";
        gmAuditService.log(
                gm.gmAccountId(), action, "mail", targetId,
                Map.of("title", request.getTitle(), "count", count),
                clientIp(httpRequest)
        );

        return ApiResponse.ok(Map.of("sent", count));
    }

    private String clientIp(HttpServletRequest request) {
        String forwarded = request.getHeader("X-Forwarded-For");
        if (forwarded != null && !forwarded.isBlank()) {
            return forwarded.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }
}
