package com.lostmiracle.module.admin.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.util.Map;

public record GmSaveReplaceRequest(
        @NotNull Map<String, Object> save,
        @NotBlank String confirmToken,
        @NotBlank String reason
) {
}
