package com.lostmiracle.module.achievement.dto;

import java.util.Map;

public record AchievementItemResponse(
        String id,
        String title,
        String description,
        int target,
        int progress,
        boolean completed,
        boolean claimed,
        Map<String, Object> rewards
) {
}
