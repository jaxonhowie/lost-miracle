package com.lostmiracle.module.loot;

import com.fasterxml.jackson.databind.JsonNode;
import org.springframework.stereotype.Component;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ThreadLocalRandom;
import java.util.concurrent.atomic.AtomicLong;

@Component
public class EquipmentGenerator {

    private final GameDataCatalog catalog;
    private final AtomicLong uidSeq = new AtomicLong(0);

    public EquipmentGenerator(GameDataCatalog catalog) {
        this.catalog = catalog;
    }

    public Map<String, Object> generateEquipment(String monsterType) {
        String tier = rollDropTier(monsterType);
        List<JsonNode> bases = catalog.listEquipmentBasesByTier(tier);
        if (bases.isEmpty()) {
            return Map.of();
        }
        JsonNode base = bases.get(ThreadLocalRandom.current().nextInt(bases.size()));
        boolean blessed = "boss".equals(monsterType)
                && ThreadLocalRandom.current().nextDouble() < catalog.getEnhanceRules()
                .path("blessed_equipment_on_drop").asDouble(0.10);
        return buildEquipmentInstance(base, blessed);
    }

    public Map<String, Object> generateJewelry() {
        List<String> lines = catalog.listJewelryLineIds();
        if (lines.isEmpty()) {
            return Map.of();
        }
        String lineId = lines.get(ThreadLocalRandom.current().nextInt(lines.size()));
        return buildJewelry(lineId, 0);
    }

    public Map<String, Object> generateNecklace() {
        List<String> lines = catalog.listNecklaceLineIds();
        if (lines.isEmpty()) {
            return Map.of();
        }
        String lineId = lines.get(ThreadLocalRandom.current().nextInt(lines.size()));
        return buildNecklace(lineId, 0);
    }

    private Map<String, Object> buildJewelry(String lineId, int level) {
        JsonNode line = catalog.getJewelryLine(lineId);
        Map<String, Object> eq = new HashMap<>();
        eq.put("uid", generateUid());
        eq.put("base_id", line.path("id").asText("ring_" + lineId));
        eq.put("jewelry_line", lineId);
        eq.put("name", jewelryName(line, level));
        eq.put("slot", "ring");
        eq.put("type", "jewelry");
        eq.put("class_req", "");
        eq.put("dual_wield", false);
        eq.put("is_blessed", false);
        eq.put("quality", "normal");
        eq.put("enhance_level", level);
        eq.put("base_stats", jewelryStats(line, level));
        eq.put("set_id", "");
        eq.put("effects", Map.of());
        return eq;
    }

    private Map<String, Object> buildNecklace(String lineId, int level) {
        JsonNode line = catalog.getNecklaceLine(lineId);
        Map<String, Object> eq = new HashMap<>();
        eq.put("uid", generateUid());
        eq.put("base_id", line.path("id").asText("necklace_" + lineId));
        eq.put("jewelry_line", lineId);
        eq.put("name", necklaceName(line, level));
        eq.put("slot", "necklace");
        eq.put("type", "jewelry");
        eq.put("class_req", "");
        eq.put("dual_wield", false);
        eq.put("is_blessed", false);
        eq.put("quality", "normal");
        eq.put("enhance_level", level);
        eq.put("base_stats", jewelryStats(line, level));
        eq.put("set_id", "");
        eq.put("effects", Map.of());
        return eq;
    }

    private Map<String, Object> buildEquipmentInstance(JsonNode base, boolean blessed) {
        JsonNode rules = catalog.getEnhanceRules();
        Map<String, Object> eq = new HashMap<>();
        eq.put("uid", generateUid());
        eq.put("base_id", base.path("id").asText(""));
        eq.put("name", base.path("name").asText("未知装备"));
        eq.put("slot", base.path("slot").asText(""));
        eq.put("type", base.path("type").asText(""));
        eq.put("class_req", base.path("class_req").asText(""));
        eq.put("dual_wield", base.path("dual_wield").asBoolean(false));
        eq.put("safe_enhance_until", base.path("safe_enhance_until")
                .asInt(rules.path("default_safe_until").asInt(3)));
        eq.put("is_blessed", blessed);
        eq.put("quality", "normal");
        eq.put("enhance_level", 0);
        eq.put("base_stats", catalog.jsonToMap(base.path("base_stats")));
        eq.put("set_id", base.path("set_id").asText(""));
        eq.put("effects", catalog.jsonToMap(base.path("effects")));
        return eq;
    }

    private String jewelryName(JsonNode line, int level) {
        JsonNode names = line.path("names");
        if (!names.isArray() || names.isEmpty()) {
            return "戒指";
        }
        int idx = Math.min(level, names.size() - 1);
        return names.get(idx).asText("戒指");
    }

    private String necklaceName(JsonNode line, int level) {
        JsonNode names = line.path("names");
        if (!names.isArray() || names.isEmpty()) {
            return "项链";
        }
        int idx = Math.min(level, names.size() - 1);
        return names.get(idx).asText("项链");
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> jewelryStats(JsonNode line, int level) {
        JsonNode statsByLevel = line.path("stats_by_level");
        if (!statsByLevel.isArray() || statsByLevel.isEmpty()) {
            return Map.of();
        }
        int idx = Math.min(level, statsByLevel.size() - 1);
        return catalog.jsonToMap(statsByLevel.get(idx));
    }

    private String rollDropTier(String monsterType) {
        JsonNode weightsCfg = catalog.getEnhanceRules().path("drop_tier_weights");
        JsonNode weights = weightsCfg.path(monsterType);
        if (weights.isMissingNode() || weights.isEmpty()) {
            weights = weightsCfg.path("normal");
        }
        if (weights.isMissingNode() || weights.isEmpty()) {
            return "vine";
        }
        String[] tiers = {"vine", "chain", "plate"};
        int total = 0;
        for (String tier : tiers) {
            total += weights.path(tier).asInt(0);
        }
        if (total <= 0) {
            return "vine";
        }
        int roll = ThreadLocalRandom.current().nextInt(total);
        int cumulative = 0;
        for (String tier : tiers) {
            cumulative += weights.path(tier).asInt(0);
            if (roll < cumulative) {
                return tier;
            }
        }
        return "vine";
    }

    private String generateUid() {
        return "eq_" + System.currentTimeMillis() + "_" + uidSeq.incrementAndGet();
    }
}
