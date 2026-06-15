package com.lostmiracle.module.achievement.dto;

import jakarta.validation.constraints.NotNull;

public record ClaimAchievementRequest(@NotNull Long saveVersion) {
}
