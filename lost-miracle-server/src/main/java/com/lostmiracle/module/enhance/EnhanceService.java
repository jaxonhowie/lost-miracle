package com.lostmiracle.module.enhance;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.lostmiracle.common.BusinessException;
import com.lostmiracle.common.ErrorCode;
import com.lostmiracle.module.character.CharacterService;
import com.lostmiracle.module.character.entity.CharacterEntity;
import com.lostmiracle.module.enhance.dto.EnhanceRollRequest;
import com.lostmiracle.module.enhance.dto.EnhanceRollResponse;
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

import java.time.ZoneId;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class EnhanceService {

    private final CharacterService characterService;
    private final CharacterSaveMapper characterSaveMapper;
    private final LeaderboardService leaderboardService;
    private final PaddingPoolService paddingPoolService;
    private final EnhanceRollEngine enhanceRollEngine;
    private final ObjectMapper objectMapper;
    private final RedisLockService redisLockService;
    private final RateLimitService rateLimitService;
    private final SaveSnapshotService saveSnapshotService;
    private final TransactionTemplate transactionTemplate;

    public EnhanceService(
            CharacterService characterService,
            CharacterSaveMapper characterSaveMapper,
            LeaderboardService leaderboardService,
            PaddingPoolService paddingPoolService,
            EnhanceRollEngine enhanceRollEngine,
            ObjectMapper objectMapper,
            RedisLockService redisLockService,
            RateLimitService rateLimitService,
            SaveSnapshotService saveSnapshotService,
            TransactionTemplate transactionTemplate
    ) {
        this.characterService = characterService;
        this.characterSaveMapper = characterSaveMapper;
        this.leaderboardService = leaderboardService;
        this.paddingPoolService = paddingPoolService;
        this.enhanceRollEngine = enhanceRollEngine;
        this.objectMapper = objectMapper;
        this.redisLockService = redisLockService;
        this.rateLimitService = rateLimitService;
        this.saveSnapshotService = saveSnapshotService;
        this.transactionTemplate = transactionTemplate;
    }

    public EnhanceRollResponse roll(long userId, long characterId, EnhanceRollRequest request) {
        String lockToken = redisLockService.acquireSaveLock(characterId);
        try {
            rateLimitService.checkEnhanceRoll(userId, characterId);
            // 事务体在锁内执行并提交；锁在事务提交后（finally）释放
            return transactionTemplate.execute(status -> rollLocked(userId, characterId, request));
        } finally {
            redisLockService.releaseSaveLock(characterId, lockToken);
        }
    }

    private EnhanceRollResponse rollLocked(long userId, long characterId, EnhanceRollRequest request) {
        SaveContext context = loadSaveContext(userId, characterId);
        requireMatchingSaveVersion(context.saveEntity(), request.saveVersion());
        Map<String, Object> equipment = requireEquipment(context.saveMap(), request.equipmentUid());
        boolean jewelry = enhanceRollEngine.isJewelry(equipment);
        int level = enhanceLevel(equipment);
        if (level >= enhanceRollEngine.maxLevel(equipment)) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "already at max enhance level");
        }

        Map<String, Object> player = requirePlayer(context.saveMap());
        deductStone(player, jewelry, request.useBlessedStone());

        double pityBonus = 0;
        if (paddingPoolService.tryConsumePity()) {
            pityBonus = paddingPoolService.getBonusRate();
        }
        EnhanceRollEngine.RollResult result = enhanceRollEngine.roll(equipment, request.useBlessedStone(), pityBonus);

        if (result.broken()) {
            int paddingContribution = PaddingPoolService.contributionForLevel(level);
            paddingPoolService.addPoints(paddingContribution);
            destroyEquipment(context.saveMap(), request.equipmentUid());
        }

        PersistResult persisted = persistSave(context, characterId);

        return new EnhanceRollResponse(
                result.success(),
                result.broken(),
                result.newLevel(),
                result.message(),
                result.gainedBlessed(),
                persisted.saveVersion(),
                persisted.serverUpdatedAt(),
                persisted.powerScore(),
                context.saveMap()
        );
    }

    private void requireMatchingSaveVersion(CharacterSaveEntity existing, Long clientVersion) {
        if (clientVersion == null || !existing.getSaveVersion().equals(clientVersion)) {
            long serverUpdatedAt = existing.getServerUpdatedAt() == null
                    ? 0L
                    : existing.getServerUpdatedAt().atZone(ZoneId.systemDefault()).toEpochSecond();
            throw new BusinessException(
                    ErrorCode.CONFLICT,
                    "save version conflict",
                    new SaveConflictResponse(existing.getSaveVersion(), serverUpdatedAt, "choose_local_or_server")
            );
        }
    }

    private SaveContext loadSaveContext(long userId, long characterId) {
        CharacterEntity character = characterService.requireOwnedCharacter(userId, characterId);
        characterService.touchLogin(character);

        CharacterSaveEntity saveEntity = characterSaveMapper.selectById(characterId);
        if (saveEntity == null) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "save not found");
        }

        try {
            @SuppressWarnings("unchecked")
            Map<String, Object> saveMap = objectMapper.readValue(saveEntity.getSaveJson(), Map.class);
            return new SaveContext(character, saveEntity, saveMap);
        } catch (JsonProcessingException e) {
            throw new BusinessException(ErrorCode.INTERNAL_ERROR, "invalid save data");
        }
    }

    private PersistResult persistSave(SaveContext context, long characterId) {
        String saveJson;
        try {
            saveJson = objectMapper.writeValueAsString(context.saveMap());
        } catch (JsonProcessingException e) {
            throw new BusinessException(ErrorCode.INTERNAL_ERROR, "invalid save data");
        }

        CharacterSaveEntity saveEntity = context.saveEntity();
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

        int powerScore = PowerScoreCalculator.calculate(objectMapper, saveJson);
        CharacterEntity character = context.character();
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
        return new PersistResult(newVersion, serverUpdatedAt, powerScore);
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> requirePlayer(Map<String, Object> saveMap) {
        Object playerObj = saveMap.get("player");
        if (!(playerObj instanceof Map<?, ?> player)) {
            throw new BusinessException(ErrorCode.INTERNAL_ERROR, "invalid save player data");
        }
        return (Map<String, Object>) player;
    }

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> requireInventory(Map<String, Object> saveMap) {
        Object inventoryObj = saveMap.get("inventory");
        if (!(inventoryObj instanceof List<?> inventory)) {
            throw new BusinessException(ErrorCode.INTERNAL_ERROR, "invalid save inventory data");
        }
        List<Map<String, Object>> result = new ArrayList<>();
        for (Object item : inventory) {
            if (item instanceof Map<?, ?> map) {
                result.add((Map<String, Object>) map);
            }
        }
        return result;
    }

    private Map<String, Object> requireEquipment(Map<String, Object> saveMap, String equipmentUid) {
        for (Map<String, Object> equipment : requireInventory(saveMap)) {
            if (equipmentUid.equals(String.valueOf(equipment.getOrDefault("uid", "")))) {
                return equipment;
            }
        }
        throw new BusinessException(ErrorCode.NOT_FOUND, "equipment not found");
    }

    private void removeInventoryItem(Map<String, Object> saveMap, String equipmentUid) {
        List<Map<String, Object>> inventory = requireInventory(saveMap);
        inventory.removeIf(item -> equipmentUid.equals(String.valueOf(item.getOrDefault("uid", ""))));
        saveMap.put("inventory", inventory);
    }

    private void destroyEquipment(Map<String, Object> saveMap, String equipmentUid) {
        Object equipmentObj = saveMap.get("equipment");
        if (equipmentObj instanceof Map<?, ?> equipped) {
            Map<String, Object> updated = new HashMap<>();
            for (Map.Entry<?, ?> entry : equipped.entrySet()) {
                String slot = String.valueOf(entry.getKey());
                String uid = String.valueOf(entry.getValue());
                updated.put(slot, equipmentUid.equals(uid) ? "" : uid);
            }
            saveMap.put("equipment", updated);
        }
        removeInventoryItem(saveMap, equipmentUid);
    }

    private void deductStone(Map<String, Object> player, boolean jewelry, boolean useBlessedStone) {
        String key = jewelry
                ? (useBlessedStone ? "blessed_jewelry_enhance_stone" : "jewelry_enhance_stone")
                : (useBlessedStone ? "blessed_enhance_stone" : "enhance_stone");
        int count = intValue(player.get(key));
        if (count < 1) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "not enough enhance stones");
        }
        player.put(key, count - 1);
    }

    private int enhanceLevel(Map<String, Object> equipment) {
        return intValue(equipment.get("enhance_level"));
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

    private record SaveContext(CharacterEntity character, CharacterSaveEntity saveEntity, Map<String, Object> saveMap) {
    }

    private record PersistResult(long saveVersion, long serverUpdatedAt, int powerScore) {
    }
}
