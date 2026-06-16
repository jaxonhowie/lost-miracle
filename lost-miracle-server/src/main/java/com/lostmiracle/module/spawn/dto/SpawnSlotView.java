package com.lostmiracle.module.spawn.dto;

public record SpawnSlotView(
        long slotId,
        String monsterId,
        int slotIndex,
        boolean available,
        int cooldownSec
) {
}
