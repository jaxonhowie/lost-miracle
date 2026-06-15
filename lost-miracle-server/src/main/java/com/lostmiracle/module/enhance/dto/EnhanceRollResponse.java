package com.lostmiracle.module.enhance.dto;

import java.util.Map;

public record EnhanceRollResponse(
        boolean success,
        boolean broken,
        int newLevel,
        String message,
        boolean gainedBlessed,
        long saveVersion,
        long serverUpdatedAt,
        int powerScore,
        Map<String, Object> save
) {
}
