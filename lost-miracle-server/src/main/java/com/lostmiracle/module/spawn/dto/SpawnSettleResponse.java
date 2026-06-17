package com.lostmiracle.module.spawn.dto;

import java.util.List;
import java.util.Map;

public record SpawnSettleResponse(
        long saveVersion,
        long serverUpdatedAt,
        int powerScore,
        int exp,
        int gold,
        List<Map<String, Object>> items,
        Map<String, Object> save
) {
}
