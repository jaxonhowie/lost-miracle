package com.lostmiracle.security;

import com.lostmiracle.common.BusinessException;
import com.lostmiracle.common.ErrorCode;
import com.lostmiracle.module.admin.GmRole;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

public final class AdminSecurityUtils {

    private AdminSecurityUtils() {
    }

    public static GmPrincipal requireGm() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null || !(authentication.getPrincipal() instanceof GmPrincipal principal)) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED, "unauthorized");
        }
        return principal;
    }

    public static GmPrincipal requireRole(GmRole minimum) {
        GmPrincipal principal = requireGm();
        if (!principal.role().atLeast(minimum)) {
            throw new BusinessException(ErrorCode.FORBIDDEN, "insufficient gm role");
        }
        return principal;
    }
}
