package com.lostmiracle.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

import java.util.Arrays;
import java.util.List;

/**
 * 生产环境启动安全检查。
 * 当 active profile 包含 prod 或 production 时，拒绝不安全的默认配置。
 */
@Component
public class ProductionSafetyCheck {

    private static final Logger log = LoggerFactory.getLogger(ProductionSafetyCheck.class);

    private static final String DEFAULT_JWT_SECRET = "change-me-to-a-long-random-secret-key-in-production";
    private static final String DEFAULT_GM_PASSWORD = "gm-admin-change-me";

    private final LostMiracleProperties properties;
    private final Environment environment;

    public ProductionSafetyCheck(LostMiracleProperties properties, Environment environment) {
        this.properties = properties;
        this.environment = environment;
    }

    @EventListener(ApplicationReadyEvent.class)
    public void checkProductionSafety() {
        if (!isProductionProfile()) {
            return;
        }

        List<String> violations = new java.util.ArrayList<>();

        String jwtSecret = properties.getJwt().getSecret();
        if (jwtSecret == null || jwtSecret.equals(DEFAULT_JWT_SECRET)) {
            violations.add("lost-miracle.jwt.secret is using the default placeholder — "
                    + "set LOST_MIRACLE_JWT_SECRET env var to a random 32+ char string");
        }

        String gmPassword = properties.getGm().getBootstrapSuperPassword();
        if (gmPassword == null || gmPassword.equals(DEFAULT_GM_PASSWORD)) {
            violations.add("lost-miracle.gm.bootstrap-super-password is using the default value — "
                    + "set LOST_MIRACLE_GM_PASSWORD env var before first startup");
        }

        if (!violations.isEmpty()) {
            String message = "Production safety check failed:\n  - " + String.join("\n  - ", violations);
            log.error(message);
            throw new IllegalStateException(message);
        }

        log.info("Production safety check passed");
    }

    private boolean isProductionProfile() {
        return Arrays.stream(environment.getActiveProfiles())
                .anyMatch(p -> p.equals("prod") || p.equals("production"));
    }
}
