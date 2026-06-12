package com.lostmiracle.module.leaderboard.dto;

public record LeaderboardEntryResponse(
        int rank,
        long characterId,
        String name,
        String playerClass,
        int level,
        long score,
        String currentDungeonId
) {
}
