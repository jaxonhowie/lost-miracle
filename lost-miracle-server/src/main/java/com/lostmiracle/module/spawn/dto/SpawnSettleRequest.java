package com.lostmiracle.module.spawn.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record SpawnSettleRequest(
        @NotNull Long saveVersion,
        @NotBlank String monsterId
) {
}
