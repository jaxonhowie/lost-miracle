package com.lostmiracle.module.config.dto;

import java.time.LocalDateTime;

public record ConfigPublishHistoryItem(
        long id,
        long version,
        long publishedBy,
        String note,
        LocalDateTime publishedAt
) {
}
