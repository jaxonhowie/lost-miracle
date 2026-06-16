package com.lostmiracle.module.config.dto;

import jakarta.validation.constraints.NotNull;

import java.util.Map;

public record ConfigUpdateRequest(
        @NotNull Map<String, Object> json
) {
}
