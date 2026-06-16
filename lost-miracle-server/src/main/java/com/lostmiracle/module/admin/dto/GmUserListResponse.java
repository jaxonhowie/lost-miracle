package com.lostmiracle.module.admin.dto;

import java.util.List;

public record GmUserListResponse(
        List<GmUserSummaryResponse> items,
        long total,
        int page,
        int pageSize
) {
}
