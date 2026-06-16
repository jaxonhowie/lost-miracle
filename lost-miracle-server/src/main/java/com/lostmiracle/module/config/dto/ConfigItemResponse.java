package com.lostmiracle.module.config.dto;

import java.util.Map;

public record ConfigItemResponse(
        String configKey,
        String description,
        Map<String, Object> draft,
        Map<String, Object> published
) {
}
