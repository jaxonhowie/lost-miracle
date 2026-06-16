package com.lostmiracle.module.config;

import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

@Component
public class GameConfigBootstrap {

    private final GameConfigService gameConfigService;

    public GameConfigBootstrap(GameConfigService gameConfigService) {
        this.gameConfigService = gameConfigService;
    }

    @Order(10)
    @EventListener(ApplicationReadyEvent.class)
    public void seedDefaults() {
        gameConfigService.seedDefaultsIfEmpty();
    }
}
