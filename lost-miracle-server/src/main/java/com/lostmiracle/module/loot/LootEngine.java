package com.lostmiracle.module.loot;

import com.fasterxml.jackson.databind.JsonNode;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ThreadLocalRandom;

public class LootEngine {

    private static final Map<String, RateRange> DEFAULT_EQUIP = Map.of(
            "normal", new RateRange(0.30, 1, 1),
            "elite", new RateRange(0.60, 1, 2),
            "boss", new RateRange(1.00, 2, 3)
    );
    private static final Map<String, IntRange> DEFAULT_GOLD = Map.of(
            "normal", new IntRange(10, 30),
            "elite", new IntRange(30, 80),
            "boss", new IntRange(100, 300)
    );
    private static final Map<String, RateRange> DEFAULT_STONE = Map.of(
            "normal", new RateRange(0.10, 0, 1),
            "elite", new RateRange(0.25, 1, 2),
            "boss", new RateRange(0.50, 2, 5)
    );

    private final GameDataCatalog catalog;
    private final EquipmentGenerator equipmentGenerator;

    public LootEngine(GameDataCatalog catalog, EquipmentGenerator equipmentGenerator) {
        this.catalog = catalog;
        this.equipmentGenerator = equipmentGenerator;
    }

    public LootRollResult rollBattleRewards(String dungeonId, String monsterId) {
        String monsterType = catalog.getMonsterType(monsterId);
        int exp = catalog.getMonsterLevel(monsterId) * 30;
        List<Map<String, Object>> items = new ArrayList<>();

        switch (dungeonId) {
            case "corrupt_swamp" -> rollCorruptSwamp(items, monsterType);
            case "frozen_abyss" -> rollFrozenAbyss(items, monsterType);
            case "forge_ruins" -> rollForgeRuins(items, monsterType);
            default -> rollDefaultDungeon(items, monsterType);
        }

        if (ThreadLocalRandom.current().nextDouble() <= 0.5) {
            items.add(resourceDrop("health_potion", randomBetween(1, 5)));
        }

        int gold = sumGold(items);
        return new LootRollResult(exp, gold, items, monsterType);
    }

    private void rollDefaultDungeon(List<Map<String, Object>> items, String monsterType) {
        RateRange equipInfo = DEFAULT_EQUIP.getOrDefault(monsterType, DEFAULT_EQUIP.get("normal"));
        if (ThreadLocalRandom.current().nextDouble() <= equipInfo.rate()) {
            int count = randomBetween(equipInfo.min(), equipInfo.max());
            for (int i = 0; i < count; i++) {
                Map<String, Object> eq = equipmentGenerator.generateEquipment(monsterType);
                if (!eq.isEmpty()) {
                    items.add(eq);
                }
            }
        }
        IntRange goldRange = DEFAULT_GOLD.getOrDefault(monsterType, DEFAULT_GOLD.get("normal"));
        items.add(resourceDrop("gold", randomBetween(goldRange.min(), goldRange.max())));

        RateRange stoneInfo = DEFAULT_STONE.getOrDefault(monsterType, DEFAULT_STONE.get("normal"));
        if (ThreadLocalRandom.current().nextDouble() <= stoneInfo.rate()) {
            int stoneCount = randomBetween(stoneInfo.min(), stoneInfo.max());
            if (stoneCount > 0) {
                items.add(resourceDrop("enhance_stone", stoneCount));
            }
        }
    }

    private void rollCorruptSwamp(List<Map<String, Object>> items, String monsterType) {
        JsonNode cfg = catalog.getJewelryConfig().path("corrupt_swamp_drops");
        JsonNode ringRates = cfg.path("ring_drop_rates");
        double ringRate = ringRates.path(monsterType).asDouble(ringRates.path("normal").asDouble(0.08));

        if ("boss".equals(monsterType)) {
            int guaranteed = cfg.path("boss_guaranteed_rings").asInt(1);
            for (int i = 0; i < guaranteed; i++) {
                addJewelryIfPresent(items, equipmentGenerator.generateJewelry());
            }
            if (ThreadLocalRandom.current().nextDouble() <= cfg.path("boss_extra_ring_chance").asDouble(0.35)) {
                addJewelryIfPresent(items, equipmentGenerator.generateJewelry());
            }
        } else if (ThreadLocalRandom.current().nextDouble() <= ringRate) {
            addJewelryIfPresent(items, equipmentGenerator.generateJewelry());
        }

        IntRange gold = readGoldRange(cfg.path("gold").path(monsterType), DEFAULT_GOLD.get(monsterType));
        items.add(resourceDrop("gold", randomBetween(gold.min(), gold.max())));

        JsonNode stoneCfg = cfg.path("enhance_stone").path(monsterType);
        if (!stoneCfg.isMissingNode() && ThreadLocalRandom.current().nextDouble() <= stoneCfg.path("rate").asDouble(0.0)) {
            int count = randomBetween(stoneCfg.path("min").asInt(0), stoneCfg.path("max").asInt(0));
            if (count > 0) {
                items.add(resourceDrop("enhance_stone", count));
            }
        }
    }

