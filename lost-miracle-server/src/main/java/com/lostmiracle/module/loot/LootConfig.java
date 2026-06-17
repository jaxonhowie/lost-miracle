package com.lostmiracle.module.loot;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class LootConfig {

    @Bean
    public LootEngine lootEngine(GameDataCatalog catalog, EquipmentGenerator equipmentGenerator) {
        return new LootEngine(catalog, equipmentGenerator);
    }
}
