package com.lostmiracle.module.save;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.lostmiracle.common.BusinessException;
import com.lostmiracle.common.ErrorCode;
import com.lostmiracle.config.LostMiracleProperties;
import com.lostmiracle.module.character.CharacterService;
import com.lostmiracle.module.character.entity.CharacterEntity;
import com.lostmiracle.module.leaderboard.LeaderboardService;
import com.lostmiracle.module.save.dto.SaveConflictResponse;
import com.lostmiracle.module.save.dto.SaveDownloadResponse;
import com.lostmiracle.module.save.dto.UploadSaveRequest;
import com.lostmiracle.module.save.dto.UploadSaveResponse;
import com.lostmiracle.module.save.entity.CharacterSaveEntity;
import com.lostmiracle.module.save.mapper.CharacterSaveMapper;
import com.lostmiracle.module.save.util.PowerScoreCalculator;
import com.lostmiracle.module.save.util.SaveChecksum;
import com.lostmiracle.module.save.util.SaveValidator;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.ZoneId;
import java.util.Map;

@Service
public class SaveService {

    private static final Logger log = LoggerFactory.getLogger(SaveService.class);

    private final CharacterService characterService;
    private final CharacterSaveMapper characterSaveMapper;
    private final LeaderboardService leaderboardService;
    private final LostMiracleProperties properties;
    private final ObjectMapper objectMapper;
    private final RedisLockService redisLockService;
    private final RateLimitService rateLimitService;
    private final SaveSnapshotService saveSnapshotService;

    public SaveService(
            CharacterService characterService,
            CharacterSaveMapper characterSaveMapper,
            LeaderboardService leaderboardService,
            LostMiracleProperties properties,
            ObjectMapper objectMapper,
            RedisLockService redisLockService,
            RateLimitService rateLimitService,
            SaveSnapshotService saveSnapshotService
    ) {
        this.characterService = characterService;
        this.characterSaveMapper = characterSaveMapper;
        this.leaderboardService = leaderboardService;
        this.properties = properties;
        this.objectMapper = objectMapper;
        this.redisLockService = redisLockService;
        this.rateLimitService = rateLimitService;
        this.saveSnapshotService = saveSnapshotService;
    }

    @SuppressWarnings("unchecked")
    public SaveDownloadResponse download(long userId, long characterId) {
        CharacterEntity character = characterService.requireOwnedCharacter(userId, characterId);
        characterService.touchLogin(character);

        CharacterSaveEntity save = characterSaveMapper.selectById(characterId);
        if (save == null) {
            log.warn("save download missing userId={} characterId={}", userId, characterId);
            throw new BusinessException(ErrorCode.NOT_FOUND, "save not found");
        }
        try {
            Map<String, Object> saveMap = objectMapper.readValue(save.getSaveJson(), Map.class);
            return new SaveDownloadResponse(
                    characterId,
                    save.getSaveVersion(),
                    save.getClientUpdatedAt(),
                    saveMap
            );
        } catch (JsonProcessingException e) {
            log.error("save download json invalid characterId={}", characterId, e);
            throw new BusinessException(ErrorCode.INTERNAL_ERROR, "invalid save data");
        }
    }

    @Transactional
    public UploadSaveResponse upload(long userId, long characterId, UploadSaveRequest request) {
        log.debug("save upload begin userId={} characterId={} clientVersion={}", userId, characterId, request.saveVersion());
        String lockToken = redisLockService.acquireSaveLock(characterId);
        try {
            rateLimitService.checkSaveUpload(userId, characterId);
            return uploadLocked(userId, characterId, request);
        } finally {
            redisLockService.releaseSaveLock(characterId, lockToken);
        }
    }

