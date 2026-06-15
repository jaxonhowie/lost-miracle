package com.lostmiracle.module.enhance;

import org.springframework.stereotype.Component;

import java.util.Map;
import java.util.concurrent.ThreadLocalRandom;

@Component
public class EnhanceRollEngine {

    private final EnhanceRulesLoader.EnhanceRules rules;

    public EnhanceRollEngine(EnhanceRulesLoader rulesLoader) {
        this.rules = rulesLoader.getRules();
    }

    public record RollResult(
            boolean success,
            boolean broken,
            int newLevel,
            String message,
            boolean gainedBlessed
    ) {
    }

    public RollResult roll(Map<String, Object> equipment, boolean useBlessedStone, double pityBonusRate) {
        if (isJewelry(equipment)) {
            return rollJewelry(equipment, useBlessedStone, pityBonusRate);
        }
        return rollArmor(equipment, useBlessedStone, pityBonusRate);
    }

    private RollResult rollArmor(Map<String, Object> equipment, boolean useBlessedStone, double pityBonusRate) {
        int level = enhanceLevel(equipment);
        if (level >= rules.maxEnhance()) {
            return new RollResult(false, false, level, "已达最高强化等级", false);
        }

        double rate = rules.armorRates()[level][useBlessedStone ? 1 : 0];
        if (pityBonusRate > 0) {
            rate = Math.min(1.0, rate + pityBonusRate);
        }
        if (ThreadLocalRandom.current().nextDouble() < rate) {
            int newLevel = level + 1;
            equipment.put("enhance_level", newLevel);
            String message = "强化成功！+" + newLevel;
            boolean gainedBlessed = false;
            if (newLevel >= 7 && !isBlessed(equipment)) {
                if (ThreadLocalRandom.current().nextDouble() < rules.blessedOnPlus7Chance()) {
                    equipment.put("is_blessed", true);
                    gainedBlessed = true;
                    message += "  装备获得祝福！";
                }
            }
            String oldQuality = qualityByEnhance(level);
            String newQuality = qualityByEnhance(newLevel);
            if (!oldQuality.equals(newQuality)) {
                message += "  品质提升: " + qualityName(newQuality);
            }
            return new RollResult(true, false, newLevel, message, gainedBlessed);
        }

        boolean broken = rollBreakOnFail(equipment, useBlessedStone);
        String failMessage = broken
                ? "强化失败！装备已损毁..."
                : (useBlessedStone
                ? "强化失败...受祝福石保住了装备"
                : (isBlessed(equipment) ? "强化失败...祝福之力保住了装备" : "强化失败...材料已消耗"));
        return new RollResult(false, broken, level, failMessage, false);
    }

    private RollResult rollJewelry(Map<String, Object> equipment, boolean useBlessedStone, double pityBonusRate) {
        int level = enhanceLevel(equipment);
        if (level >= rules.maxJewelryEnhance()) {
            return new RollResult(false, false, level, "已达最高首饰强化等级", false);
        }

        double rate = rules.jewelryRates()[level][useBlessedStone ? 1 : 0];
        if (pityBonusRate > 0) {
            rate = Math.min(1.0, rate + pityBonusRate);
        }
        if (ThreadLocalRandom.current().nextDouble() < rate) {
            int newLevel = level + 1;
            equipment.put("enhance_level", newLevel);
            return new RollResult(true, false, newLevel, "首饰强化成功！+" + newLevel, false);
        }

        boolean broken = rollJewelryBreakOnFail(level, useBlessedStone);
        String failMessage = broken
                ? "首饰强化失败！装备已损毁..."
                : "首饰强化失败...材料已消耗";
        return new RollResult(false, broken, level, failMessage, false);
    }

    private boolean rollJewelryBreakOnFail(int level, boolean useBlessedStone) {
        int idx = Math.min(level, rules.jewelryBreakRates().length - 1);
        double breakChance = useBlessedStone ? rules.jewelryBreakRates()[idx][1] : rules.jewelryBreakRates()[idx][0];
        return ThreadLocalRandom.current().nextDouble() < breakChance;
    }

    private boolean rollBreakOnFail(Map<String, Object> equipment, boolean useBlessedStone) {
        int level = enhanceLevel(equipment);
        if (level + 1 < rules.breakFromLevel()) {
            return false;
        }
        if (level <= safeEnhanceUntil(equipment)) {
            return false;
        }
        double breakChance = useBlessedStone ? rules.breakChanceBlessed() : rules.breakChanceNormal();
        if (ThreadLocalRandom.current().nextDouble() >= breakChance) {
            return false;
        }
        if (isBlessed(equipment)) {
            return ThreadLocalRandom.current().nextDouble() >= rules.blessedSaveChance();
        }
        return true;
    }

    public boolean isJewelry(Map<String, Object> equipment) {
        if ("jewelry".equals(String.valueOf(equipment.getOrDefault("type", "")))) {
            return true;
        }
        if (!equipment.containsKey("jewelry_line")) {
            return false;
        }
        String slot = String.valueOf(equipment.getOrDefault("slot", ""));
        return "ring".equals(slot) || "necklace".equals(slot);
    }

    public int maxLevel(Map<String, Object> equipment) {
        return isJewelry(equipment) ? rules.maxJewelryEnhance() : rules.maxEnhance();
    }

    private int enhanceLevel(Map<String, Object> equipment) {
        Object value = equipment.get("enhance_level");
        if (value instanceof Number number) {
            return number.intValue();
        }
        return 0;
    }

    private int safeEnhanceUntil(Map<String, Object> equipment) {
        Object value = equipment.get("safe_enhance_until");
        if (value instanceof Number number) {
            return number.intValue();
        }
        return rules.defaultSafeUntil();
    }

    private boolean isBlessed(Map<String, Object> equipment) {
        Object value = equipment.get("is_blessed");
        return value instanceof Boolean blessed && blessed;
    }

    private String qualityByEnhance(int level) {
        if (level >= 10) {
            return "legendary";
        }
        if (level >= 7) {
            return "epic";
        }
        if (level >= 4) {
            return "fine";
        }
        return "normal";
    }

    private String qualityName(String quality) {
        return switch (quality) {
            case "fine" -> "精良";
            case "epic" -> "史诗";
            case "legendary" -> "传说";
            default -> "普通";
        };
    }
}
