package com.lostmiracle.module.achievement.dto;

import java.util.Map;

public record ClaimAchievementResponse(
        long saveVersion,
        long serverUpdatedAt,
        int powerScore,
        Map<String, Object> save
) {
}
