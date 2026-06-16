package com.lostmiracle.module.admin.dto;

public record GmSaveFieldsRequest(
        Long gold,
        Integer level,
        Integer exp,
        Integer enhanceStone,
        Integer blessedEnhanceStone,
        Integer jewelryEnhanceStone,
        Integer blessedJewelryEnhanceStone,
        Integer healthPotion
) {
}
