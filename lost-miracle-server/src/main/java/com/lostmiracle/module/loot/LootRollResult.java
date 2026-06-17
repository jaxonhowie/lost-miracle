package com.lostmiracle.module.loot;

import java.util.List;
import java.util.Map;

public record LootRollResult(
        int exp,
        int gold,
        List<Map<String, Object>> items,
        String monsterType
) {
}
