package com.lostmiracle.module.character.dto;

public record CharacterSummaryResponse(
        long id,
        String name,
        String playerClass,
        int level,
        int powerScore,
        String currentDungeonId,
        long lastLoginAt,
        long saveVersion
) {
}
