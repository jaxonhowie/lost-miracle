package com.lostmiracle.module.admin;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.lostmiracle.common.BusinessException;
import com.lostmiracle.common.ErrorCode;
import com.lostmiracle.module.admin.dto.GmBanRequest;
import com.lostmiracle.module.admin.dto.GmCharacterSaveResponse;
import com.lostmiracle.module.admin.dto.GmSaveFieldsRequest;
import com.lostmiracle.module.admin.dto.GmSavePreviewResponse;
import com.lostmiracle.module.admin.dto.GmSaveReplaceRequest;
import com.lostmiracle.module.admin.dto.GmUserDetailResponse;
import com.lostmiracle.module.admin.dto.GmUserListResponse;
import com.lostmiracle.module.admin.dto.GmUserSummaryResponse;
import com.lostmiracle.module.admin.util.GmSaveDiffHelper;
import com.lostmiracle.module.character.CharacterService;
import com.lostmiracle.module.character.dto.CharacterListResponse;
import com.lostmiracle.module.save.SaveService;
import com.lostmiracle.module.save.dto.UploadSaveResponse;
import com.lostmiracle.module.save.entity.CharacterSaveEntity;
import com.lostmiracle.module.save.mapper.CharacterSaveMapper;
import com.lostmiracle.module.save.util.SaveChecksum;
import com.lostmiracle.module.user.entity.UserEntity;
import com.lostmiracle.module.user.mapper.UserMapper;
import com.lostmiracle.security.AdminJwtTokenProvider;
import com.lostmiracle.security.GmPrincipal;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.ZoneId;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class AdminPlayerService {

    private final UserMapper userMapper;
    private final CharacterService characterService;
    private final SaveService saveService;
    private final CharacterSaveMapper characterSaveMapper;
    private final AdminJwtTokenProvider adminJwtTokenProvider;
    private final GmAuditService gmAuditService;
    private final ObjectMapper objectMapper;

    public AdminPlayerService(
            UserMapper userMapper,
            CharacterService characterService,
            SaveService saveService,
            CharacterSaveMapper characterSaveMapper,
            AdminJwtTokenProvider adminJwtTokenProvider,
            GmAuditService gmAuditService,
            ObjectMapper objectMapper
    ) {
        this.userMapper = userMapper;
        this.characterService = characterService;
        this.saveService = saveService;
        this.characterSaveMapper = characterSaveMapper;
        this.adminJwtTokenProvider = adminJwtTokenProvider;
        this.gmAuditService = gmAuditService;
        this.objectMapper = objectMapper;
    }

    public GmUserListResponse searchUsers(String query, int page, int pageSize) {
        int safePage = Math.max(page, 1);
        int safeSize = Math.min(Math.max(pageSize, 1), 50);
        String safeQuery = query == null ? "" : query.trim();
        if (safeQuery.isEmpty()) {
            return new GmUserListResponse(List.of(), 0, safePage, safeSize);
        }
        int offset = (safePage - 1) * safeSize;
        List<GmUserSummaryResponse> items = userMapper.search(safeQuery, safeSize, offset).stream()
                .map(this::toSummary)
                .toList();
        long total = userMapper.countSearch(safeQuery);
        return new GmUserListResponse(items, total, safePage, safeSize);
    }

    public GmUserDetailResponse getUser(long userId) {
        UserEntity user = requireUser(userId);
        return toDetail(user);
    }

    public CharacterListResponse listCharacters(long userId) {
        requireUser(userId);
        return characterService.listCharacters(userId);
    }

    public GmCharacterSaveResponse getSave(long characterId) {
        characterService.requireCharacter(characterId);
        CharacterSaveEntity save = characterSaveMapper.selectById(characterId);
        if (save == null) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "save not found");
        }
        Map<String, Object> saveMap = saveService.readSaveMap(characterId);
        return new GmCharacterSaveResponse(
                characterId,
                save.getSaveVersion(),
                save.getClientUpdatedAt(),
                save.getChecksum(),
                saveMap
        );
    }

    @Transactional
    public UploadSaveResponse patchSaveFields(
            GmPrincipal gm,
            long characterId,
            GmSaveFieldsRequest request,
            String ip
    ) {
        Map<String, Object> save = new HashMap<>(saveService.readSaveMap(characterId));
        @SuppressWarnings("unchecked")
        Map<String, Object> player = (Map<String, Object>) save.computeIfAbsent("player", ignored -> new HashMap<>());

        applyField(player, "gold", request.gold());
        applyField(player, "level", request.level());
        applyField(player, "exp", request.exp());
        applyField(player, "enhance_stone", request.enhanceStone());
        applyField(player, "blessed_enhance_stone", request.blessedEnhanceStone());
        applyField(player, "jewelry_enhance_stone", request.jewelryEnhanceStone());
        applyField(player, "blessed_jewelry_enhance_stone", request.blessedJewelryEnhanceStone());
        applyField(player, "health_potion", request.healthPotion());

        String beforeChecksum = saveService.readSaveChecksum(characterId);
        UploadSaveResponse result = saveService.adminForceUpload(characterId, save, Instant.now().getEpochSecond());
        String afterChecksum = saveService.readSaveChecksum(characterId);
        gmAuditService.log(
                gm.gmAccountId(),
                "SAVE_PATCH_FIELDS",
                "character",
                String.valueOf(characterId),
                Map.of(
                        "beforeChecksum", beforeChecksum,
                        "afterChecksum", afterChecksum,
                        "saveVersion", result.saveVersion()
                ),
                ip
        );
        return result;
    }

    public GmSavePreviewResponse previewSaveReplace(GmPrincipal gm, long characterId, Map<String, Object> newSave) {
        characterService.requireCharacter(characterId);
        Map<String, Object> before = saveService.readSaveMap(characterId);
        String beforeChecksum = saveService.readSaveChecksum(characterId);
        String afterChecksum = checksum(newSave);
        List<String> changes = GmSaveDiffHelper.summarize(before, newSave);
        String confirmToken = adminJwtTokenProvider.createConfirmToken(gm.gmAccountId(), characterId, afterChecksum);
        return new GmSavePreviewResponse(characterId, confirmToken, beforeChecksum, afterChecksum, changes);
    }

    @Transactional
    public UploadSaveResponse replaceSave(GmPrincipal gm, long characterId, GmSaveReplaceRequest request, String ip) {
        AdminJwtTokenProvider.ConfirmTokenClaims claims = adminJwtTokenProvider.parseConfirmToken(request.confirmToken());
        if (claims.gmAccountId() != gm.gmAccountId()) {
            throw new BusinessException(ErrorCode.FORBIDDEN, "confirm token gm mismatch");
        }
        if (claims.characterId() != characterId) {
            throw new BusinessException(ErrorCode.FORBIDDEN, "confirm token character mismatch");
        }
        String afterChecksum = checksum(request.save());
        if (!afterChecksum.equals(claims.saveChecksum())) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "save content changed since preview");
        }

        String beforeChecksum = saveService.readSaveChecksum(characterId);
        UploadSaveResponse result = saveService.adminForceUpload(characterId, request.save(), Instant.now().getEpochSecond());
        gmAuditService.log(
                gm.gmAccountId(),
                "SAVE_REPLACE",
                "character",
                String.valueOf(characterId),
                Map.of(
                        "reason", request.reason(),
                        "beforeChecksum", beforeChecksum,
                        "afterChecksum", afterChecksum
                ),
                ip
        );
        return result;
    }

    @Transactional
    public void banUser(GmPrincipal gm, long userId, GmBanRequest request, String ip) {
        UserEntity user = requireUser(userId);
        if (user.getStatus() != null && user.getStatus() == 0) {
            return;
        }
        userMapper.updateStatus(userId, 0);
        gmAuditService.log(
                gm.gmAccountId(),
                "USER_BAN",
                "user",
                String.valueOf(userId),
                Map.of("reason", request.reason()),
                ip
        );
    }

    @Transactional
    public void unbanUser(GmPrincipal gm, long userId, String ip) {
        requireUser(userId);
        userMapper.updateStatus(userId, 1);
        gmAuditService.log(
                gm.gmAccountId(),
                "USER_UNBAN",
                "user",
                String.valueOf(userId),
                Map.of(),
                ip
        );
    }

    @Transactional
    public void deleteCharacter(GmPrincipal gm, long characterId, String ip) {
        characterService.adminDeleteCharacter(characterId);
        gmAuditService.log(
                gm.gmAccountId(),
                "CHARACTER_DELETE",
                "character",
                String.valueOf(characterId),
                Map.of(),
                ip
        );
    }

    private UserEntity requireUser(long userId) {
        UserEntity user = userMapper.selectById(userId);
        if (user == null) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "user not found");
        }
        return user;
    }

    private void applyField(Map<String, Object> player, String key, Object value) {
        if (value != null) {
            player.put(key, value);
        }
    }

    private String checksum(Map<String, Object> save) {
        try {
            return SaveChecksum.sha256(objectMapper.writeValueAsString(save));
        } catch (JsonProcessingException e) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "invalid save json");
        }
    }

    private GmUserSummaryResponse toSummary(UserEntity user) {
        long createdAt = user.getCreatedAt() == null
                ? 0L
                : user.getCreatedAt().atZone(ZoneId.systemDefault()).toEpochSecond();
        return new GmUserSummaryResponse(
                user.getId(),
                user.getUsername(),
                user.getStatus() == null ? 1 : user.getStatus(),
                createdAt
        );
    }

    private GmUserDetailResponse toDetail(UserEntity user) {
        long createdAt = user.getCreatedAt() == null
                ? 0L
                : user.getCreatedAt().atZone(ZoneId.systemDefault()).toEpochSecond();
        long updatedAt = user.getUpdatedAt() == null
                ? createdAt
                : user.getUpdatedAt().atZone(ZoneId.systemDefault()).toEpochSecond();
        return new GmUserDetailResponse(
                user.getId(),
                user.getUsername(),
                user.getStatus() == null ? 1 : user.getStatus(),
                createdAt,
                updatedAt
        );
    }
}
