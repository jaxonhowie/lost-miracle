package com.lostmiracle.module.character.dto;

import java.util.List;

public record CharacterListResponse(
        List<CharacterSummaryResponse> items,
        int maxSlots
) {
}
