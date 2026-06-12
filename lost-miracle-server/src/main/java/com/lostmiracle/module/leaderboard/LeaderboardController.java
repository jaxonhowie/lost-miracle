package com.lostmiracle.module.leaderboard;

import com.lostmiracle.common.ApiResponse;
import com.lostmiracle.module.leaderboard.dto.LeaderboardResponse;
import com.lostmiracle.security.SecurityUtils;
import com.lostmiracle.security.UserPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/leaderboards")
public class LeaderboardController {

    private final LeaderboardService leaderboardService;

    public LeaderboardController(LeaderboardService leaderboardService) {
        this.leaderboardService = leaderboardService;
    }

    @GetMapping("/{boardType}")
    public ApiResponse<LeaderboardResponse> getLeaderboard(
            @PathVariable String boardType,
            @RequestParam(defaultValue = "all") String season,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "50") int pageSize,
            @RequestParam(required = false) Long characterId
    ) {
        SecurityUtils.requirePrincipal();
        pageSize = Math.min(Math.max(pageSize, 1), 100);
        return ApiResponse.ok(leaderboardService.getLeaderboard(boardType, season, page, pageSize, characterId));
    }
}
