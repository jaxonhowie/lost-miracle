package com.lostmiracle.module.save.util;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;

public final class DefaultSaveFactory {

    private DefaultSaveFactory() {
    }

    public static String createNewSaveJson(ObjectMapper objectMapper) {
        try {
            ObjectNode root = objectMapper.createObjectNode();
            ObjectNode player = root.putObject("player");
            player.put("level", 1);
            player.put("exp", 0);
            player.put("gold", 0);
            player.put("enhance_stone", 0);
            player.put("blessed_enhance_stone", 0);
            player.put("jewelry_enhance_stone", 0);
            player.put("blessed_jewelry_enhance_stone", 0);
            player.put("health_potion", 0);
            player.putObject("base_stats");
            ObjectNode primary = player.putObject("primary_stats");
            primary.put("STR", 10);
            primary.put("AGI", 3);
            primary.put("INT", 3);
            player.put("class", "warrior");
            player.set("altar_buffs", objectMapper.createArrayNode());
            player.put("battle_roar_remaining", 0);
            player.put("battle_roar_atk_spd_percent", 0);

            ObjectNode equipment = root.putObject("equipment");
            equipment.put("weapon", "");
            equipment.put("helmet", "");
            equipment.put("armor", "");
            equipment.put("legs", "");
            equipment.put("gloves", "");
            equipment.put("ring_left", "");
            equipment.put("ring_right", "");
            equipment.put("necklace", "");

            root.set("inventory", objectMapper.createArrayNode());

            ObjectNode dungeon = root.putObject("dungeon");
            dungeon.put("normal_kill_count", 0);
            dungeon.put("elite_kill_count", 0);
            dungeon.put("boss_kill_count", 0);

            ObjectNode world = root.putObject("world");
            world.put("current_dungeon_id", "bone_crypt");
            world.put("auto_battle", false);

            return objectMapper.writeValueAsString(root);
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("failed to build default save", e);
        }
    }
}
