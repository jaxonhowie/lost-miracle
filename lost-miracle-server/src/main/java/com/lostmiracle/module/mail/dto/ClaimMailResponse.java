package com.lostmiracle.module.mail.dto;

import java.util.Map;

public record ClaimMailResponse(
        long saveVersion,
        long serverUpdatedAt,
        int powerScore,
        Map<String, Object> save
) {
}
