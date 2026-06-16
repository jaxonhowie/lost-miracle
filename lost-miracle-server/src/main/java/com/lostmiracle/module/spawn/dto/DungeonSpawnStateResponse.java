package com.lostmiracle.module.spawn.dto;

import java.util.List;
import java.util.Map;

public record DungeonSpawnStateResponse(
        String dungeonId,
        Map<String, List<SpawnSlotView>> normals,
        SpawnSlotView elite,
        SpawnSlotView boss
) {
}
