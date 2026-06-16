package com.lostmiracle.module.admin;

import com.lostmiracle.module.config.GameConfigService;
import com.lostmiracle.module.config.dto.ConfigItemResponse;
import com.lostmiracle.module.config.dto.ConfigListResponse;
import com.lostmiracle.module.config.dto.ConfigPublishHistoryResponse;
import com.lostmiracle.module.config.dto.ConfigPublishRequest;
import com.lostmiracle.module.config.dto.ConfigPublishResultResponse;
import com.lostmiracle.module.config.dto.ConfigUpdateRequest;
import com.lostmiracle.security.GmPrincipal;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Map;

@Service
public class AdminConfigService {

    private final GameConfigService gameConfigService;
    private final GmAuditService gmAuditService;

    public AdminConfigService(GameConfigService gameConfigService, GmAuditService gmAuditService) {
        this.gameConfigService = gameConfigService;
        this.gmAuditService = gmAuditService;
    }

    public ConfigListResponse list() {
        return gameConfigService.listForAdmin();
    }

    public ConfigItemResponse get(String configKey) {
        return gameConfigService.getForAdmin(configKey);
    }

    @Transactional
    public ConfigItemResponse updateDraft(GmPrincipal gm, String configKey, ConfigUpdateRequest request, String ip) {
        ConfigItemResponse updated = gameConfigService.updateDraft(configKey, request.json());
        gmAuditService.log(
                gm.gmAccountId(),
                "CONFIG_UPDATE_DRAFT",
                "config",
                configKey,
                Map.of("configKey", configKey),
                ip
        );
        return updated;
    }

    @Transactional
    public ConfigPublishResultResponse publish(GmPrincipal gm, ConfigPublishRequest request, String ip) {
        ConfigPublishResultResponse result = gameConfigService.publish(gm.gmAccountId(), request.note());
        gmAuditService.log(
                gm.gmAccountId(),
                "CONFIG_PUBLISH",
                "config",
                String.valueOf(result.version()),
                Map.of("version", result.version(), "note", request.note() == null ? "" : request.note()),
                ip
        );
        return result;
    }

    public ConfigPublishHistoryResponse history(int limit) {
        return gameConfigService.publishHistory(limit);
    }

    @Transactional
    public ConfigPublishResultResponse rollback(GmPrincipal gm, long publishId, String ip) {
        ConfigPublishResultResponse result = gameConfigService.rollback(gm.gmAccountId(), publishId);
        gmAuditService.log(
                gm.gmAccountId(),
                "CONFIG_ROLLBACK",
                "config",
                String.valueOf(result.version()),
                Map.of("publishId", publishId, "version", result.version()),
                ip
        );
        return result;
    }
}
