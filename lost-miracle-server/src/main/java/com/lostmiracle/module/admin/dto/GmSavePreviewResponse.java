package com.lostmiracle.module.admin.dto;

import java.util.List;

public record GmSavePreviewResponse(
        long characterId,
        String confirmToken,
        String beforeChecksum,
        String afterChecksum,
        List<String> changes
) {
}
