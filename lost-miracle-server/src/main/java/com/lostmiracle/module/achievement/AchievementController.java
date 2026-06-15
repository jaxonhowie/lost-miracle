package com.lostmiracle.module.achievement;

import com.lostmiracle.common.ApiResponse;
import com.lostmiracle.module.achievement.dto.AchievementListResponse;
import com.lostmiracle.module.achievement.dto.ClaimAchievementRequest;
import com.lostmiracle.module.achievement.dto.ClaimAchievementResponse;
import com.lostmiracle.security.SecurityUtils;
import com.lostmiracle.security.UserPrincipal;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/achievements")
public class AchievementController {

    private final AchievementService achievementService;

    public AchievementController(AchievementService achievementService) {
        this.achievementService = achievementService;
    }

    @GetMapping
    public ApiResponse<AchievementListResponse> list(@RequestParam long characterId) {
        UserPrincipal principal = SecurityUtils.requirePrincipal();
        return ApiResponse.ok(achievementService.list(principal.userId(), characterId));
    }

    @PostMapping("/{achievementId}/claim")
    public ApiResponse<ClaimAchievementResponse> claim(
            @PathVariable String achievementId,
            @RequestParam long characterId,
            @Valid @RequestBody ClaimAchievementRequest request
    ) {
        UserPrincipal principal = SecurityUtils.requirePrincipal();
        return ApiResponse.ok(achievementService.claim(principal.userId(), characterId, achievementId, request));
    }
}
