package com.lostmiracle.module.admin.dto;

import java.time.LocalDateTime;

public record GmAuditLogResponse(
        long id,
        long gmAccountId,
        String action,
        String targetType,
        String targetId,
        String detailJson,
        String ip,
        LocalDateTime createdAt
) {
}
