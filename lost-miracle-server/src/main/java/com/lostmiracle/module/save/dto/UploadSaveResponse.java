package com.lostmiracle.module.save.dto;

public record UploadSaveResponse(
        long characterId,
        long saveVersion,
        long serverUpdatedAt,
        int powerScore
) {
}
