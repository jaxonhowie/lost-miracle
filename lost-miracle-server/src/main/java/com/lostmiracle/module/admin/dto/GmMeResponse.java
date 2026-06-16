package com.lostmiracle.module.admin.dto;

import com.lostmiracle.module.admin.GmRole;

public record GmMeResponse(
        long gmAccountId,
        String username,
        String role
) {
    public static GmMeResponse from(long gmAccountId, String username, GmRole role) {
        return new GmMeResponse(gmAccountId, username, role.toDbValue());
    }
}
