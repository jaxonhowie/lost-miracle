package com.lostmiracle.module.spawn;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.lostmiracle.common.BusinessException;
import com.lostmiracle.common.ErrorCode;
import com.lostmiracle.module.character.CharacterService;
import com.lostmiracle.module.character.entity.CharacterEntity;
import com.lostmiracle.module.leaderboard.LeaderboardService;
import com.lostmiracle.module.loot.LootEngine;
import com.lostmiracle.module.loot.LootRollResult;
import com.lostmiracle.module.loot.GameDataCatalog;
import com.lostmiracle.module.loot.SaveRewardApplier;
import com.lostmiracle.module.save.RateLimitService;
import com.lostmiracle.module.save.RedisLockService;
import com.lostmiracle.module.save.SaveSnapshotService;
import com.lostmiracle.module.save.dto.SaveConflictResponse;
import com.lostmiracle.module.save.entity.CharacterSaveEntity;
import com.lostmiracle.module.save.mapper.CharacterSaveMapper;
import com.lostmiracle.module.save.util.PowerScoreCalculator;
import com.lostmiracle.module.save.util.SaveChecksum;
import com.lostmiracle.module.spawn.dto.SpawnSettleRequest;
import com.lostmiracle.module.spawn.dto.SpawnSettleResponse;
import com.lostmiracle.module.spawn.entity.DungeonSpawnSlotEntity;
import com.lostmiracle.module.spawn.mapper.DungeonSpawnMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Instant;
import java.time.ZoneId;
import java.util.Map;

@Service
public class SpawnSettleService {

    private final CharacterService characterService;
    private final CharacterSaveMapper characterSaveMapper;
    private final DungeonSpawnMapper dungeonSpawnMapper;
    private final LeaderboardService leaderboardService;
    private final GameDataCatalog gameDataCatalog;
    private final LootEngine lootEngine;
    private final ObjectMapper objectMapper;
    private final RedisLockService redisLockService;
    private final RateLimitService rateLimitService;
    private final SaveSnapshotService saveSnapshotService;
    private final TransactionTemplate transactionTemplate;

    public SpawnSettleService(
            CharacterService characterService,
            CharacterSaveMapper characterSaveMapper,
            DungeonSpawnMapper dungeonSpawnMapper,
            LeaderboardService leaderboardService,
            GameDataCatalog gameDataCatalog,
            LootEngine lootEngine,
            ObjectMapper objectMapper,
            RedisLockService redisLockService,
            RateLimitService rateLimitService,
            SaveSnapshotService saveSnapshotService,
            TransactionTemplate transactionTemplate
    ) {
        this.characterService = characterService;
        this.characterSaveMapper = characterSaveMapper;
        this.dungeonSpawnMapper = dungeonSpawnMapper;
        this.leaderboardService = leaderboardService;
        this.gameDataCatalog = gameDataCatalog;
        this.lootEngine = lootEngine;
        this.objectMapper = objectMapper;
        this.redisLockService = redisLockService;
        this.rateLimitService = rateLimitService;
        this.saveSnapshotService = saveSnapshotService;
        this.transactionTemplate = transactionTemplate;
    }

    public SpawnSettleResponse settle(
            long userId,
            long characterId,
            String dungeonId,
            long slotId,
            SpawnSettleRequest request
    ) {
        String lockToken = redisLockService.acquireSaveLock(characterId);
        try {
            rateLimitService.checkSaveUpload(userId, characterId);
            return transactionTemplate.execute(status -> settleLocked(
                    userId,
                    characterId,
                    dungeonId,
                    slotId,
                    request
            ));
        } finally {
            redisLockService.releaseSaveLock(characterId, lockToken);
        }
    }