    private UploadSaveResponse uploadLocked(long userId, long characterId, UploadSaveRequest request) {
        CharacterEntity character = characterService.requireOwnedCharacter(userId, characterId);
        CharacterSaveEntity existing = characterSaveMapper.selectById(characterId);
        if (existing == null) {
            log.warn("save upload missing userId={} characterId={}", userId, characterId);
            throw new BusinessException(ErrorCode.NOT_FOUND, "save not found");
        }

        boolean force = Boolean.TRUE.equals(request.force());
        if (!force && !existing.getSaveVersion().equals(request.saveVersion())) {
            log.warn(
                    "save version conflict userId={} characterId={} clientVersion={} serverVersion={}",
                    userId,
                    characterId,
                    request.saveVersion(),
                    existing.getSaveVersion()
            );
            long serverUpdatedAt = existing.getServerUpdatedAt() == null
                    ? 0L
                    : existing.getServerUpdatedAt().atZone(ZoneId.systemDefault()).toEpochSecond();
            throw new BusinessException(
                    ErrorCode.CONFLICT,
                    "save version conflict",
                    new SaveConflictResponse(existing.getSaveVersion(), serverUpdatedAt, "choose_local_or_server")
            );
        }

        SaveValidator.validate(request.save());

        String saveJson;
        try {
            saveJson = objectMapper.writeValueAsString(request.save());
        } catch (JsonProcessingException e) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "invalid save json");
        }

        if (saveJson.getBytes().length > properties.getSave().getMaxBytes()) {
            log.warn(
                    "save too large userId={} characterId={} bytes={} limit={}",
                    userId,
                    characterId,
                    saveJson.getBytes().length,
                    properties.getSave().getMaxBytes()
            );
            throw new BusinessException(ErrorCode.BAD_REQUEST, "save too large");
        }

        String checksum = SaveChecksum.sha256(saveJson);
        long newVersion = existing.getSaveVersion() + 1;
        existing.setSaveVersion(newVersion);
        existing.setSaveJson(saveJson);
        existing.setChecksum(checksum);
        existing.setClientUpdatedAt(request.clientUpdatedAt());
        characterSaveMapper.updateById(existing);

        int powerScore = PowerScoreCalculator.calculate(objectMapper, saveJson);
        updateCharacterFromSave(character, saveJson, powerScore);
        characterService.touchLogin(character);

        leaderboardService.submitPowerScore(character);
        saveSnapshotService.snapshotAsync(characterId, newVersion, saveJson);

        long serverUpdatedAt = existing.getServerUpdatedAt() == null
                ? request.clientUpdatedAt()
                : existing.getServerUpdatedAt().atZone(ZoneId.systemDefault()).toEpochSecond();

        return new UploadSaveResponse(characterId, newVersion, serverUpdatedAt, powerScore);
    }

    @Transactional
    public UploadSaveResponse adminForceUpload(long characterId, Map<String, Object> save, long clientUpdatedAt) {
        CharacterEntity character = characterService.requireCharacter(characterId);
        CharacterSaveEntity existing = characterSaveMapper.selectById(characterId);
        if (existing == null) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "save not found");
        }

        SaveValidator.validate(save);

        String saveJson;
        try {
            saveJson = objectMapper.writeValueAsString(save);
        } catch (JsonProcessingException e) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "invalid save json");
        }

        if (saveJson.getBytes().length > properties.getSave().getMaxBytes()) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "save too large");
        }

        String checksum = SaveChecksum.sha256(saveJson);
        long newVersion = existing.getSaveVersion() + 1;
        existing.setSaveVersion(newVersion);
        existing.setSaveJson(saveJson);
        existing.setChecksum(checksum);
        existing.setClientUpdatedAt(clientUpdatedAt);
        characterSaveMapper.updateById(existing);

        int powerScore = PowerScoreCalculator.calculate(objectMapper, saveJson);
        updateCharacterFromSave(character, saveJson, powerScore);
        characterService.touchLogin(character);

        leaderboardService.submitPowerScore(character);
        saveSnapshotService.snapshotAsync(characterId, newVersion, saveJson);

        long serverUpdatedAt = existing.getServerUpdatedAt() == null
                ? clientUpdatedAt
                : existing.getServerUpdatedAt().atZone(ZoneId.systemDefault()).toEpochSecond();

        return new UploadSaveResponse(characterId, newVersion, serverUpdatedAt, powerScore);
    }

    public String readSaveChecksum(long characterId) {
        CharacterSaveEntity existing = characterSaveMapper.selectById(characterId);
        if (existing == null) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "save not found");
        }
        return existing.getChecksum();
    }

    @SuppressWarnings("unchecked")
    public Map<String, Object> readSaveMap(long characterId) {
        CharacterSaveEntity existing = characterSaveMapper.selectById(characterId);
        if (existing == null) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "save not found");
        }
        try {
            return objectMapper.readValue(existing.getSaveJson(), Map.class);
        } catch (JsonProcessingException e) {
            throw new BusinessException(ErrorCode.INTERNAL_ERROR, "invalid save data");
        }
    }

    private void updateCharacterFromSave(CharacterEntity character, String saveJson, int powerScore) {
        character.setPowerScore(powerScore);
        character.setLevel(PowerScoreCalculator.extractLevel(objectMapper, saveJson));
        character.setPlayerClass(PowerScoreCalculator.extractPlayerClass(objectMapper, saveJson));
        character.setCurrentDungeonId(PowerScoreCalculator.extractDungeonId(objectMapper, saveJson));
        characterService.updateCharacterMeta(character);
    }
}
