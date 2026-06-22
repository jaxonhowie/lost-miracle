package com.lostmiracle.module.loot;

import com.fasterxml.jackson.databind.JsonNode;
import com.lostmiracle.module.config.ConfigDefaults;
import com.lostmiracle.module.config.GameConfigService;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ThreadLocalRandom;

public class LootEngine {

    private static final Map<String, RateRange> FALLBACK_EQUIP = Map.of(
            "normal", new RateRange(0.30, 1, 1),
            "elite", new RateRange(0.60, 1, 2),
            "boss", new RateRange(1.00, 2, 3)
    );
    private static final Map<String, IntRange> FALLBACK_GOLD = Map.of(
            "normal", new IntRange(10, 30),
            "elite", new IntRange(30, 80),
            "boss", new IntRange(100, 300)
    );
    private static final Map<String, RateRange> FALLBACK_STONE = Map.of(
            "normal", new RateRange(0.10, 0, 1),
            "elite", new RateRange(0.25, 1, 2),
            "boss", new RateRange(0.50, 2, 5)
    );

    private final GameDataCatalog catalog;
    private final EquipmentGenerator equipmentGenerator;
    private final GameConfigService configService;

    public LootEngine(GameDataCatalog catalog, EquipmentGenerator equipmentGenerator, GameConfigService configService) {
        this.catalog = catalog;
        this.equipmentGenerator = equipmentGenerator;
        this.configService = configService;
    }

    public LootRollResult rollBattleRewards(String dungeonId, String monsterId) {
        String monsterType = catalog.getMonsterType(monsterId);
        int expPerLevel = readConfigInt(ConfigDefaults.LOOT_EXP_PER_LEVEL, "exp_per_level", 30);
        int exp = catalog.getMonsterLevel(monsterId) * expPerLevel;
        List<Map<String, Object>> items = new ArrayList<>();

        switch (dungeonId) {
            case "corrupt_swamp" -> rollCorruptSwamp(items, monsterType);
            case "frozen_abyss" -> rollFrozenAbyss(items, monsterType);
            case "forge_ruins" -> rollForgeRuins(items, monsterType);
            default -> rollDefaultDungeon(items, monsterType);
        }

        Map<String, Object> potionCfg = getConfigMap(ConfigDefaults.LOOT_POTION_DROP);
        double potionRate = readDouble(potionCfg, "rate", 0.50);
        int potionMin = readInt(potionCfg, "min", 1);
        int potionMax = readInt(potionCfg, "max", 5);
        if (ThreadLocalRandom.current().nextDouble() <= potionRate) {
            items.add(resourceDrop("health_potion", randomBetween(potionMin, potionMax)));
        }

        int gold = sumGold(items);
        return new LootRollResult(exp, gold, items, monsterType);
    }

    private void rollDefaultDungeon(List<Map<String, Object>> items, String monsterType) {
        RateRange equipInfo = readEquipRate(monsterType);
        if (ThreadLocalRandom.current().nextDouble() <= equipInfo.rate()) {
            int count = randomBetween(equipInfo.min(), equipInfo.max());
            for (int i = 0; i < count; i++) {
                Map<String, Object> eq = equipmentGenerator.generateEquipment(monsterType);
                if (!eq.isEmpty()) {
                    items.add(eq);
                }
            }
        }
        IntRange goldRange = readGoldRange(monsterType);
        items.add(resourceDrop("gold", randomBetween(goldRange.min(), goldRange.max())));

        RateRange stoneInfo = readStoneRate(monsterType);
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

        IntRange gold = readGoldRange(cfg.path("gold").path(monsterType), FALLBACK_GOLD.get(monsterType));
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

        IntRange gold = readGoldRange(cfg.path("gold").path(monsterType), FALLBACK_GOLD.get(monsterType));
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
        IntRange gold = readGoldRange(cfg.path("gold").path(monsterType), FALLBACK_GOLD.get(monsterType));
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

    // ---------- config-driven helpers ----------

    @SuppressWarnings("unchecked")
    private Map<String, Object> getConfigMap(String configKey) {
        Map<String, Object> map = configService.getPublishedMap(configKey);
        return map.isEmpty() ? Map.of() : map;
    }

    private int readConfigInt(String configKey, String field, int fallback) {
        Map<String, Object> map = getConfigMap(configKey);
        return readInt(map, field, fallback);
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> getTypeSection(Map<String, Object> cfg, String monsterType) {
        Object section = cfg.get(monsterType);
        if (section instanceof Map<?, ?> m) {
            return (Map<String, Object>) m;
        }
        Object normal = cfg.get("normal");
        if (normal instanceof Map<?, ?> m) {
            return (Map<String, Object>) m;
        }
        return Map.of();
    }

    private RateRange readEquipRate(String monsterType) {
        Map<String, Object> cfg = getConfigMap(ConfigDefaults.LOOT_EQUIP_DROP);
        if (cfg.isEmpty()) {
            return FALLBACK_EQUIP.getOrDefault(monsterType, FALLBACK_EQUIP.get("normal"));
        }
        Map<String, Object> section = getTypeSection(cfg, monsterType);
        return new RateRange(
                readDouble(section, "rate", 0.30),
                readInt(section, "min", 1),
                readInt(section, "max", 1)
        );
    }

    private IntRange readGoldRange(String monsterType) {
        Map<String, Object> cfg = getConfigMap(ConfigDefaults.LOOT_GOLD_DROP);
        if (cfg.isEmpty()) {
            return FALLBACK_GOLD.getOrDefault(monsterType, FALLBACK_GOLD.get("normal"));
        }
        Map<String, Object> section = getTypeSection(cfg, monsterType);
        return new IntRange(readInt(section, "min", 10), readInt(section, "max", 30));
    }

    private RateRange readStoneRate(String monsterType) {
        Map<String, Object> cfg = getConfigMap(ConfigDefaults.LOOT_STONE_DROP);
        if (cfg.isEmpty()) {
            return FALLBACK_STONE.getOrDefault(monsterType, FALLBACK_STONE.get("normal"));
        }
        Map<String, Object> section = getTypeSection(cfg, monsterType);
        return new RateRange(
                readDouble(section, "rate", 0.10),
                readInt(section, "min", 0),
                readInt(section, "max", 1)
        );
    }

    private double readDouble(Map<String, Object> map, String key, double fallback) {
        Object v = map.get(key);
        if (v instanceof Number n) return n.doubleValue();
        return fallback;
    }

    private int readInt(Map<String, Object> map, String key, int fallback) {
        Object v = map.get(key);
        if (v instanceof Number n) return n.intValue();
        return fallback;
    }

    // ---------- existing helpers ----------

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
