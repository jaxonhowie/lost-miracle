package com.lostmiracle.module.config.dto;

import java.util.Map;

public record ConfigBundleResponse(
        long version,
        boolean unchanged,
        Map<String, Object> configs
) {
}
