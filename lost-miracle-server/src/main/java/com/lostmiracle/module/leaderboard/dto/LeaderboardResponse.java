package com.lostmiracle.module.leaderboard.dto;

import java.util.List;

public record LeaderboardResponse(
        String boardType,
        String season,
        Integer myRank,
        Long myScore,
        List<LeaderboardEntryResponse> items
) {
}
