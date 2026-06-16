package com.lostmiracle.module.admin.dto;

public record GmUserSummaryResponse(
        long id,
        String username,
        int status,
        long createdAt
) {
}
