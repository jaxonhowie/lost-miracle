package com.lostmiracle.module.achievement;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.lostmiracle.common.BusinessException;
import com.lostmiracle.common.ErrorCode;
import com.lostmiracle.module.achievement.dto.AchievementItemResponse;
import com.lostmiracle.module.achievement.dto.AchievementListResponse;
import com.lostmiracle.module.achievement.dto.ClaimAchievementRequest;
import com.lostmiracle.module.achievement.dto.ClaimAchievementResponse;
import com.lostmiracle.module.achievement.entity.AchievementProgressEntity;
import com.lostmiracle.module.achievement.mapper.AchievementProgressMapper;
import com.lostmiracle.module.character.CharacterService;
import com.lostmiracle.module.character.entity.CharacterEntity;
import com.lostmiracle.module.leaderboard.LeaderboardService;
import com.lostmiracle.module.save.RateLimitService;
import com.lostmiracle.module.save.RedisLockService;
import com.lostmiracle.module.save.SaveSnapshotService;
import com.lostmiracle.module.save.dto.SaveConflictResponse;
import com.lostmiracle.module.save.entity.CharacterSaveEntity;
import com.lostmiracle.module.save.mapper.CharacterSaveMapper;
import com.lostmiracle.module.save.util.PowerScoreCalculator;
import com.lostmiracle.module.save.util.SaveChecksum;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
public class AchievementService {

    private record AchievementDef(String id, String title, String description, int target, Map<String, Object> rewards) {
    }

    private static final List<AchievementDef> DEFINITIONS = List.of(
            new AchievementDef("reach_level_5", "初出茅庐", "角色达到 5 级", 5, Map.of("gold", 100, "enhance_stone", 3)),
            new AchievementDef("reach_level_10", "小有名气", "角色达到 10 级", 10, Map.of("gold", 300, "enhance_stone", 5)),
            new AchievementDef("reach_level_20", "地牢老手", "角色达到 20 级", 20, Map.of("gold", 800, "blessed_enhance_stone", 2))
    );

    private final CharacterService characterService;
    private final CharacterSaveMapper characterSaveMapper;
    private final AchievementProgressMapper achievementProgressMapper;
    private final LeaderboardService leaderboardService;
    private final ObjectMapper objectMapper;
    private final RedisLockService redisLockService;
    private final RateLimitService rateLimitService;
    private final SaveSnapshotService saveSnapshotService;
    private final TransactionTemplate transactionTemplate;

    public AchievementService(
            CharacterService characterService,
            CharacterSaveMapper characterSaveMapper,
            AchievementProgressMapper achievementProgressMapper,
            LeaderboardService leaderboardService,
            ObjectMapper objectMapper,
            RedisLockService redisLockService,
            RateLimitService rateLimitService,
            SaveSnapshotService saveSnapshotService,
            TransactionTemplate transactionTemplate
    ) {
        this.characterService = characterService;
        this.characterSaveMapper = characterSaveMapper;
        this.achievementProgressMapper = achievementProgressMapper;
        this.leaderboardService = leaderboardService;
        this.objectMapper = objectMapper;
        this.redisLockService = redisLockService;
        this.rateLimitService = rateLimitService;
        this.saveSnapshotService = saveSnapshotService;
        this.transactionTemplate = transactionTemplate;
    }

    public AchievementListResponse list(long userId, long characterId) {
        characterService.requireOwnedCharacter(userId, characterId);
        int level = readLevel(characterId);
        Map<String, AchievementProgressEntity> progressMap = loadProgress(characterId);
        List<AchievementItemResponse> items = new ArrayList<>();
        for (AchievementDef def : DEFINITIONS) {
            AchievementProgressEntity row = progressMap.get(def.id());
            int progress = Math.min(level, def.target());
            boolean completed = level >= def.target();
            boolean claimed = row != null && row.getCompleted() != null && row.getCompleted() == 1;
            items.add(new AchievementItemResponse(
                    def.id(),
                    def.title(),
                    def.description(),
                    def.target(),
                    progress,
                    completed,
                    claimed,
                    def.rewards()
            ));
        }
        return new AchievementListResponse(items);
    }

    public ClaimAchievementResponse claim(long userId, long characterId, String achievementId, ClaimAchievementRequest request) {
        String lockToken = redisLockService.acquireSaveLock(characterId);
        try {
            rateLimitService.checkSaveUpload(userId, characterId);
            // 事务体在锁内执行并提交；锁在事务提交后（finally）释放
            return transactionTemplate.execute(status -> claimLocked(userId, characterId, achievementId, request));
        } finally {
            redisLockService.releaseSaveLock(characterId, lockToken);
        }
    }

