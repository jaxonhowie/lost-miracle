package com.lostmiracle.module.config.dto;

import java.util.List;

public record ConfigPublishHistoryResponse(
        List<ConfigPublishHistoryItem> items
) {
}
