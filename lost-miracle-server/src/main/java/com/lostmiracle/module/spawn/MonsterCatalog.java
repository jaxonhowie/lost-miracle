package com.lostmiracle.module.spawn;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.lostmiracle.common.BusinessException;
import com.lostmiracle.common.ErrorCode;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

@Component
public class MonsterCatalog {

    private final JsonNode monsters;

    public MonsterCatalog(ObjectMapper objectMapper) {
        this.monsters = load(objectMapper);
    }

    public List<String> listDungeonIds() {
        Set<String> dungeonIds = new LinkedHashSet<>();
        monsters.fields().forEachRemaining(entry -> {
            JsonNode dungeons = entry.getValue().path("dungeons");
            if (dungeons.isArray()) {
                dungeons.forEach(node -> dungeonIds.add(node.asText()));
            }
        });
        return new ArrayList<>(dungeonIds);
    }

    public List<String> listMonsterIds(String dungeonId, String type) {
        List<String> ids = new ArrayList<>();
        monsters.fields().forEachRemaining(entry -> {
            JsonNode monster = entry.getValue();
            if (!type.equals(monster.path("type").asText())) {
                return;
            }
            JsonNode dungeons = monster.path("dungeons");
            if (!dungeons.isArray()) {
                return;
            }
            for (JsonNode dungeon : dungeons) {
                if (dungeonId.equals(dungeon.asText())) {
                    ids.add(entry.getKey());
                    break;
                }
            }
        });
        return ids;
    }

    public String getBossId(String dungeonId) {
        List<String> bosses = listMonsterIds(dungeonId, SpawnConstants.SPAWN_BOSS);
        if (bosses.isEmpty()) {
            throw new BusinessException(ErrorCode.INTERNAL_ERROR, "boss not configured for dungeon " + dungeonId);
        }
        return bosses.get(0);
    }

    private JsonNode load(ObjectMapper objectMapper) {
        try (InputStream input = new ClassPathResource("data/monsters.json").getInputStream()) {
            return objectMapper.readTree(input);
        } catch (IOException e) {
            throw new BusinessException(ErrorCode.INTERNAL_ERROR, "failed to load monsters.json");
        }
    }
}