    private ClaimAchievementResponse claimLocked(
            long userId,
            long characterId,
            String achievementId,
            ClaimAchievementRequest request
    ) {
        AchievementDef def = DEFINITIONS.stream()
                .filter(item -> item.id().equals(achievementId))
                .findFirst()
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "achievement not found"));

        CharacterEntity character = characterService.requireOwnedCharacter(userId, characterId);
        CharacterSaveEntity saveEntity = characterSaveMapper.selectById(characterId);
        if (saveEntity == null) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "save not found");
        }
        if (!saveEntity.getSaveVersion().equals(request.saveVersion())) {
            long serverUpdatedAt = saveEntity.getServerUpdatedAt() == null
                    ? 0L
                    : saveEntity.getServerUpdatedAt().atZone(ZoneId.systemDefault()).toEpochSecond();
            throw new BusinessException(
                    ErrorCode.CONFLICT,
                    "save version conflict",
                    new SaveConflictResponse(saveEntity.getSaveVersion(), serverUpdatedAt, "choose_local_or_server")
            );
        }

        AchievementProgressEntity existing = achievementProgressMapper.selectByCharacterAndAchievement(characterId, achievementId);
        if (existing != null && existing.getCompleted() != null && existing.getCompleted() == 1) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "achievement already claimed");
        }

        try {
            @SuppressWarnings("unchecked")
            Map<String, Object> saveMap = objectMapper.readValue(saveEntity.getSaveJson(), Map.class);
            int level = extractLevel(saveMap);
            if (level < def.target()) {
                throw new BusinessException(ErrorCode.BAD_REQUEST, "achievement not completed");
            }

            applyRewards(saveMap, def.rewards());
            String saveJson = objectMapper.writeValueAsString(saveMap);

            long expectedVersion = saveEntity.getSaveVersion();
            long newVersion = expectedVersion + 1;
            saveEntity.setSaveVersion(newVersion);
            saveEntity.setSaveJson(saveJson);
            saveEntity.setChecksum(SaveChecksum.sha256(saveJson));
            saveEntity.setClientUpdatedAt(System.currentTimeMillis() / 1000);
            if (characterSaveMapper.updateWithVersion(saveEntity, expectedVersion) == 0) {
                throw new BusinessException(
                        ErrorCode.CONFLICT,
                        "save version conflict",
                        new SaveConflictResponse(expectedVersion, 0L, "choose_local_or_server")
                );
            }

            AchievementProgressEntity progress = existing == null ? new AchievementProgressEntity() : existing;
            progress.setCharacterId(characterId);
            progress.setAchievementId(achievementId);
            progress.setProgress(def.target());
            progress.setCompleted(1);
            progress.setUpdatedAt(LocalDateTime.now());
            if (existing == null) {
                achievementProgressMapper.insert(progress);
            } else {
                achievementProgressMapper.updateById(progress);
            }

            int powerScore = PowerScoreCalculator.calculate(objectMapper, saveJson);
            character.setPowerScore(powerScore);
            character.setLevel(PowerScoreCalculator.extractLevel(objectMapper, saveJson));
            character.setPlayerClass(PowerScoreCalculator.extractPlayerClass(objectMapper, saveJson));
            character.setCurrentDungeonId(PowerScoreCalculator.extractDungeonId(objectMapper, saveJson));
            characterService.updateCharacterMeta(character);
            leaderboardService.submitPowerScore(character);
            saveSnapshotService.snapshotAsync(characterId, newVersion, saveJson);

            long serverUpdatedAt = saveEntity.getServerUpdatedAt() == null
                    ? System.currentTimeMillis() / 1000
                    : saveEntity.getServerUpdatedAt().atZone(ZoneId.systemDefault()).toEpochSecond();
            return new ClaimAchievementResponse(newVersion, serverUpdatedAt, powerScore, saveMap);
        } catch (JsonProcessingException e) {
            throw new BusinessException(ErrorCode.INTERNAL_ERROR, "invalid save data");
        }
    }

    private int readLevel(long characterId) {
        CharacterSaveEntity saveEntity = characterSaveMapper.selectById(characterId);
        if (saveEntity == null) {
            return 1;
        }
        try {
            @SuppressWarnings("unchecked")
            Map<String, Object> saveMap = objectMapper.readValue(saveEntity.getSaveJson(), Map.class);
            return extractLevel(saveMap);
        } catch (JsonProcessingException e) {
            return 1;
        }
    }

    @SuppressWarnings("unchecked")
    private int extractLevel(Map<String, Object> saveMap) {
        Object playerObj = saveMap.get("player");
        if (playerObj instanceof Map<?, ?> player) {
            return intValue(((Map<String, Object>) player).get("level"));
        }
        return 1;
    }

    @SuppressWarnings("unchecked")
    private void applyRewards(Map<String, Object> saveMap, Map<String, Object> rewards) {
        Object playerObj = saveMap.get("player");
        if (!(playerObj instanceof Map<?, ?> playerMap)) {
            throw new BusinessException(ErrorCode.INTERNAL_ERROR, "invalid save player data");
        }
        Map<String, Object> player = (Map<String, Object>) playerMap;
        for (Map.Entry<String, Object> entry : rewards.entrySet()) {
            player.put(entry.getKey(), intValue(player.get(entry.getKey())) + intValue(entry.getValue()));
        }
    }

    private Map<String, AchievementProgressEntity> loadProgress(long characterId) {
        List<AchievementProgressEntity> rows = achievementProgressMapper.selectByCharacterId(characterId);
        Map<String, AchievementProgressEntity> map = new LinkedHashMap<>();
        for (AchievementProgressEntity row : rows) {
            map.put(row.getAchievementId(), row);
        }
        return map;
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
}
