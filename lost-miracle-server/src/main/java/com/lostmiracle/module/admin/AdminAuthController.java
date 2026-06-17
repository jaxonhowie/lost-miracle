package com.lostmiracle.module.admin;

import com.lostmiracle.common.ApiResponse;
import com.lostmiracle.module.admin.dto.GmAuthResponse;
import com.lostmiracle.module.admin.dto.GmLoginRequest;
import com.lostmiracle.module.admin.dto.GmMeResponse;
import com.lostmiracle.module.save.RateLimitService;
import com.lostmiracle.security.AdminSecurityUtils;
import com.lostmiracle.security.GmPrincipal;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/admin/auth")
public class AdminAuthController {

    private final AdminAuthService adminAuthService;
    private final RateLimitService rateLimitService;

    public AdminAuthController(AdminAuthService adminAuthService, RateLimitService rateLimitService) {
        this.adminAuthService = adminAuthService;
        this.rateLimitService = rateLimitService;
    }

    @PostMapping("/login")
    public ApiResponse<GmAuthResponse> login(@Valid @RequestBody GmLoginRequest request, HttpServletRequest httpRequest) {
        rateLimitService.checkLogin(resolveClientIp(httpRequest));
        return ApiResponse.ok(adminAuthService.login(request));
    }

    @GetMapping("/me")
    public ApiResponse<GmMeResponse> me() {
        GmPrincipal principal = AdminSecurityUtils.requireGm();
        return ApiResponse.ok(adminAuthService.me(principal));
    }

    private static String resolveClientIp(HttpServletRequest request) {
        String xff = request.getHeader("X-Forwarded-For");
        if (xff != null && !xff.isBlank()) {
            return xff.split(",")[0].trim();
        }
        String realIp = request.getHeader("X-Real-IP");
        if (realIp != null && !realIp.isBlank()) {
            return realIp.trim();
        }
        return request.getRemoteAddr();
    }
}
