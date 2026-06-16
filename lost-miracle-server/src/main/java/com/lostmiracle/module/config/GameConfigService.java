package com.lostmiracle.module.config;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.lostmiracle.common.BusinessException;
import com.lostmiracle.common.ErrorCode;
import com.lostmiracle.module.config.dto.ConfigBundleResponse;
import com.lostmiracle.module.config.dto.ConfigItemResponse;
import com.lostmiracle.module.config.dto.ConfigListResponse;
import com.lostmiracle.module.config.dto.ConfigPublishHistoryItem;
import com.lostmiracle.module.config.dto.ConfigPublishHistoryResponse;
import com.lostmiracle.module.config.dto.ConfigPublishResultResponse;
import com.lostmiracle.module.config.entity.GameConfigEntity;
import com.lostmiracle.module.config.entity.GameConfigPublishEntity;
import com.lostmiracle.module.config.mapper.GameConfigMapper;
import com.lostmiracle.module.config.mapper.GameConfigPublishMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
public class GameConfigService {

    private static final Logger log = LoggerFactory.getLogger(GameConfigService.class);

    private final GameConfigMapper gameConfigMapper;
    private final GameConfigPublishMapper gameConfigPublishMapper;
    private final ObjectMapper objectMapper;
    private final ApplicationEventPublisher eventPublisher;

    public GameConfigService(
            GameConfigMapper gameConfigMapper,
            GameConfigPublishMapper gameConfigPublishMapper,
            ObjectMapper objectMapper,
            ApplicationEventPublisher eventPublisher
    ) {
        this.gameConfigMapper = gameConfigMapper;
        this.gameConfigPublishMapper = gameConfigPublishMapper;
        this.objectMapper = objectMapper;
        this.eventPublisher = eventPublisher;
    }

    public void seedDefaultsIfEmpty() {
        if (gameConfigMapper.countAll() > 0) {
            return;
        }
        for (var entry : ConfigDefaults.all(objectMapper).entrySet()) {
            GameConfigEntity entity = new GameConfigEntity();
            entity.setConfigKey(entry.getKey());
            entity.setDescription(entry.getValue().description());
            String json = writeJson(entry.getValue().json());
            entity.setDraftJson(json);
            entity.setPublishedJson(json);
            gameConfigMapper.insert(entity);
        }
        publishInternal(0L, "bootstrap");
        log.info("seeded default game_config and published version 1");
    }

    public long currentVersion() {
        Long version = gameConfigPublishMapper.selectCurrentVersion();
        return version == null ? 0L : version;
    }

    public ConfigBundleResponse getBundle(Long since) {
        long version = currentVersion();
        if (since != null && since >= version && version > 0) {
            return new ConfigBundleResponse(version, true, Map.of());
        }
        Map<String, Object> configs = loadPublishedConfigs();
        return new ConfigBundleResponse(version, false, configs);
    }

    public ConfigListResponse listForAdmin() {
        long version = currentVersion();
        List<ConfigItemResponse> items = gameConfigMapper.selectAll().stream()
                .map(this::toItemResponse)
                .toList();
        return new ConfigListResponse(version, items);
    }

    public ConfigItemResponse getForAdmin(String configKey) {
        GameConfigEntity entity = requireConfig(configKey);
        return toItemResponse(entity);
    }

    @Transactional
    public ConfigItemResponse updateDraft(String configKey, Map<String, Object> json) {
        requireConfig(configKey);
        validateKnownKey(configKey);
        gameConfigMapper.updateDraft(configKey, writeJson(json));
        return toItemResponse(requireConfig(configKey));
    }

    @Transactional
    public ConfigPublishResultResponse publish(long gmAccountId, String note) {
        long version = publishInternal(gmAccountId, note);
        return new ConfigPublishResultResponse(version);
    }

