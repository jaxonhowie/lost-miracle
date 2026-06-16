package com.lostmiracle.module.spawn.dto;

public record SpawnEncounterResponse(
        long slotId,
        String spawnType,
        String monsterId,
        int slotIndex
) {
}
