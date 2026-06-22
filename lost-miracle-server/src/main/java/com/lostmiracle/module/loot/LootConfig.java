package com.lostmiracle.module.loot;

import com.lostmiracle.module.config.GameConfigService;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class LootConfig {

    @Bean
    public LootEngine lootEngine(GameDataCatalog catalog, EquipmentGenerator equipmentGenerator, GameConfigService configService) {
        return new LootEngine(catalog, equipmentGenerator, configService);
    }
}
