package com.lostmiracle.module.enhance;

import com.lostmiracle.common.ApiResponse;
import com.lostmiracle.module.enhance.dto.EnhanceRollRequest;
import com.lostmiracle.module.enhance.dto.EnhanceRollResponse;
import com.lostmiracle.security.SecurityUtils;
import com.lostmiracle.security.UserPrincipal;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class EnhanceController {

    private final EnhanceService enhanceService;

    public EnhanceController(EnhanceService enhanceService) {
        this.enhanceService = enhanceService;
    }

    @PostMapping("/characters/{characterId}/enhance/roll")
    public ApiResponse<EnhanceRollResponse> roll(
            @PathVariable long characterId,
            @Valid @RequestBody EnhanceRollRequest request
    ) {
        UserPrincipal principal = SecurityUtils.requirePrincipal();
        return ApiResponse.ok(enhanceService.roll(principal.userId(), characterId, request));
    }
}
