package com.lostmiracle.module.config.dto;

import java.util.List;

public record ConfigListResponse(
        long version,
        List<ConfigItemResponse> items
) {
}