    public ConfigPublishHistoryResponse publishHistory(int limit) {
        int safeLimit = Math.min(Math.max(limit, 1), 50);
        List<ConfigPublishHistoryItem> items = gameConfigPublishMapper.selectRecent(safeLimit).stream()
                .map(row -> new ConfigPublishHistoryItem(
                        row.getId(),
                        row.getVersion(),
                        row.getPublishedBy(),
                        row.getNote(),
                        row.getPublishedAt()
                ))
                .toList();
        return new ConfigPublishHistoryResponse(items);
    }

    @Transactional
    public ConfigPublishResultResponse rollback(long gmAccountId, long publishId) {
        GameConfigPublishEntity publish = gameConfigPublishMapper.selectById(publishId);
        if (publish == null) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "publish record not found");
        }
        Map<String, Object> snapshot = readMap(publish.getSnapshotJson());
        for (var entry : snapshot.entrySet()) {
            gameConfigMapper.restoreDraftFromPublished(entry.getKey(), writeJson(castMap(entry.getValue())));
        }
        return publish(gmAccountId, "rollback to version " + publish.getVersion());
    }

    @SuppressWarnings("unchecked")
    public Map<String, Object> getPublishedMap(String configKey) {
        GameConfigEntity entity = gameConfigMapper.selectByKey(configKey);
        if (entity == null || entity.getPublishedJson() == null) {
            return Map.of();
        }
        return readMap(entity.getPublishedJson());
    }

    private long publishInternal(long gmAccountId, String note) {
        gameConfigMapper.publishAll();
        long nextVersion = currentVersion() + 1;
        Map<String, Object> snapshot = loadPublishedConfigs();

        GameConfigPublishEntity publish = new GameConfigPublishEntity();
        publish.setVersion(nextVersion);
        publish.setPublishedBy(gmAccountId);
        publish.setNote(note);
        publish.setSnapshotJson(writeJson(snapshot));
        gameConfigPublishMapper.insert(publish);
        gameConfigPublishMapper.updateCurrentVersion(nextVersion);

        eventPublisher.publishEvent(new ConfigPublishedEvent(this, nextVersion));
        log.info("published game_config version={} by gm={}", nextVersion, gmAccountId);
        return nextVersion;
    }

    private Map<String, Object> loadPublishedConfigs() {
        Map<String, Object> configs = new LinkedHashMap<>();
        for (GameConfigEntity entity : gameConfigMapper.selectAll()) {
            if (entity.getPublishedJson() != null) {
                configs.put(entity.getConfigKey(), readMap(entity.getPublishedJson()));
            }
        }
        return configs;
    }

    private ConfigItemResponse toItemResponse(GameConfigEntity entity) {
        return new ConfigItemResponse(
                entity.getConfigKey(),
                entity.getDescription(),
                entity.getDraftJson() == null ? Map.of() : readMap(entity.getDraftJson()),
                entity.getPublishedJson() == null ? Map.of() : readMap(entity.getPublishedJson())
        );
    }

    private GameConfigEntity requireConfig(String configKey) {
        GameConfigEntity entity = gameConfigMapper.selectByKey(configKey);
        if (entity == null) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "config key not found");
        }
        return entity;
    }

    private void validateKnownKey(String configKey) {
        if (!ConfigDefaults.all(objectMapper).containsKey(configKey)) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "unknown config key");
        }
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> castMap(Object value) {
        if (value instanceof Map<?, ?> map) {
            return (Map<String, Object>) map;
        }
        throw new BusinessException(ErrorCode.BAD_REQUEST, "invalid config snapshot");
    }

    private Map<String, Object> readMap(String json) {
        try {
            return objectMapper.readValue(json, new TypeReference<Map<String, Object>>() {
            });
        } catch (JsonProcessingException e) {
            throw new BusinessException(ErrorCode.INTERNAL_ERROR, "invalid config json");
        }
    }

    private String writeJson(Object value) {
        try {
            return objectMapper.writeValueAsString(value);
        } catch (JsonProcessingException e) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "invalid config json");
        }
    }
}
