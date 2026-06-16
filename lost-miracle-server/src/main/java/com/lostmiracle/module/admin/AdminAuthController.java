package com.lostmiracle.module.admin;

import com.lostmiracle.common.ApiResponse;
import com.lostmiracle.module.admin.dto.GmAuthResponse;
import com.lostmiracle.module.admin.dto.GmLoginRequest;
import com.lostmiracle.module.admin.dto.GmMeResponse;
import com.lostmiracle.security.AdminSecurityUtils;
import com.lostmiracle.security.GmPrincipal;
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

    public AdminAuthController(AdminAuthService adminAuthService) {
        this.adminAuthService = adminAuthService;
    }

    @PostMapping("/login")
    public ApiResponse<GmAuthResponse> login(@Valid @RequestBody GmLoginRequest request) {
        return ApiResponse.ok(adminAuthService.login(request));
    }

    @GetMapping("/me")
    public ApiResponse<GmMeResponse> me() {
        GmPrincipal principal = AdminSecurityUtils.requireGm();
        return ApiResponse.ok(adminAuthService.me(principal));
    }
}
