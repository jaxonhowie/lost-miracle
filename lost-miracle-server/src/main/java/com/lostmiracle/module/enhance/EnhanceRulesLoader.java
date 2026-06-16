package com.lostmiracle.module.enhance;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.lostmiracle.common.BusinessException;
import com.lostmiracle.common.ErrorCode;
import com.lostmiracle.module.config.ConfigDefaults;
import com.lostmiracle.module.config.ConfigPublishedEvent;
import com.lostmiracle.module.config.GameConfigService;
import org.springframework.context.event.EventListener;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.io.InputStream;
import java.util.Map;

@Component
public class EnhanceRulesLoader {

    private final ObjectMapper objectMapper;
    private final GameConfigService gameConfigService;
    private volatile EnhanceRules rules;

    public EnhanceRulesLoader(ObjectMapper objectMapper, GameConfigService gameConfigService) {
        this.objectMapper = objectMapper;
        this.gameConfigService = gameConfigService;
        this.rules = loadRules();
    }

    public EnhanceRules getRules() {
        return rules;
    }

    @EventListener
    public void onConfigPublished(ConfigPublishedEvent event) {
        rules = loadRules();
    }

    private EnhanceRules loadRules() {
        Map<String, Object> published = gameConfigService.getPublishedMap(ConfigDefaults.ENHANCE_RULES);
        if (!published.isEmpty()) {
            return parseRules(objectMapper.valueToTree(published));
        }
        return loadFromClasspath(objectMapper);
    }

    private EnhanceRules loadFromClasspath(ObjectMapper objectMapper) {
        try (InputStream input = new ClassPathResource("data/enhance_rules.json").getInputStream()) {
            JsonNode root = objectMapper.readTree(input);
            return parseRules(root);
        } catch (IOException e) {
            throw new BusinessException(ErrorCode.INTERNAL_ERROR, "failed to load enhance rules");
        }
    }

    private EnhanceRules parseRules(JsonNode root) {
        return new EnhanceRules(
                root.path("max_enhance").asInt(10),
                root.path("max_jewelry_enhance").asInt(3),
                root.path("default_safe_until").asInt(3),
                root.path("break_from_level").asInt(4),
                root.path("break_chance_normal_scroll").asDouble(0.35),
                root.path("break_chance_blessed_scroll").asDouble(0.15),
                root.path("blessed_equipment_save_chance").asDouble(0.5),
                root.path("blessed_equipment_on_enhance_plus7").asDouble(0.15),
                parseRates(root.path("armor_rates")),
                parseRates(root.path("jewelry_rates")),
                parseRates(root.path("jewelry_break_rates"))
        );
    }

    private double[][] parseRates(JsonNode node) {
        if (!node.isArray()) {
            return new double[0][0];
        }
        double[][] rates = new double[node.size()][];
        for (int i = 0; i < node.size(); i++) {
            JsonNode row = node.get(i);
            rates[i] = new double[row.size()];
            for (int j = 0; j < row.size(); j++) {
                rates[i][j] = row.get(j).asDouble();
            }
        }
        return rates;
    }

    public record EnhanceRules(
            int maxEnhance,
            int maxJewelryEnhance,
            int defaultSafeUntil,
            int breakFromLevel,
            double breakChanceNormal,
            double breakChanceBlessed,
            double blessedSaveChance,
            double blessedOnPlus7Chance,
            double[][] armorRates,
            double[][] jewelryRates,
            double[][] jewelryBreakRates
    ) {
    }
}
