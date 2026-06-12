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
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.ZoneId;
import java.util.Map;

@Service
public class SaveService {

    private final CharacterService characterService;
    private final CharacterSaveMapper characterSaveMapper;
    private final LeaderboardService leaderboardService;
    private final LostMiracleProperties properties;
    private final ObjectMapper objectMapper;

    public SaveService(
            CharacterService characterService,
            CharacterSaveMapper characterSaveMapper,
            LeaderboardService leaderboardService,
            LostMiracleProperties properties,
            ObjectMapper objectMapper
    ) {
        this.characterService = characterService;
        this.characterSaveMapper = characterSaveMapper;
        this.leaderboardService = leaderboardService;
        this.properties = properties;
        this.objectMapper = objectMapper;
    }

    @SuppressWarnings("unchecked")
    public SaveDownloadResponse download(long userId, long characterId) {
        CharacterEntity character = characterService.requireOwnedCharacter(userId, characterId);
        characterService.touchLogin(character);

        CharacterSaveEntity save = characterSaveMapper.selectById(characterId);
        if (save == null) {
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
            throw new BusinessException(ErrorCode.INTERNAL_ERROR, "invalid save data");
        }
    }

    @Transactional
    public UploadSaveResponse upload(long userId, long characterId, UploadSaveRequest request) {
        CharacterEntity character = characterService.requireOwnedCharacter(userId, characterId);
        CharacterSaveEntity existing = characterSaveMapper.selectById(characterId);
        if (existing == null) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "save not found");
        }

        boolean force = Boolean.TRUE.equals(request.force());
        if (!force && !existing.getSaveVersion().equals(request.saveVersion())) {
            long serverUpdatedAt = existing.getServerUpdatedAt() == null
                    ? 0L
                    : existing.getServerUpdatedAt().atZone(ZoneId.systemDefault()).toEpochSecond();
            throw new BusinessException(
                    ErrorCode.CONFLICT,
                    "save version conflict",
                    new SaveConflictResponse(existing.getSaveVersion(), serverUpdatedAt, "choose_local_or_server")
            );
        }

        String saveJson;
        try {
            saveJson = objectMapper.writeValueAsString(request.save());
        } catch (JsonProcessingException e) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "invalid save json");
        }

        if (saveJson.getBytes().length > properties.getSave().getMaxBytes()) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "save too large");
        }

        long newVersion = existing.getSaveVersion() + 1;
        existing.setSaveVersion(newVersion);
        existing.setSaveJson(saveJson);
        existing.setChecksum(SaveChecksum.sha256(saveJson));
        existing.setClientUpdatedAt(request.clientUpdatedAt());
        characterSaveMapper.updateById(existing);

        int powerScore = PowerScoreCalculator.calculate(objectMapper, saveJson);
        updateCharacterFromSave(character, saveJson, powerScore);
        characterService.touchLogin(character);

        leaderboardService.submitPowerScore(character);

        long serverUpdatedAt = existing.getServerUpdatedAt() == null
                ? request.clientUpdatedAt()
                : existing.getServerUpdatedAt().atZone(ZoneId.systemDefault()).toEpochSecond();

        return new UploadSaveResponse(characterId, newVersion, serverUpdatedAt, powerScore);
    }

    private void updateCharacterFromSave(CharacterEntity character, String saveJson, int powerScore) {
        character.setPowerScore(powerScore);
        character.setLevel(PowerScoreCalculator.extractLevel(objectMapper, saveJson));
        character.setPlayerClass(PowerScoreCalculator.extractPlayerClass(objectMapper, saveJson));
        character.setCurrentDungeonId(PowerScoreCalculator.extractDungeonId(objectMapper, saveJson));
        characterService.updateCharacterMeta(character);
    }
}
