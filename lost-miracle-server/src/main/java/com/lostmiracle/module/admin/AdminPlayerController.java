package com.lostmiracle.module.admin;

import com.lostmiracle.common.ApiResponse;
import com.lostmiracle.module.admin.dto.GmBanRequest;
import com.lostmiracle.module.admin.dto.GmCharacterSaveResponse;
import com.lostmiracle.module.admin.dto.GmSaveFieldsRequest;
import com.lostmiracle.module.admin.dto.GmSavePreviewResponse;
import com.lostmiracle.module.admin.dto.GmSaveReplaceRequest;
import com.lostmiracle.module.admin.dto.GmUserDetailResponse;
import com.lostmiracle.module.admin.dto.GmUserListResponse;
import com.lostmiracle.module.character.dto.CharacterListResponse;
import com.lostmiracle.module.save.dto.UploadSaveResponse;
import com.lostmiracle.security.AdminSecurityUtils;
import com.lostmiracle.security.GmPrincipal;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/admin")
public class AdminPlayerController {

    private final AdminPlayerService adminPlayerService;

    public AdminPlayerController(AdminPlayerService adminPlayerService) {
        this.adminPlayerService = adminPlayerService;
    }

    @GetMapping("/users")
    public ApiResponse<GmUserListResponse> searchUsers(
            @RequestParam(defaultValue = "") String q,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int pageSize
    ) {
        AdminSecurityUtils.requireRole(GmRole.viewer);
        return ApiResponse.ok(adminPlayerService.searchUsers(q, page, pageSize));
    }

    @GetMapping("/users/{userId}")
    public ApiResponse<GmUserDetailResponse> getUser(@PathVariable long userId) {
        AdminSecurityUtils.requireRole(GmRole.viewer);
        return ApiResponse.ok(adminPlayerService.getUser(userId));
    }

    @GetMapping("/users/{userId}/characters")
    public ApiResponse<CharacterListResponse> listCharacters(@PathVariable long userId) {
        AdminSecurityUtils.requireRole(GmRole.viewer);
        return ApiResponse.ok(adminPlayerService.listCharacters(userId));
    }

    @PostMapping("/users/{userId}/ban")
    public ApiResponse<Void> banUser(
            @PathVariable long userId,
            @Valid @RequestBody GmBanRequest request,
            HttpServletRequest httpRequest
    ) {
        GmPrincipal gm = AdminSecurityUtils.requireRole(GmRole.super_);
        adminPlayerService.banUser(gm, userId, request, clientIp(httpRequest));
        return ApiResponse.ok();
    }

    @PostMapping("/users/{userId}/unban")
    public ApiResponse<Void> unbanUser(@PathVariable long userId, HttpServletRequest httpRequest) {
        GmPrincipal gm = AdminSecurityUtils.requireRole(GmRole.super_);
        adminPlayerService.unbanUser(gm, userId, clientIp(httpRequest));
        return ApiResponse.ok();
    }

    @GetMapping("/characters/{characterId}/save")
    public ApiResponse<GmCharacterSaveResponse> getSave(@PathVariable long characterId) {
        AdminSecurityUtils.requireRole(GmRole.viewer);
        return ApiResponse.ok(adminPlayerService.getSave(characterId));
    }

    @PatchMapping("/characters/{characterId}/save/fields")
    public ApiResponse<UploadSaveResponse> patchSaveFields(
            @PathVariable long characterId,
            @RequestBody GmSaveFieldsRequest request,
            HttpServletRequest httpRequest
    ) {
        GmPrincipal gm = AdminSecurityUtils.requireRole(GmRole.operator);
        return ApiResponse.ok(adminPlayerService.patchSaveFields(gm, characterId, request, clientIp(httpRequest)));
    }

    @PostMapping("/characters/{characterId}/save/preview")
    public ApiResponse<GmSavePreviewResponse> previewSaveReplace(
            @PathVariable long characterId,
            @RequestBody Map<String, Object> save
    ) {
        GmPrincipal gm = AdminSecurityUtils.requireRole(GmRole.super_);
        return ApiResponse.ok(adminPlayerService.previewSaveReplace(gm, characterId, save));
    }

    @PutMapping("/characters/{characterId}/save")
    public ApiResponse<UploadSaveResponse> replaceSave(
            @PathVariable long characterId,
            @Valid @RequestBody GmSaveReplaceRequest request,
            HttpServletRequest httpRequest
    ) {
        GmPrincipal gm = AdminSecurityUtils.requireRole(GmRole.super_);
        return ApiResponse.ok(adminPlayerService.replaceSave(gm, characterId, request, clientIp(httpRequest)));
    }

    @DeleteMapping("/characters/{characterId}")
    public ApiResponse<Void> deleteCharacter(@PathVariable long characterId, HttpServletRequest httpRequest) {
        GmPrincipal gm = AdminSecurityUtils.requireRole(GmRole.super_);
        adminPlayerService.deleteCharacter(gm, characterId, clientIp(httpRequest));
        return ApiResponse.ok();
    }

    private String clientIp(HttpServletRequest request) {
        String forwarded = request.getHeader("X-Forwarded-For");
        if (forwarded != null && !forwarded.isBlank()) {
            return forwarded.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }
}
