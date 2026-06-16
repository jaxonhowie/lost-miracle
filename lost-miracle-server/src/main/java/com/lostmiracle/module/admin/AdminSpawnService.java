package com.lostmiracle.module.admin;

import com.lostmiracle.module.admin.dto.GmSpawnResetResponse;
import com.lostmiracle.module.spawn.SpawnService;
import com.lostmiracle.module.spawn.dto.DungeonSpawnStateResponse;
import com.lostmiracle.security.GmPrincipal;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Map;

@Service
public class AdminSpawnService {

    private final SpawnService spawnService;
    private final GmAuditService gmAuditService;

    public AdminSpawnService(SpawnService spawnService, GmAuditService gmAuditService) {
        this.spawnService = spawnService;
        this.gmAuditService = gmAuditService;
    }

    public DungeonSpawnStateResponse getState(String dungeonId) {
        return spawnService.getState(dungeonId);
    }

    @Transactional
    public void resetSlot(GmPrincipal gm, long slotId, String ip) {
        spawnService.adminResetSlot(slotId);
        gmAuditService.log(
                gm.gmAccountId(),
                "SPAWN_RESET_SLOT",
                "spawn_slot",
                String.valueOf(slotId),
                Map.of(),
                ip
        );
    }

    @Transactional
    public GmSpawnResetResponse resetDungeon(GmPrincipal gm, String dungeonId, String ip) {
        int count = spawnService.adminResetDungeon(dungeonId);
        gmAuditService.log(
                gm.gmAccountId(),
                "SPAWN_RESET_DUNGEON",
                "dungeon",
                dungeonId,
                Map.of("resetCount", count),
                ip
        );
        return new GmSpawnResetResponse(count);
    }
}