    private SpawnSettleResponse settleLocked(
            long userId,
            long characterId,
            String dungeonId,
            long slotId,
            SpawnSettleRequest request
    ) {
        CharacterEntity character = characterService.requireOwnedCharacter(userId, characterId);
        DungeonSpawnSlotEntity slot = requireOwnedSlot(characterId, slotId);
        if (!dungeonId.equals(slot.getDungeonId())) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "dungeon mismatch");
        }

        validateMonster(request.monsterId(), dungeonId, slot.getSpawnType());

        CharacterSaveEntity saveEntity = characterSaveMapper.selectById(characterId);
        if (saveEntity == null) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "save not found");
        }
        if (!saveEntity.getSaveVersion().equals(request.saveVersion())) {
            throw saveVersionConflict(saveEntity);
        }

        Map<String, Object> saveMap = readSaveMap(saveEntity.getSaveJson());
        LootRollResult rewards = lootEngine.rollBattleRewards(dungeonId, request.monsterId());
        SaveRewardApplier.apply(saveMap, rewards);

        String saveJson = writeSaveJson(saveMap);
        long expectedVersion = saveEntity.getSaveVersion();
        long newVersion = expectedVersion + 1;
        saveEntity.setSaveVersion(newVersion);
        saveEntity.setSaveJson(saveJson);
        saveEntity.setChecksum(SaveChecksum.sha256(saveJson));
        saveEntity.setClientUpdatedAt(System.currentTimeMillis() / 1000);
        if (characterSaveMapper.updateWithVersion(saveEntity, expectedVersion) == 0) {
            throw saveVersionConflict(characterSaveMapper.selectById(characterId));
        }

        long respawnAt = Instant.now().getEpochSecond() + cooldownFor(slot.getSpawnType());
        if (dungeonSpawnMapper.applyDefeatCooldown(slotId, characterId, respawnAt) == 0) {
            throw new BusinessException(ErrorCode.CONFLICT, "spawn slot state changed");
        }

        int powerScore = PowerScoreCalculator.calculate(objectMapper, saveJson);
        character.setPowerScore(powerScore);
        character.setLevel(PowerScoreCalculator.extractLevel(objectMapper, saveJson));
        character.setPlayerClass(PowerScoreCalculator.extractPlayerClass(objectMapper, saveJson));
        character.setCurrentDungeonId(PowerScoreCalculator.extractDungeonId(objectMapper, saveJson));
        characterService.updateCharacterMeta(character);
        characterService.touchLogin(character);
        leaderboardService.submitPowerScore(character);
        saveSnapshotService.snapshotAsync(characterId, newVersion, saveJson);

        long serverUpdatedAt = saveEntity.getServerUpdatedAt() == null
                ? System.currentTimeMillis() / 1000
                : saveEntity.getServerUpdatedAt().atZone(ZoneId.systemDefault()).toEpochSecond();

        return new SpawnSettleResponse(
                newVersion,
                serverUpdatedAt,
                powerScore,
                rewards.exp(),
                rewards.gold(),
                rewards.items(),
                saveMap
        );
    }

    private void validateMonster(String monsterId, String dungeonId, String spawnType) {
        if (!gameDataCatalog.monsterInDungeon(monsterId, dungeonId)) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "monster not in dungeon");
        }
        String monsterType = gameDataCatalog.getMonsterType(monsterId);
        if (!spawnType.equals(monsterType)) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "monster type mismatch");
        }
    }

    private DungeonSpawnSlotEntity requireOwnedSlot(long characterId, long slotId) {
        DungeonSpawnSlotEntity slot = dungeonSpawnMapper.selectById(slotId);
        if (slot == null) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "spawn slot not found");
        }
        if (slot.getEngagedCharacterId() == null || !slot.getEngagedCharacterId().equals(characterId)) {
            throw new BusinessException(ErrorCode.FORBIDDEN, "spawn slot not engaged by character");
        }
        return slot;
    }

    private BusinessException saveVersionConflict(CharacterSaveEntity existing) {
        if (existing == null) {
            return new BusinessException(ErrorCode.CONFLICT, "save version conflict");
        }
        long serverUpdatedAt = existing.getServerUpdatedAt() == null
                ? 0L
                : existing.getServerUpdatedAt().atZone(ZoneId.systemDefault()).toEpochSecond();
        return new BusinessException(
                ErrorCode.CONFLICT,
                "save version conflict",
                new SaveConflictResponse(existing.getSaveVersion(), serverUpdatedAt, "choose_local_or_server")
        );
    }

    private Map<String, Object> readSaveMap(String saveJson) {
        try {
            return objectMapper.readValue(saveJson, new TypeReference<>() {
            });
        } catch (JsonProcessingException e) {
            throw new BusinessException(ErrorCode.INTERNAL_ERROR, "invalid save data");
        }
    }

    private String writeSaveJson(Map<String, Object> saveMap) {
        try {
            return objectMapper.writeValueAsString(saveMap);
        } catch (JsonProcessingException e) {
            throw new BusinessException(ErrorCode.INTERNAL_ERROR, "invalid save data");
        }
    }

    private int cooldownFor(String spawnType) {
        return switch (spawnType) {
            case SpawnConstants.SPAWN_NORMAL -> SpawnConstants.NORMAL_COOLDOWN_SEC;
            case SpawnConstants.SPAWN_ELITE -> SpawnConstants.ELITE_COOLDOWN_SEC;
            case SpawnConstants.SPAWN_BOSS -> SpawnConstants.BOSS_COOLDOWN_SEC;
            default -> SpawnConstants.NORMAL_COOLDOWN_SEC;
        };
    }
}
