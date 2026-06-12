package com.lostmiracle.module.save.dto;

import jakarta.validation.constraints.NotNull;

import java.util.Map;

public record UploadSaveRequest(
        @NotNull Long saveVersion,
        @NotNull Long clientUpdatedAt,
        @NotNull Map<String, Object> save,
        Boolean force
) {
}
