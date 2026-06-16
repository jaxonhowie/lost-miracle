package com.lostmiracle.module.admin.dto;

import java.util.List;

public record GmAuditLogListResponse(
        List<GmAuditLogResponse> items,
        int page,
        int pageSize
) {
}
