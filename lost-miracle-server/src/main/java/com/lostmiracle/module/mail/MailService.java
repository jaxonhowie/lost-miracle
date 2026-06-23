package com.lostmiracle.module.mail;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.lostmiracle.common.BusinessException;
import com.lostmiracle.common.ErrorCode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import com.lostmiracle.module.character.CharacterService;
import com.lostmiracle.module.character.entity.CharacterEntity;
import com.lostmiracle.module.leaderboard.LeaderboardService;
import com.lostmiracle.module.mail.dto.ClaimMailRequest;
import com.lostmiracle.module.mail.dto.ClaimMailResponse;
import com.lostmiracle.module.mail.dto.MailListResponse;
import com.lostmiracle.module.mail.dto.MailResponse;
import com.lostmiracle.module.mail.entity.MailEntity;
import com.lostmiracle.module.mail.mapper.MailMapper;
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
import java.util.Collections;
import java.util.List;
import java.util.Map;

@Service
public class MailService {

    private static final Logger log = LoggerFactory.getLogger(MailService.class);

    private final CharacterService characterService;
    private final CharacterSaveMapper characterSaveMapper;
    private final MailMapper mailMapper;
    private final LeaderboardService leaderboardService;
    private final ObjectMapper objectMapper;
    private final RedisLockService redisLockService;
    private final RateLimitService rateLimitService;
    private final SaveSnapshotService saveSnapshotService;
    private final TransactionTemplate transactionTemplate;

    public MailService(
            CharacterService characterService,
            CharacterSaveMapper characterSaveMapper,
            MailMapper mailMapper,
            LeaderboardService leaderboardService,
            ObjectMapper objectMapper,
            RedisLockService redisLockService,
            RateLimitService rateLimitService,
            SaveSnapshotService saveSnapshotService,
            TransactionTemplate transactionTemplate
    ) {
        this.characterService = characterService;
        this.characterSaveMapper = characterSaveMapper;
        this.mailMapper = mailMapper;
        this.leaderboardService = leaderboardService;
        this.objectMapper = objectMapper;
        this.redisLockService = redisLockService;
        this.rateLimitService = rateLimitService;
        this.saveSnapshotService = saveSnapshotService;
        this.transactionTemplate = transactionTemplate;
    }

    public MailListResponse listMail(long userId, long characterId) {
        characterService.requireOwnedCharacter(userId, characterId);
        List<MailEntity> mails = mailMapper.selectByCharacterId(characterId);
        return new MailListResponse(mails.stream().map(this::toResponse).toList());
    }

    public ClaimMailResponse claim(long userId, long characterId, long mailId, ClaimMailRequest request) {
        String lockToken = redisLockService.acquireSaveLock(characterId);
        try {
            rateLimitService.checkSaveUpload(userId, characterId);
            // 事务体在锁内执行并提交；锁在事务提交后（finally）释放
            return transactionTemplate.execute(status -> claimLocked(userId, characterId, mailId, request));
        } finally {
            redisLockService.releaseSaveLock(characterId, lockToken);
        }
    }

    private ClaimMailResponse claimLocked(long userId, long characterId, long mailId, ClaimMailRequest request) {
        CharacterEntity character = characterService.requireOwnedCharacter(userId, characterId);
        MailEntity mail = mailMapper.selectById(mailId);
        if (mail == null || !mail.getCharacterId().equals(characterId)) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "mail not found");
        }
        if (mail.getClaimed() != null && mail.getClaimed() == 1) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "mail already claimed");
        }

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

        try {
            @SuppressWarnings("unchecked")
            Map<String, Object> saveMap = objectMapper.readValue(saveEntity.getSaveJson(), Map.class);
            applyAttachments(saveMap, parseAttachments(mail.getAttachments()));
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

            mailMapper.updateClaimed(mailId, 1, LocalDateTime.now());

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
            return new ClaimMailResponse(newVersion, serverUpdatedAt, powerScore, saveMap);
        } catch (JsonProcessingException e) {
            throw new BusinessException(ErrorCode.INTERNAL_ERROR, "invalid save data");
        }
    }

    @SuppressWarnings("unchecked")
    private void applyAttachments(Map<String, Object> saveMap, Map<String, Object> attachments) {
        Object playerObj = saveMap.get("player");
        if (!(playerObj instanceof Map<?, ?> playerMap)) {
            throw new BusinessException(ErrorCode.INTERNAL_ERROR, "invalid save player data");
        }
        Map<String, Object> player = (Map<String, Object>) playerMap;
        for (Map.Entry<String, Object> entry : attachments.entrySet()) {
            String key = entry.getKey();
            if (!MailAttachmentPolicy.ALLOWED_KEYS.contains(key)) {
                log.warn("skipping disallowed attachment key={}", key);
                continue;
            }
            int delta = intValue(entry.getValue());
            player.put(key, intValue(player.get(key)) + delta);
        }
    }

    private Map<String, Object> parseAttachments(String attachmentsJson) {
        if (attachmentsJson == null || attachmentsJson.isBlank()) {
            return Collections.emptyMap();
        }
        try {
            return objectMapper.readValue(attachmentsJson, new TypeReference<>() {
            });
        } catch (JsonProcessingException e) {
            return Collections.emptyMap();
        }
    }

    private MailResponse toResponse(MailEntity mail) {
        long createdAt = mail.getCreatedAt() == null
                ? 0L
                : mail.getCreatedAt().atZone(ZoneId.systemDefault()).toEpochSecond();
        return new MailResponse(
                mail.getId(),
                mail.getTitle(),
                mail.getBody(),
                parseAttachments(mail.getAttachments()),
                mail.getClaimed() != null && mail.getClaimed() == 1,
                createdAt
        );
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
