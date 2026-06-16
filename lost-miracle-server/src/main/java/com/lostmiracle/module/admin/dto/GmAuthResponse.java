package com.lostmiracle.module.admin.dto;

import com.lostmiracle.module.admin.GmRole;

public record GmAuthResponse(
        String token,
        long expiresInSeconds,
        long gmAccountId,
        String username,
        String role
) {
    public static GmAuthResponse of(String token, long expiresInSeconds, long gmAccountId, String username, GmRole role) {
        return new GmAuthResponse(token, expiresInSeconds, gmAccountId, username, role.toDbValue());
    }
}