    private void rollFrozenAbyss(List<Map<String, Object>> items, String monsterType) {
        JsonNode cfg = catalog.getJewelryConfig().path("frozen_abyss_drops");
        JsonNode necklaceRates = cfg.path("necklace_drop_rates");
        double necklaceRate = necklaceRates.path(monsterType)
                .asDouble(necklaceRates.path("normal").asDouble(0.08));

        if ("boss".equals(monsterType)) {
            int guaranteed = cfg.path("boss_guaranteed_necklaces").asInt(1);
            for (int i = 0; i < guaranteed; i++) {
                addJewelryIfPresent(items, equipmentGenerator.generateNecklace());
            }
            if (ThreadLocalRandom.current().nextDouble() <= cfg.path("boss_extra_necklace_chance").asDouble(0.35)) {
                addJewelryIfPresent(items, equipmentGenerator.generateNecklace());
            }
        } else if (ThreadLocalRandom.current().nextDouble() <= necklaceRate) {
            addJewelryIfPresent(items, equipmentGenerator.generateNecklace());
        }

        IntRange gold = readGoldRange(cfg.path("gold").path(monsterType), DEFAULT_GOLD.get(monsterType));
        items.add(resourceDrop("gold", randomBetween(gold.min(), gold.max())));

        JsonNode stoneCfg = cfg.path("enhance_stone").path(monsterType);
        if (!stoneCfg.isMissingNode() && ThreadLocalRandom.current().nextDouble() <= stoneCfg.path("rate").asDouble(0.0)) {
            int count = randomBetween(stoneCfg.path("min").asInt(0), stoneCfg.path("max").asInt(0));
            if (count > 0) {
                items.add(resourceDrop("enhance_stone", count));
            }
        }
    }

    private void rollForgeRuins(List<Map<String, Object>> items, String monsterType) {
        JsonNode cfg = catalog.getJewelryConfig().path("forge_ruins_drops");
        IntRange gold = readGoldRange(cfg.path("gold").path(monsterType), DEFAULT_GOLD.get(monsterType));
        items.add(resourceDrop("gold", randomBetween(gold.min(), gold.max())));

        JsonNode stoneCfg = catalog.getJewelryConfig()
                .path("jewelry_stone_drop")
                .path("forge_ruins")
                .path(monsterType);
        if (stoneCfg.isMissingNode() || stoneCfg.isEmpty()) {
            stoneCfg = catalog.getJewelryConfig().path("jewelry_stone_drop").path("forge_ruins").path("normal");
        }
        if (!stoneCfg.isMissingNode()) {
            if (ThreadLocalRandom.current().nextDouble() <= stoneCfg.path("jewelry_rate").asDouble(0.0)) {
                int count = randomBetween(
                        stoneCfg.path("jewelry_min").asInt(0),
                        stoneCfg.path("jewelry_max").asInt(0)
                );
                if (count > 0) {
                    items.add(resourceDrop("jewelry_enhance_stone", count));
                }
            }
            if (ThreadLocalRandom.current().nextDouble() <= stoneCfg.path("blessed_jewelry_rate").asDouble(0.0)) {
                int count = randomBetween(
                        stoneCfg.path("blessed_jewelry_min").asInt(0),
                        stoneCfg.path("blessed_jewelry_max").asInt(0)
                );
                if (count > 0) {
                    items.add(resourceDrop("blessed_jewelry_enhance_stone", count));
                }
            }
        }
    }

    private void addJewelryIfPresent(List<Map<String, Object>> items, Map<String, Object> jewelry) {
        if (!jewelry.isEmpty()) {
            items.add(jewelry);
        }
    }

    private IntRange readGoldRange(JsonNode node, IntRange fallback) {
        if (node == null || node.isMissingNode() || node.isEmpty()) {
            return fallback;
        }
        return new IntRange(node.path("min").asInt(fallback.min()), node.path("max").asInt(fallback.max()));
    }

    private Map<String, Object> resourceDrop(String type, int amount) {
        Map<String, Object> drop = new HashMap<>();
        drop.put("type", type);
        drop.put("amount", amount);
        return drop;
    }

    private int sumGold(List<Map<String, Object>> items) {
        int total = 0;
        for (Map<String, Object> item : items) {
            if ("gold".equals(String.valueOf(item.get("type")))) {
                total += intValue(item.get("amount"));
            }
        }
        return total;
    }

    private int randomBetween(int min, int max) {
        if (max < min) {
            return min;
        }
        return ThreadLocalRandom.current().nextInt(min, max + 1);
    }

    private int intValue(Object value) {
        if (value instanceof Number number) {
            return number.intValue();
        }
        if (value == null) {
            return 0;
        }
        try {
            return Integer.parseInt(String.valueOf(value));
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    private record RateRange(double rate, int min, int max) {
    }

    private record IntRange(int min, int max) {
    }
}
