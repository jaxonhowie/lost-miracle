package com.lostmiracle.module.save.dto;

public record SaveConflictResponse(
        long serverSaveVersion,
        long serverUpdatedAt,
        String resolution
) {
}
