package com.lostmiracle.module.loot;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.lostmiracle.common.BusinessException;
import com.lostmiracle.common.ErrorCode;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

@Component
public class GameDataCatalog {

    private final ObjectMapper objectMapper;
    private final JsonNode monsters;
    private final JsonNode equipmentBase;
    private final JsonNode jewelry;
    private final JsonNode enhanceRules;

    public GameDataCatalog(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
        this.monsters = load("data/monsters.json");
        this.equipmentBase = load("data/equipment_base.json");
        this.jewelry = load("data/jewelry.json");
        this.enhanceRules = load("data/enhance_rules.json");
    }

    public JsonNode getMonster(String monsterId) {
        JsonNode node = monsters.get(monsterId);
        if (node == null || node.isMissingNode()) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "unknown monster");
        }
        return node;
    }

    public String getMonsterType(String monsterId) {
        return getMonster(monsterId).path("type").asText("normal");
    }

    public int getMonsterLevel(String monsterId) {
        return getMonster(monsterId).path("level").asInt(1);
    }

    public boolean monsterInDungeon(String monsterId, String dungeonId) {
        JsonNode dungeons = getMonster(monsterId).path("dungeons");
        if (!dungeons.isArray()) {
            return false;
        }
        for (JsonNode dungeon : dungeons) {
            if (dungeonId.equals(dungeon.asText())) {
                return true;
            }
        }
        return false;
    }

    public JsonNode getEnhanceRules() {
        return enhanceRules;
    }

    public JsonNode getJewelryConfig() {
        return jewelry;
    }

    public List<JsonNode> listEquipmentBasesByTier(String tier) {
        List<JsonNode> result = new ArrayList<>();
        Iterator<Map.Entry<String, JsonNode>> fields = equipmentBase.fields();
        while (fields.hasNext()) {
            JsonNode base = fields.next().getValue();
            if (tier.equals(base.path("drop_tier").asText())) {
                result.add(base);
            }
        }
        return result;
    }

    public List<String> listJewelryLineIds() {
        return listObjectKeys(jewelry.path("lines"));
    }

    public List<String> listNecklaceLineIds() {
        return listObjectKeys(jewelry.path("necklace_lines"));
    }

    public JsonNode getJewelryLine(String lineId) {
        JsonNode line = jewelry.path("lines").path(lineId);
        if (line.isMissingNode() || line.isEmpty()) {
            throw new BusinessException(ErrorCode.INTERNAL_ERROR, "jewelry line missing");
        }
        return line;
    }

    public JsonNode getNecklaceLine(String lineId) {
        JsonNode line = jewelry.path("necklace_lines").path(lineId);
        if (line.isMissingNode() || line.isEmpty()) {
            throw new BusinessException(ErrorCode.INTERNAL_ERROR, "necklace line missing");
        }
        return line;
    }

    @SuppressWarnings("unchecked")
    public Map<String, Object> jsonToMap(JsonNode node) {
        return objectMapper.convertValue(node, Map.class);
    }

    private List<String> listObjectKeys(JsonNode node) {
        List<String> keys = new ArrayList<>();
        if (node == null || !node.isObject()) {
            return keys;
        }
        Iterator<String> names = node.fieldNames();
        while (names.hasNext()) {
            keys.add(names.next());
        }
        return keys;
    }

    private JsonNode load(String path) {
        try (InputStream input = new ClassPathResource(path).getInputStream()) {
            return objectMapper.readTree(input);
        } catch (IOException e) {
            throw new BusinessException(ErrorCode.INTERNAL_ERROR, "failed to load " + path);
        }
    }
}
