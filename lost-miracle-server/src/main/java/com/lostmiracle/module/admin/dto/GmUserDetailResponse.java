package com.lostmiracle.module.admin.dto;

public record GmUserDetailResponse(
        long id,
        String username,
        int status,
        long createdAt,
        long updatedAt
) {
}
