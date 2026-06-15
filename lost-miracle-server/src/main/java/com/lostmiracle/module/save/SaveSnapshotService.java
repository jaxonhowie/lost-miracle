package com.lostmiracle.module.save;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

@Service
public class SaveSnapshotService {

    private static final int MAX_SNAPSHOTS_PER_CHARACTER = 5;

    private final JdbcTemplate jdbcTemplate;

    public SaveSnapshotService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Async
    public void snapshotAsync(long characterId, long saveVersion, String saveJson) {
        jdbcTemplate.update(
                "INSERT INTO character_save_snapshot (character_id, save_version, save_json) VALUES (?, ?, ?)",
                characterId,
                saveVersion,
                saveJson
        );
        jdbcTemplate.update(
                """
                        DELETE FROM character_save_snapshot
                        WHERE character_id = ?
                          AND id NOT IN (
                            SELECT id FROM (
                              SELECT id FROM character_save_snapshot
                              WHERE character_id = ?
                              ORDER BY save_version DESC
                              LIMIT ?
                            ) recent
                          )
                        """,
                characterId,
                characterId,
                MAX_SNAPSHOTS_PER_CHARACTER
        );
    }

    public void deleteByCharacterId(long characterId) {
        jdbcTemplate.update("DELETE FROM character_save_snapshot WHERE character_id = ?", characterId);
        jdbcTemplate.update("DELETE FROM leaderboard_snapshot WHERE character_id = ?", characterId);
    }
}
