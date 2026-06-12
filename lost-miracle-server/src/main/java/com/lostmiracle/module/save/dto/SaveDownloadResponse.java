package com.lostmiracle.module.save.dto;

import java.util.Map;

public record SaveDownloadResponse(
        long characterId,
        long saveVersion,
        long clientUpdatedAt,
        Map<String, Object> save
) {
}
