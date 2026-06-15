package com.lostmiracle.module.enhance.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record EnhanceRollRequest(
        @NotBlank String equipmentUid,
        boolean useBlessedStone,
        @NotNull Long saveVersion
) {
}
