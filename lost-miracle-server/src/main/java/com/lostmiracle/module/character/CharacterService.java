package com.lostmiracle.module.character;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.lostmiracle.common.BusinessException;
import com.lostmiracle.common.ErrorCode;
import com.lostmiracle.config.LostMiracleProperties;
import com.lostmiracle.module.achievement.mapper.AchievementProgressMapper;
import com.lostmiracle.module.character.dto.CharacterListResponse;
import com.lostmiracle.module.character.dto.CharacterSummaryResponse;
import com.lostmiracle.module.character.dto.CreateCharacterRequest;
import com.lostmiracle.module.character.dto.UpdateCharacterRequest;
import com.lostmiracle.module.character.entity.CharacterEntity;
import com.lostmiracle.module.character.mapper.CharacterMapper;
import com.lostmiracle.module.leaderboard.LeaderboardService;
import com.lostmiracle.module.mail.mapper.MailMapper;
import com.lostmiracle.module.save.entity.CharacterSaveEntity;
import com.lostmiracle.module.save.mapper.CharacterSaveMapper;
import com.lostmiracle.module.save.SaveSnapshotService;
import com.lostmiracle.module.save.util.DefaultSaveFactory;
import com.lostmiracle.module.save.util.PowerScoreCalculator;
import com.lostmiracle.module.save.util.SaveChecksum;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Comparator;
import java.util.List;

@Service
public class CharacterService {

    private static final Logger log = LoggerFactory.getLogger(CharacterService.class);

    private final CharacterMapper characterMapper;
    private final CharacterSaveMapper characterSaveMapper;
    private final MailMapper mailMapper;
    private final AchievementProgressMapper achievementProgressMapper;
    private final SaveSnapshotService saveSnapshotService;
    private final LeaderboardService leaderboardService;
    private final LostMiracleProperties properties;
    private final ObjectMapper objectMapper;

    public CharacterService(
            CharacterMapper characterMapper,
            CharacterSaveMapper characterSaveMapper,
            MailMapper mailMapper,
            AchievementProgressMapper achievementProgressMapper,
            SaveSnapshotService saveSnapshotService,
            LeaderboardService leaderboardService,
            LostMiracleProperties properties,
            ObjectMapper objectMapper
    ) {
        this.characterMapper = characterMapper;
        this.characterSaveMapper = characterSaveMapper;
        this.mailMapper = mailMapper;
        this.achievementProgressMapper = achievementProgressMapper;
        this.saveSnapshotService = saveSnapshotService;
        this.leaderboardService = leaderboardService;
        this.properties = properties;
        this.objectMapper = objectMapper;
    }

    public CharacterListResponse listCharacters(long userId) {
        List<CharacterEntity> characters = characterMapper.selectByUserId(userId);
        List<CharacterSummaryResponse> items = characters.stream()
                .sorted(Comparator.comparing(CharacterEntity::getLastLoginAt, Comparator.nullsLast(Comparator.reverseOrder())))
                .map(this::toSummary)
                .toList();
        return new CharacterListResponse(items, properties.getCharacter().getMaxSlotsPerUser());
    }

    @Transactional
    public CharacterSummaryResponse createCharacter(long userId, CreateCharacterRequest request) {
        long count = characterMapper.countByUserId(userId);
        if (count >= properties.getCharacter().getMaxSlotsPerUser()) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "character slot limit reached");
        }

        String saveJson = DefaultSaveFactory.createNewSaveJson(objectMapper);
        int powerScore = PowerScoreCalculator.calculate(objectMapper, saveJson);
        long nowEpoch = Instant.now().getEpochSecond();

        CharacterEntity character = new CharacterEntity();
        character.setUserId(userId);
        character.setName(request.name() == null || request.name().isBlank() ? "冒险者" : request.name().trim());
        character.setPlayerClass("warrior");
        character.setLevel(1);
        character.setPowerScore(powerScore);
        character.setCurrentDungeonId("bone_crypt");
        character.setLastLoginAt(LocalDateTime.now());
        characterMapper.insert(character);

        CharacterSaveEntity save = new CharacterSaveEntity();
        save.setCharacterId(character.getId());
        save.setSaveVersion(1L);
        save.setSaveJson(saveJson);
        save.setChecksum(SaveChecksum.sha256(saveJson));
        save.setClientUpdatedAt(nowEpoch);
        characterSaveMapper.insert(save);

        return toSummary(character);
    }

    @Transactional
    public CharacterSummaryResponse updateCharacter(long userId, long characterId, UpdateCharacterRequest request) {
        CharacterEntity character = requireOwnedCharacter(userId, characterId);
        character.setName(request.name().trim());
        characterMapper.updateById(character);
        return toSummary(character);
    }

    @Transactional
    public void deleteCharacter(long userId, long characterId) {
        requireOwnedCharacter(userId, characterId);
        log.info("delete character userId={} characterId={}", userId, characterId);
        mailMapper.deleteByCharacterId(characterId);
        achievementProgressMapper.deleteByCharacterId(characterId);
        saveSnapshotService.deleteByCharacterId(characterId);
        characterSaveMapper.deleteById(characterId);
        leaderboardService.removeCharacter(characterId);
        characterMapper.deleteById(characterId);
    }

    public CharacterEntity requireOwnedCharacter(long userId, long characterId) {
        CharacterEntity character = characterMapper.selectById(characterId);
        if (character == null || !character.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.FORBIDDEN, "character not found");
        }
        return character;
    }

    public CharacterEntity requireCharacter(long characterId) {
        CharacterEntity character = characterMapper.selectById(characterId);
        if (character == null) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "character not found");
        }
        return character;
    }

    @Transactional
    public void adminDeleteCharacter(long characterId) {
        CharacterEntity character = requireCharacter(characterId);
        deleteCharacter(character.getUserId(), characterId);
    }

    public void touchLogin(CharacterEntity character) {
        character.setLastLoginAt(LocalDateTime.now());
        characterMapper.updateById(character);
    }

    public void updateCharacterMeta(CharacterEntity character) {
        characterMapper.updateById(character);
    }

    private CharacterSummaryResponse toSummary(CharacterEntity character) {
        CharacterSaveEntity save = characterSaveMapper.selectById(character.getId());
        long saveVersion = save == null ? 0L : save.getSaveVersion();
        long lastLoginAt = character.getLastLoginAt() == null
                ? 0L
                : character.getLastLoginAt().atZone(ZoneId.systemDefault()).toEpochSecond();
        return new CharacterSummaryResponse(
                character.getId(),
                character.getName(),
                character.getPlayerClass(),
                character.getLevel(),
                character.getPowerScore(),
                character.getCurrentDungeonId(),
                lastLoginAt,
                saveVersion
        );
    }
}
