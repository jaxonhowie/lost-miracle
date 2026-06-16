package com.lostmiracle.module.config;

import com.lostmiracle.common.ApiResponse;
import com.lostmiracle.module.config.dto.ConfigBundleResponse;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/config")
public class ConfigController {

    private final GameConfigService gameConfigService;

    public ConfigController(GameConfigService gameConfigService) {
        this.gameConfigService = gameConfigService;
    }

    @GetMapping("/bundle")
    public ApiResponse<ConfigBundleResponse> bundle(@RequestParam(required = false) Long since) {
        return ApiResponse.ok(gameConfigService.getBundle(since));
    }
}
