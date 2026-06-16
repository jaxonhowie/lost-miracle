package com.lostmiracle.module.admin.dto;

import java.util.Map;

public record GmCharacterSaveResponse(
        long characterId,
        long saveVersion,
        long clientUpdatedAt,
        String checksum,
        Map<String, Object> save
) {
}
