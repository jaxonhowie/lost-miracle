package com.lostmiracle.module.leaderboard;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.util.Set;

@Component
public class LeaderboardSnapshotJob {

    private final LeaderboardService leaderboardService;
    private final JdbcTemplate jdbcTemplate;

    public LeaderboardSnapshotJob(LeaderboardService leaderboardService, JdbcTemplate jdbcTemplate) {
        this.leaderboardService = leaderboardService;
        this.jdbcTemplate = jdbcTemplate;
    }

    @Scheduled(cron = "0 0 * * * *")
    public void snapshotPowerLeaderboard() {
        String boardType = LeaderboardService.BOARD_POWER;
        String season = "all";
        var response = leaderboardService.getLeaderboard(boardType, season, 1, 100, null);
        jdbcTemplate.update(
                "DELETE FROM leaderboard_snapshot WHERE board_type = ? AND season = ?",
                boardType,
                season
        );
        response.items().forEach(entry -> jdbcTemplate.update(
                """
                        INSERT INTO leaderboard_snapshot
                        (board_type, season, character_id, score, rank)
                        VALUES (?, ?, ?, ?, ?)
                        """,
                boardType,
                season,
                entry.characterId(),
                entry.score(),
                entry.rank()
        ));
    }
}
