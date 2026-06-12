package com.lostmiracle.module.save.util;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

public final class PowerScoreCalculator {

    private PowerScoreCalculator() {
    }

    public static int calculate(ObjectMapper objectMapper, String saveJson) {
        try {
            JsonNode root = objectMapper.readTree(saveJson);
            int level = root.path("player").path("level").asInt(1);
            int enhanceSum = 0;
            int inventorySize = 0;
            JsonNode inventory = root.path("inventory");
            if (inventory.isArray()) {
                inventorySize = inventory.size();
                for (JsonNode item : inventory) {
                    enhanceSum += item.path("enhance_level").asInt(0);
                }
            }
            return level * 100 + enhanceSum * 10 + inventorySize * 5;
        } catch (Exception e) {
            return 0;
        }
    }

    public static int extractLevel(ObjectMapper objectMapper, String saveJson) {
        try {
            return objectMapper.readTree(saveJson).path("player").path("level").asInt(1);
        } catch (Exception e) {
            return 1;
        }
    }

    public static String extractPlayerClass(ObjectMapper objectMapper, String saveJson) {
        try {
            String clazz = objectMapper.readTree(saveJson).path("player").path("class").asText("warrior");
            return clazz.isBlank() ? "warrior" : clazz;
        } catch (Exception e) {
            return "warrior";
        }
    }

    public static String extractDungeonId(ObjectMapper objectMapper, String saveJson) {
        try {
            String dungeonId = objectMapper.readTree(saveJson).path("world").path("current_dungeon_id").asText("bone_crypt");
            return dungeonId.isBlank() ? "bone_crypt" : dungeonId;
        } catch (Exception e) {
            return "bone_crypt";
        }
    }
}
