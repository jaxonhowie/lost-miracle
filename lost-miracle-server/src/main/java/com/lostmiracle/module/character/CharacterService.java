package com.lostmiracle.module.character;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.lostmiracle.common.BusinessException;
import com.lostmiracle.common.ErrorCode;
import com.lostmiracle.config.LostMiracleProperties;
import com.lostmiracle.module.character.dto.CharacterListResponse;
import com.lostmiracle.module.character.dto.CharacterSummaryResponse;
import com.lostmiracle.module.character.dto.CreateCharacterRequest;
import com.lostmiracle.module.character.entity.CharacterEntity;
import com.lostmiracle.module.character.mapper.CharacterMapper;
import com.lostmiracle.module.save.entity.CharacterSaveEntity;
import com.lostmiracle.module.save.mapper.CharacterSaveMapper;
import com.lostmiracle.module.save.util.DefaultSaveFactory;
import com.lostmiracle.module.save.util.PowerScoreCalculator;
import com.lostmiracle.module.save.util.SaveChecksum;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Comparator;
import java.util.List;

@Service
public class CharacterService {

    private final CharacterMapper characterMapper;
    private final CharacterSaveMapper characterSaveMapper;
    private final LostMiracleProperties properties;
    private final ObjectMapper objectMapper;

    public CharacterService(
            CharacterMapper characterMapper,
            CharacterSaveMapper characterSaveMapper,
            LostMiracleProperties properties,
            ObjectMapper objectMapper
    ) {
        this.characterMapper = characterMapper;
        this.characterSaveMapper = characterSaveMapper;
        this.properties = properties;
        this.objectMapper = objectMapper;
    }

    public CharacterListResponse listCharacters(long userId) {
        List<CharacterEntity> characters = characterMapper.selectList(new LambdaQueryWrapper<CharacterEntity>()
                .eq(CharacterEntity::getUserId, userId)
                .orderByDesc(CharacterEntity::getLastLoginAt));
        List<CharacterSummaryResponse> items = characters.stream()
                .sorted(Comparator.comparing(CharacterEntity::getLastLoginAt, Comparator.nullsLast(Comparator.reverseOrder())))
                .map(this::toSummary)
                .toList();
        return new CharacterListResponse(items, properties.getCharacter().getMaxSlotsPerUser());
    }

    @Transactional
    public CharacterSummaryResponse createCharacter(long userId, CreateCharacterRequest request) {
        Long count = characterMapper.selectCount(new LambdaQueryWrapper<CharacterEntity>()
                .eq(CharacterEntity::getUserId, userId));
        if (count != null && count >= properties.getCharacter().getMaxSlotsPerUser()) {
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

    public CharacterEntity requireOwnedCharacter(long userId, long characterId) {
        CharacterEntity character = characterMapper.selectById(characterId);
        if (character == null || !character.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.FORBIDDEN, "character not found");
        }
        return character;
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
